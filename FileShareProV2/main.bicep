param storageAccount_name string = 'accountname'

resource storageAccount_name_resource 'Microsoft.Storage/storageAccounts@2026-04-01' = {
  name: storageAccount_name
  location: 'uksouth'
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
