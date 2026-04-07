# =============================================================================
# AVD Lab — Deployment Configuration
# =============================================================================
# Fill in your values here. This file is dot-sourced by deploy.ps1.
# Your values are preserved when deploy.ps1 is updated.
# =============================================================================

$resourceGroupName         = 'AVDLab'
$location                  = 'uksouth'
$prefix                    = 'avd-lab'
$goldenImageId             = ''   # Leave blank to use latest Windows 11 25H2 AVD marketplace image
                                  # Or supply a resource ID for a custom Managed Image or SIG version
$vmAdminUsername           = 'avdadmin'
$avdUsersGroupId           = '<object-id-of-avd-users-group>'
$vmSize                    = 'Standard_D2as_v6'
$vmCount                   = 2
$enrollInIntune            = $true    # Set to $false to skip Intune enrollment — requires security defaults to be disabled in Entra ID
$vmSecurityType            = 'TrustedLaunch'  # Use 'Standard' if your golden image was built on a standard (non-Trusted Launch) VM
$storageAccountSku         = 'Premium_LRS'
$fslogixProfileSizeGB      = 20
$fslogixUserCount          = 4
$tagEnvironment            = 'lab'    # Set to '' to deploy without tags
$tagProject                = 'avd'   # Set to '' to deploy without tags
$enableMonitoring          = $false   # Set to $true to deploy Log Analytics, AVD Insights and alerts
$logAnalyticsWorkspaceName = 'avd-lab-law'
$logRetentionDays          = 30       # Allowed values: 30, 60, 90, 180, 365
$alertEmailAddress         = ''       # Set to your email to receive alerts — leave blank to skip
