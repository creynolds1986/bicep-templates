param(
    [string]$resourceGroupName  = "rg-yourname",
    [string]$resourceGroupRegion = "uksouth",
    [string]$storageAccountName = "yourStorageAccount",
    [string]$bicepFilePath      = ".\PAYG.bicep",
    [string]$fileShareName      = "sharename",
    [string]$accessTier         = "Hot",
    [string]$replicationType    = "Standard_LRS",
    [bool]$allowSharedKeyAccess = $false
)

#region Check / Connect Azure
$azContext = Get-AzContext -ErrorAction SilentlyContinue
$azAccessToken = $null

try {
    $azAccessToken = Get-AzAccessToken -ErrorAction Stop
} catch {
    $azAccessToken = $null
}

if (-not $azAccessToken -or [string]::IsNullOrWhiteSpace($azAccessToken.Token)) {
    Write-Host "No valid Azure access token found. Connecting..." -ForegroundColor Yellow
    Connect-AzAccount
} else {
    Write-Host "Already connected to Azure as $($azContext.Account.Id) (Tenant: $($azContext.Tenant.Id))" -ForegroundColor Green
}
#endregion

#region Check / Connect Graph
$graphContext = Get-MgContext -ErrorAction SilentlyContinue
$requiredScopes = @("Application.ReadWrite.All", "DelegatedPermissionGrant.ReadWrite.All")

if (-not $graphContext) {
    Write-Host "No Graph connection found. Connecting..." -ForegroundColor Yellow
    Connect-MgGraph -Scopes $requiredScopes
} else {
    $missingScopes = $requiredScopes | Where-Object { $_ -notin $graphContext.Scopes }
    if ($missingScopes) {
        Write-Host "Graph connected but missing scopes: $($missingScopes -join ', '). Reconnecting..." -ForegroundColor Yellow
        Connect-MgGraph -Scopes $requiredScopes
    } else {
        Write-Host "Already connected to Graph as $($graphContext.Account) (Tenant: $($graphContext.TenantId))" -ForegroundColor Green
    }
}
#endregion

#check for resource group existence
$rg = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if (-not $rg) {
    Write-Host "Resource group '$resourceGroupName' does not exist. Creating..." -ForegroundColor Yellow
    New-AzResourceGroup -Name $resourceGroupName -Location $resourceGroupRegion
} else {
    Write-Host "Resource group '$resourceGroupName' already exists." -ForegroundColor Green
}

#region Deploy Bicep
Write-Host "Deploying Bicep template..." -ForegroundColor Cyan
New-AzResourceGroupDeployment `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile $bicepFilePath `
    -storageAccount_name $storageAccountName `
    -fileShare_name $fileShareName `
    -accessTier $accessTier `
    -replicationType $replicationType `
    -allowSharedKeyAccess $allowSharedKeyAccess `
    -Verbose
#endregion

#region Grant Admin Consent
$spDisplayName = "[Storage Account] $storageAccountName.file.core.windows.net"
$preExistingSp = Get-MgServicePrincipal -Filter "displayName eq '$spDisplayName'" -ErrorAction SilentlyContinue

if (-not $preExistingSp) {
    Write-Host "Waiting for app registration to propagate..." -ForegroundColor Cyan
    Start-Sleep -Seconds 15
}

Write-Host "Granting admin consent to storage account app registration..." -ForegroundColor Cyan
$sp = Get-MgServicePrincipal -Filter "displayName eq '$spDisplayName'"

if (-not $sp) {
    Write-Warning "Service principal not found for '$spDisplayName'. Admin consent skipped - run manually."
} else {
    $graphSp = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"

    $params = @{
        ClientId    = $sp.Id
        ConsentType = "AllPrincipals"
        ResourceId  = $graphSp.Id
        Scope       = "openid profile User.Read"
    }
    New-MgOauth2PermissionGrant -BodyParameter $params
    Write-Host "Admin consent granted." -ForegroundColor Green
}
#endregion

#region Update App Manifest - Cloud SID Tag
Write-Host "Adding kdc_enable_cloud_group_sids tag to app manifest..." -ForegroundColor Cyan
$app = Get-MgApplication -Filter "displayName eq '$spDisplayName'"

if (-not $app) {
    Write-Warning "App registration not found for '$spDisplayName'. Manifest tag skipped - run manually."
} else {
    $existingTags = $app.Tags
    if ("kdc_enable_cloud_group_sids" -notin $existingTags) {
        Update-MgApplication -ApplicationId $app.Id -Tags ($existingTags + "kdc_enable_cloud_group_sids")
        Write-Host "Tag added." -ForegroundColor Green
    } else {
        Write-Host "Tag already present, skipping." -ForegroundColor Yellow
    }
}
#endregion

Write-Host "Deployment complete." -ForegroundColor Green
