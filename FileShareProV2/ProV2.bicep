param storageAccount_name string = 'accountname'
param fileShare_name string = 'sharename'
param fileShare_size int = 32
param fileShare_iops int = 3000
param fileShare_throughput int = 100
param deployFileShare bool = true

resource storageAccount_name_resource 'Microsoft.Storage/storageAccounts@2026-04-01' = {
  name: storageAccount_name
  location: resourceGroup().location
  sku: {
    name: 'PremiumV2_LRS'
    tier: 'Premium'
  }
  kind: 'FileStorage'
  properties: {
    dualStackEndpointPreference: {
      publishIpv6Endpoint: false
    }
    dnsEndpointType: 'Standard'
    defaultToOAuthAuthentication: false
    publicNetworkAccess: 'Enabled'
    allowCrossTenantReplication: false
    azureFilesIdentityBasedAuthentication: {
      smbOAuthSettings: {
        isSmbOAuthEnabled: true
      }
      directoryServiceOptions: 'AADKERB'
    }
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    largeFileSharesState: 'Enabled'
    networkAcls: {
      ipv6Rules: []
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      requireInfrastructureEncryption: false
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

resource storageAccount_name_default 'Microsoft.Storage/storageAccounts/fileServices@2026-04-01' = {
  parent: storageAccount_name_resource
  name: 'default'
  sku: {
    name: 'PremiumV2_LRS'
    tier: 'Premium'
  }
  properties: {
    protocolSettings: {
      nfs: {
        encryptionInTransit: {
          required: true
        }
      }
      smb: {
        encryptionInTransit: {
          required: true
        }
        multichannel: {
          enabled: true
        }
      }
    }
    cors: {
      corsRules: []
    }
    shareDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2026-04-01' = if (deployFileShare) {
  parent: storageAccount_name_default
  name: fileShare_name
  properties: {
    shareQuota: fileShare_size
    provisionedIops: fileShare_iops
    provisionedBandwidthMibps: fileShare_throughput
    enabledProtocols: 'SMB'
  }
}
