# AVD Lab - PowerShell Deployment Script
# Run this script from the folder containing avd-lab.bicep

# -----------------------------------------------
# Configuration - fill in your values here
# -----------------------------------------------

$resourceGroupName         = 'AVDLab'
$location                  = 'uksouth'
$prefix                    = 'avd-lab'
$goldenImageId             = '/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Compute/images/<image-name>'
$vmAdminUsername           = 'avdadmin'
$avdUsersGroupId           = '<object-id-of-avd-users-group>'
$vmSize                    = 'Standard_D2as_v6'
$vmCount                   = 2
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
