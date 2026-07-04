# FileSharePAYG

Deploys a PAYG-style Azure Files storage account with Entra Kerberos authentication and creates an Azure Files share using the PAYG template.

## Prerequisites

- Az PowerShell module
- Microsoft.Graph PowerShell module

## Files

- `PAYG.bicep` - Bicep template that defines the storage account and file share
- `DeployPAYG.ps1` - PowerShell script that deploys the template and configures Entra Kerberos

## What the script does

1. Checks for existing Azure and Graph connections, prompting to connect if not already
2. Deploys the Bicep template to the specified resource group. If the group doesn't exist, it will create one. You can set the region using `$resourceGroupRegion` (default is `uksouth`)
3. Grants admin consent to the storage account app registration in Entra ID
4. Adds the `kdc_enable_cloud_group_sids` tag to the app manifest to enable cloud group SID support

## Usage

Existing resource group

```powershell
.\DeployPAYG.ps1 -resourceGroupName "rg-client" -storageAccountName "stclient01" -fileShareName "sharename"
```

Create new resource group

```powershell
.\DeployPAYG.ps1 -resourceGroupName "rg-client" -resourceGroupRegion "westeurope" -storageAccountName "stclient01" -fileShareName "sharename"
```

Use a different access tier or replication type

```powershell
.\DeployPAYG.ps1 -resourceGroupName "rg-client" -storageAccountName "stclient01" -fileShareName "sharename" -accessTier "Cool" -replicationType "Standard_GRS"
```

## Parameters

| Parameter | Default | Description |
|---|---|---|
| resourceGroupName | rg-yourname | Resource group to deploy into |
| resourceGroupRegion | uksouth | Azure region for the resource group if it needs to be created |
| storageAccountName | yourStorageAccount | Name of the storage account |
| bicepFilePath | .\PAYG.bicep | Path to the Bicep template |
| fileShareName | sharename | Name of the file share |
| accessTier | Hot | Storage account and share access tier. Common values include Hot and Cool |
| replicationType | Standard_LRS | Storage account SKU replication type. Common values include Standard_LRS, Standard_GRS, Standard_RAGRS |
| allowSharedKeyAccess | false | Enables storage account access keys when set to $true |

## Available options

- accessTier: Use `Hot` for frequently accessed data or `Cool` for lower-cost, less-frequently accessed data.
- replicationType: Choose a replication option supported in the target region and required by your durability needs.
- allowSharedKeyAccess: Set to $true to enable storage account access keys; the default is disabled.
