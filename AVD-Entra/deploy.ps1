# =============================================================================
# AVD Lab — Deployment Script
# =============================================================================
# Usage:
#   1. Fill in your values in deploy.config.ps1
#   2. Run: .\deploy.ps1
# =============================================================================

# Load configuration — all user values live in deploy.config.ps1
. (Join-Path $PSScriptRoot 'deploy.config.ps1')

# -----------------------------------------------
# Create resource group if it doesn't exist
# -----------------------------------------------
if (-not (Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue)) {
    New-AzResourceGroup -Name $resourceGroupName -Location $location
    Write-Output "Resource group $resourceGroupName created"
} else {
    Write-Output "Resource group $resourceGroupName already exists"
}

# -----------------------------------------------
# Register Standard security type feature if needed
# -----------------------------------------------
if ($vmSecurityType -eq 'Standard') {
    Write-Output 'Checking Microsoft.Compute/UseStandardSecurityType feature registration...'
    $feature = Get-AzProviderFeature -FeatureName 'UseStandardSecurityType' -ProviderNamespace 'Microsoft.Compute'
    
    if ($feature.RegistrationState -ne 'Registered') {
        Write-Output 'Registering Microsoft.Compute/UseStandardSecurityType feature...'
        Register-AzProviderFeature -FeatureName 'UseStandardSecurityType' -ProviderNamespace 'Microsoft.Compute'
        
        Write-Output 'Waiting for feature registration to complete...'
        do {
            Start-Sleep -Seconds 15
            $feature = Get-AzProviderFeature -FeatureName 'UseStandardSecurityType' -ProviderNamespace 'Microsoft.Compute'
            Write-Output ('Current state: ' + $feature.RegistrationState)
        } while ($feature.RegistrationState -ne 'Registered')
        
        Write-Output 'Feature registered successfully'
    } else {
        Write-Output 'Feature already registered - continuing'
    }
}

# -----------------------------------------------
# Deploy
# -----------------------------------------------
$securePassword = Read-Host -Prompt 'VM Admin Password' -AsSecureString

$deployment = New-AzResourceGroupDeployment `
  -ResourceGroupName $resourceGroupName `
  -TemplateFile '.\avd-lab.bicep' `
  -location $location `
  -prefix $prefix `
  -goldenImageId $goldenImageId `
  -vmAdminUsername $vmAdminUsername `
  -vmAdminPassword $securePassword `
  -avdUsersGroupId $avdUsersGroupId `
  -vmSize $vmSize `
  -vmCount $vmCount `
  -enrollInIntune $enrollInIntune `
  -vmSecurityType $vmSecurityType `
  -storageAccountSku $storageAccountSku `
  -fslogixProfileSizeGB $fslogixProfileSizeGB `
  -fslogixUserCount $fslogixUserCount `
  -tagEnvironment $tagEnvironment `
  -tagProject $tagProject `
  -enableMonitoring $enableMonitoring `
  -logAnalyticsWorkspaceName $logAnalyticsWorkspaceName `
  -logRetentionDays $logRetentionDays `
  -alertEmailAddress $alertEmailAddress `
  -Verbose

# -----------------------------------------------
# Post-deployment: tag the storage account app registration as cloud-only
# -----------------------------------------------
# The GROUP_SKU_CLOUD_ONLY tag must be present on the Entra app registration
# created when AADKERB is enabled, otherwise Entra attempts a hybrid identity
# flow and FSLogix profile mounts fail with a Kerberos service ticket error.
# Requires the Microsoft.Graph.Applications module.

