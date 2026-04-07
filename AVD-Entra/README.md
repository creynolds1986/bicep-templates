# AVD Lab — Bicep Deployment (Entra Kerberos Authentication)

A fully automated Azure Virtual Desktop environment deployed via **PowerShell**. Built as a portfolio piece to demonstrate end-to-end AVD infrastructure as code using cloud-native Entra identity for FSLogix profile container access — no domain controllers or AD DS required.

This version uses **Entra Kerberos authentication** for FSLogix profile containers. For a version using storage account key authentication with full NTFS ACL support, see the [AVD-SAS](../AVD-SAS) template.

---

## Architecture

![AVD Lab Resource Map](Diagrams/AVDEntra.png)

---

## What gets deployed

| Resource | Detail |
|---|---|
| Virtual Network | 10.0.0.0/16 with AVD and storage subnets |
| NAT Gateway | Secure outbound internet — no public IPs on VMs |
| NSGs | AVD and storage subnets locked down |
| Storage Account | Azure Files Premium v2, Entra Kerberos enabled, shared key access disabled |
| FSLogix Share | Quota calculated from profile size × user count |
| Private Endpoint | Storage accessed privately over the VNet |
| Private DNS Zone | `privatelink.file.core.windows.net` linked to VNet |
| Host Pool | Pooled, BreadthFirst, Entra ID-joined, SSO enabled |
| App Group | Desktop App Group |
| Workspace | Linked to App Group |
| Session Hosts | Configurable number of VMs, Trusted Launch, no public IP |
| RBAC | AVD Users granted Desktop Virtualization User + VM User Login + FSLogix SMB roles |
| Log Analytics Workspace | Optional — central store for all AVD and resource logs |
| AVD Insights | Optional — session host health, connection reliability, user experience |
| Diagnostic Settings | Optional — logs from Host Pool, Workspace, App Group, Storage and VMs |
| Alerts | Optional — session host unavailable and FSLogix mount failure alerts |

---

## FSLogix authentication

This deployment uses **Entra Kerberos authentication** for FSLogix profile containers. No storage account key is used — FSLogix mounts the profile share using the user's Entra identity via Kerberos.

The following are required for this to work. Most are handled automatically by the deployment:

| Requirement | How it is met |
|---|---|
| `directoryServiceOptions: AADKERB` on the storage account | Bicep template |
| `defaultSharePermission: StorageFileDataSmbShareContributor` on the storage account | Bicep template |
| Storage File Data SMB Share Contributor RBAC on the storage account | Bicep template |
| Storage File Data SMB Share Elevated Contributor RBAC on the storage account | Bicep template — required for FSLogix to set directory-level permissions on profile VHD containers |
| `AccessNetworkAsComputerObject = 0` in the FSLogix registry | Bicep Run Command — must be 0 for cloud-only Entra; setting it to 1 causes FSLogix to use the computer's Kerberos ticket which does not exist in a cloud-only environment |
| `GROUP_SKU_CLOUD_ONLY` tag on the Entra app registration manifest | deploy.ps1 post-deployment step |
| Admin consent granted on the Entra app registration | deploy.ps1 post-deployment step |
| `CloudKerberosTicketRetrievalEnabled = 1` on session hosts | **Manual** — deploy via Intune settings catalog policy targeting the AVD Devices group before users sign in |

> **Note:** Entra Kerberos does not support MFA for file share access. If you have Conditional Access policies enforcing MFA for Azure Storage, create an exclusion for the storage account or profile mounts will fail.

### Security considerations

The `defaultSharePermission: StorageFileDataSmbShareContributor` setting grants all authenticated users in your Entra tenant contributor access at the share level. This is a requirement of the cloud-only Kerberos preview — without it, share-level access is denied before authentication can complete.

This means fine-grained NTFS ACL-based access control at the directory and file level is not available in the same way as a traditional AD DS deployment. For FSLogix this is largely mitigated — each user's profile is isolated inside their own VHD container, and the elevated contributor role allows FSLogix to set ACLs on those containers so users cannot access each other's profiles.

For production environments the recommended mitigations are to remove `defaultSharePermission` and instead assign RBAC roles to a tightly controlled Entra group, apply Conditional Access policies to restrict which compliant devices can access Azure Storage, and consider data-level protection such as sensitivity labels where appropriate.

---

## Pre-requisites

Before deploying, ensure you have:

