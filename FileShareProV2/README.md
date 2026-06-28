# FileShareProV2

Deploys an Azure Files Premium V2 storage account with Entra Kerberos authentication, and optionally creates a file share (enabled by default). File share size is in GB.

## Prerequisites

- Az PowerShell module
- Microsoft.Graph PowerShell module
- An existing resource group to deploy into

## Files

- `ProV2.bicep` - Bicep template that defines the storage account and file share
- `DeployProV2.ps1` - PowerShell script that deploys the template and configures Entra Kerberos

## What the script does

1. Checks for existing Azure and Graph connections, prompting to connect if not already
2. Deploys the Bicep template to the specified resource group
3. Grants admin consent to the storage account app registration in Entra ID
4. Adds the `kdc_enable_cloud_group_sids` tag to the app manifest to enable cloud group SID support

## Usage

```powershell
.\DeployProV2.ps1 -resourceGroupName "rg-client" -storageAccountName "stclient01" -fileShareName "sharename" -fileShareSize 50
```

Skip file share creation:

```powershell
.\DeployProV2.ps1 -deployFileShare $false
```

## Parameters

| Parameter | Default | Description |
|---|---|---|
| resourceGroupName | rg-yourname | Resource group to deploy into |
| storageAccountName | yourStorageAccount | Name of the storage account |
| bicepFilePath | .\ProV2.bicep | Path to the Bicep template |
| fileShareName | sharename | Name of the file share |
| fileShareSize | 32 | Share size in GB |
| fileShareIops | 3000 | Provisioned IOPS |
| fileShareThroughput | 100 | Provisioned throughput in MiB/s |
| deployFileShare | true | Whether to create the file share |