if ($deployment.ProvisioningState -eq 'Succeeded') {
    $saName = $deployment.Outputs['storageAccountName'].Value

    $graphAvailable = Get-Module -ListAvailable -Name 'Microsoft.Graph.Applications' -ErrorAction SilentlyContinue
    if (-not $graphAvailable) {
        Write-Warning "Microsoft.Graph.Applications module not found. Skipping GROUP_SKU_CLOUD_ONLY tag."
        Write-Warning "Install it with: Install-Module Microsoft.Graph -Scope CurrentUser"
        Write-Warning "Then find the app registration for '$saName' in Entra ID and run:"
        Write-Warning "  `$app = Get-MgApplication -Filter `"displayName eq '$saName'`""
        Write-Warning "  Update-MgApplication -ApplicationId `$app.Id -Tags @('GROUP_SKU_CLOUD_ONLY')"
    } else {
        Write-Output 'Configuring storage account app registration...'
        try {
            Connect-MgGraph -Scopes 'Application.ReadWrite.All', 'DelegatedPermissionGrant.ReadWrite.All' -NoWelcome -ErrorAction Stop
            $appDisplayName = "[Storage Account] $saName.file.core.windows.net"

            # Retry loop — the app registration can take up to 2 minutes to appear in Entra
            # after the storage account is created with AADKERB enabled
            $app = $null
            $sp  = $null
            $maxAttempts = 12
            $attempt = 0
            do {
                $attempt++
                Write-Output "Waiting for app registration to appear in Entra ID (attempt $attempt of $maxAttempts)..."
                $app = Get-MgApplication -Filter "displayName eq '$appDisplayName'" -ErrorAction SilentlyContinue | Select-Object -First 1
                $sp  = Get-MgServicePrincipal -Filter "displayName eq '$appDisplayName'" -ErrorAction SilentlyContinue | Select-Object -First 1
                if (-not ($app -and $sp)) { Start-Sleep -Seconds 10 }
            } while (-not ($app -and $sp) -and $attempt -lt $maxAttempts)

            if ($app -and $sp) {
                # Apply GROUP_SKU_CLOUD_ONLY tag to the app manifest
                $newTags = ($app.Tags + @('GROUP_SKU_CLOUD_ONLY')) | Select-Object -Unique
                Update-MgApplication -ApplicationId $app.Id -Tags $newTags -ErrorAction Stop
                Write-Output 'App registration tagged as cloud-only.'

                # Grant admin consent for all delegated permissions defined on the app
                foreach ($ra in $app.RequiredResourceAccess) {
                    $resourceSp = Get-MgServicePrincipal -Filter "appId eq '$($ra.ResourceAppId)'" -ErrorAction SilentlyContinue
                    if (-not $resourceSp) { continue }

                    $scopes = foreach ($permission in $ra.ResourceAccess | Where-Object { $_.Type -eq 'Scope' }) {
                        ($resourceSp.Oauth2PermissionScopes | Where-Object { $_.Id -eq $permission.Id }).Value
                    }

                    if ($scopes) {
                        $existingGrant = Get-MgOauth2PermissionGrant -Filter "clientId eq '$($sp.Id)' and resourceId eq '$($resourceSp.Id)'" -ErrorAction SilentlyContinue
                        if ($existingGrant) {
                            Update-MgOauth2PermissionGrant -OAuth2PermissionGrantId $existingGrant.Id -Scope ($scopes -join ' ') -ErrorAction Stop
                        } else {
                            New-MgOauth2PermissionGrant -ClientId $sp.Id -ConsentType 'AllPrincipals' -ResourceId $resourceSp.Id -Scope ($scopes -join ' ') -ErrorAction Stop
                        }
                    }
                }
                Write-Output 'Admin consent granted.'
            } else {
                Write-Warning "Could not find app registration for '$saName' in Entra ID."
                Write-Warning "Grant admin consent manually: Entra ID > App registrations > search '$saName' > API permissions > Grant admin consent"
                Write-Warning "Then apply the tag manually:"
                Write-Warning "  `$app = Get-MgApplication -Filter `"displayName eq '[Storage Account] $saName.file.core.windows.net'`""
                Write-Warning "  `$newTags = (`$app.Tags + @('GROUP_SKU_CLOUD_ONLY')) | Select-Object -Unique"
                Write-Warning "  Update-MgApplication -ApplicationId `$app.Id -Tags `$newTags"
            }
        } catch {
            Write-Warning "Failed to configure app registration: $_"
        }
    }
} else {
    Write-Warning "Deployment did not succeed — skipping post-deployment steps."
}
