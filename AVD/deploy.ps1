# AVD Lab - PowerShell Deployment Script
# Run this script from the folder containing avd-lab.bicep

# -----------------------------------------------
# Configuration - fill in your values here
# -----------------------------------------------

$resourceGroupName         = 'AVDLab'
$location                  = 'uksouth'
$prefix                    = 'avd-lab'
$goldenImageId             = ''   # Leave blank to use latest Windows 11 25H2 AVD marketplace image
                                    # Or supply a resource ID for a custom Managed Image or SIG version
$vmAdminUsername           = 'avdadmin'
$avdUsersGroupId           = '<object-id-of-avd-users-group>'
$vmSize                    = 'Standard_D2as_v6'
$vmCount                   = 2
$enrollInIntune            = $true    # Set to $false to skip Intune enrollment - also requires security defaults to be disabled in Entra ID
$vmSecurityType            = 'TrustedLaunch' # Use 'Standard' if your golden image was built on a standard (non-Trusted Launch) VM
                                              # Note: Using 'Standard' requires the Microsoft.Compute/UseStandardSecurityType
                                              # feature to be registered on your subscription - this script handles that automatically
$storageAccountSku         = 'Premium_LRS'
$fslogixProfileSizeGB      = 20
$fslogixUserCount          = 4
$tagEnvironment            = 'lab'    # Set to '' to deploy without tags
$tagProject                = 'avd'   # Set to '' to deploy without tags
$enableMonitoring          = $false   # Set to $true to deploy Log Analytics, AVD Insights and alerts
$logAnalyticsWorkspaceName = 'avd-lab-law'
$logRetentionDays          = 30       # Allowed values: 30, 60, 90, 180, 365
$alertEmailAddress         = ''       # Set to your email to receive alerts - leave blank to skip

# -----------------------------------------------
# Connect to Azure (uncomment if needed)
# -----------------------------------------------
# Connect-AzAccount
# Set-AzContext -Subscription '<your-subscription-id>'

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

New-AzResourceGroupDeployment `
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
