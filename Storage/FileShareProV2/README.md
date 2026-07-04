# FileShareProV2

Deploys a fileshare storage account with Entra Kerberos authentication and optionally creates an Azure Files Premium V2 file share (enabled by default). File share size is in GB.

## Prerequisites

- Az PowerShell module
- Microsoft.Graph PowerShell module

## Files

- `ProV2.bicep` - Bicep template that defines the storage account and file share
- `DeployProV2.ps1` - PowerShell script that deploys the template and configures Entra Kerberos

## What the script does

1. Checks for existing Azure and Graph connections, prompting to connect if not already
2. Deploys the Bicep template to the specified resource group. If the group doesn't exist, it will create one. You can set the region using $resourceGroupRegion (default is uksouth)
3. Grants admin consent to the storage account app registration in Entra ID
4. Adds the `kdc_enable_cloud_group_sids` tag to the app manifest to enable cloud group SID support

## Usage

Existing resource group
```powershell
.\DeployProV2.ps1 -resourceGroupName "rg-client" -storageAccountName "stclient01" -fileShareName "sharename" -fileShareSize 50
```

Create new resource group

```powershell
.\DeployProV2.ps1 -resourceGroupName "rg-client" -resourceGroupRegion "westeurope" -storageAccountName "stclient01" -fileShareName "sharename" -fileShareSize 50
```

Skip file share creation:

```powershell
.\DeployProV2.ps1 -resourceGroupName "rg-client" -resourceGroupRegion "westeurope" -storageAccountName "stclient01" -deployFileShare $false
```

## Parameters

| Parameter | Default | Description |
|---|---|---|
| resourceGroupName | rg-yourname | Resource group to deploy into |
| resourceGroupRegion | uksouth | Azure region for the resource group if it needs to be created |
| storageAccountName | yourStorageAccount | Name of the storage account |
| bicepFilePath | .\ProV2.bicep | Path to the Bicep template |
| fileShareName | sharename | Name of the file share |
| replicationType | PremiumV2_LRS | Storage account SKU replication type. Supported values include PremiumV2_LRS, Premium_LRS, Premium_ZRS, Standard_LRS, Standard_GRS, Standard_RAGRS, Standard_ZRS, Standard_GZRS, Standard_RAGZRS |
| performanceTier | Premium | Storage account performance tier. Use Premium for Premium file shares |
| fileShareSize | 32 | Share size in GB |
| fileShareIops | 3000 | Provisioned IOPS |
| fileShareThroughput | 100 | Provisioned throughput in MiB/s |
| deployFileShare | true | Whether to create the file share |
| allowSharedKeyAccess | false | Enables storage account access keys when set to $true |


## Available options

- replicationType: Use values supported by the target Azure region and storage SKU availability. For Premium file shares, PremiumV2_LRS is the default choice.
- performanceTier: Typically Premium for Azure Files Premium / Premium V2 deployments. Standard is only appropriate for non-Premium storage account scenarios.
- Note: The replication type should match the selected performance tier. For example, Premium performance should use Premium replication types such as PremiumV2_LRS or Premium_LRS, while Standard performance should use Standard replication types such as Standard_LRS or Standard_GRS.
- deployFileShare: Set to $false to deploy the storage account without creating a file share.
- allowSharedKeyAccess: Set to $true to enable storage account access keys; the default is disabled.
