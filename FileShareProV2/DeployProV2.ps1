param(
    [string]$resourceGroupName  = "rg-yourname",
    [string]$storageAccountName = "yourStorageAccount",
    [string]$bicepFilePath      = ".\ProV2.bicep",
    [string]$fileShareName      = "sharename",
    [int]$fileShareSize         = 32,
    [int]$fileShareIops         = 3000,
    [int]$fileShareThroughput   = 100,
    [bool]$deployFileShare      = $true
)

#region Check / Connect Azure
$azContext = Get-AzContext -ErrorAction SilentlyContinue
if (-not $azContext) {
    Write-Host "No Azure connection found. Connecting..." -ForegroundColor Yellow
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

#region Deploy Bicep
Write-Host "Deploying Bicep template..." -ForegroundColor Cyan
New-AzResourceGroupDeployment `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile $bicepFilePath `
    -storageAccount_name $storageAccountName `
    -fileShare_name $fileShareName `
    -fileShare_size $fileShareSize `
    -fileShare_iops $fileShareIops `
    -fileShare_throughput $fileShareThroughput `
    -deployFileShare $deployFileShare `
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