1. **An Entra ID security group for AVD Users** — the Object ID is required at deploy time. Found in Entra ID > Groups > select the group > Overview > Object ID
2. **An Entra ID security group for AVD Devices** *(optional — only required if using Intune)* — used for Intune policy targeting. Session hosts are added automatically on deployment
3. **Security defaults disabled** *(optional — only required if using Intune)* — security defaults enforce MFA for all users which blocks Intune auto-enrollment. Disable via **Entra ID > Properties > Manage security defaults**. Use Conditional Access policies instead for production environments
4. **Intune policy for `CloudKerberosTicketRetrievalEnabled`** — deploy a settings catalog policy setting `CloudKerberosTicketRetrievalEnabled = 1` targeting the AVD Devices group before users sign in. Without this, FSLogix cannot retrieve a Kerberos ticket at logon and profile mounts will fail
5. **Microsoft.Graph PowerShell module** — required for the post-deployment steps in deploy.ps1. Install with: `Install-Module Microsoft.Graph -Scope CurrentUser`

---

## Deployment — PowerShell

### 1. Clone the repository

```powershell
git clone https://github.com/creynolds1986/bicep-templates.git
cd AVD-Entra
```

### 2. Fill in your values

Open `deploy.config.ps1` and fill in your values. This file is separate from the script logic so your settings are never lost when the script is updated. The following parameters are required:

| Parameter | Description |
|---|---|
| `avdUsersGroupId` | Object ID of your AVD Users Entra ID security group |

The following parameters are optional and have sensible defaults:

| Parameter | Default | Description |
|---|---|---|
| `prefix` | `avd-lab` | Short prefix applied to all resource names |
| `location` | `uksouth` | Azure region to deploy into |
| `goldenImageId` | _(blank)_ | Full resource ID of a custom Managed Image or SIG version — leave blank to use the latest Windows 11 25H2 AVD marketplace image |
| `vmCount` | `2` | Number of session host VMs to deploy |
| `vmSize` | `Standard_D2as_v6` | Size of each session host VM |
| `enrollInIntune` | `true` | Set to `false` to skip Intune enrollment — if `true`, security defaults must be disabled in Entra ID |
| `vmSecurityType` | `TrustedLaunch` | Must match your golden image — use `Standard` if built on a standard VM |
| `vmAdminUsername` | `avdadmin` | Local admin username on each session host |
| `storageAccountSku` | `Premium_LRS` | Storage redundancy — use `Premium_ZRS` for zone redundancy |
| `fslogixProfileSizeGB` | `20` | Maximum size of each user's FSLogix profile VHDX in GB |
| `fslogixUserCount` | `4` | Number of users — used to calculate the file share quota |
| `tagEnvironment` | `lab` | Value for the environment tag on all resources — set to `''` to deploy without tags |
| `tagProject` | `avd` | Value for the project tag on all resources — set to `''` to deploy without tags |
| `enableMonitoring` | `false` | Set to `true` to deploy Log Analytics, AVD Insights, diagnostic settings and alerts |
| `logAnalyticsWorkspaceName` | `avd-lab-law` | Name for the Log Analytics workspace — only used if `enableMonitoring` is `true` |
| `logRetentionDays` | `30` | Log retention in days — allowed values: 30, 60, 90, 180, 365 |
| `alertEmailAddress` | `''` | Email address for alert notifications — leave blank to skip alerts |

### 3. Connect to Azure

```powershell
Connect-AzAccount
Set-AzContext -Subscription '<your-subscription-id>'
```

### 4. Run the deployment script

```powershell
.\deploy.ps1
```

The script prompts for the VM admin password securely, creates the resource group if it doesn't exist, deploys all resources, then automatically applies the `GROUP_SKU_CLOUD_ONLY` tag and grants admin consent on the storage account's Entra app registration. Requires `Microsoft.Graph` to be installed.

---

## FSLogix share quota calculation

The file share quota is calculated automatically:

```
quota = max(profileSizeGB × userCount, 100)
```

Azure Files Premium has a **minimum share size of 100 GB**. Examples:

| Profile size | Users | Calculated | Actual quota |
|---|---|---|---|
| 20 GB | 4 | 80 GB | **100 GB** (floor applied) |
| 20 GB | 6 | 120 GB | **120 GB** |
| 30 GB | 10 | 300 GB | **300 GB** |

---

## Troubleshooting

For detailed guidance on Entra Kerberos authentication for Azure Files, see the official Microsoft documentation:

[Enable Azure Active Directory Kerberos authentication for hybrid identities on Azure Files](https://learn.microsoft.com/en-us/azure/storage/files/storage-files-identity-auth-hybrid-identities-enable?tabs=azure-portal%2Cintune)

---

## Repository structure

| File/Folder | Purpose |
|---|---|
| `avd-lab.bicep` | Main Bicep template — all Azure resources defined here |
| `deploy.config.ps1` | Your values — fill this in once and it survives script updates |
| `deploy.ps1` | Deployment script logic — run this, do not edit |
| `createUiDefinition.json` | Portal wizard UI definition — kept for reference only, not used for deployment |
| `README.md` | This file |
