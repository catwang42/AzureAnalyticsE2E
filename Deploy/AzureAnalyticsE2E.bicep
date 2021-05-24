//********************************************************
// Global Parameters
//********************************************************

param aadDirectoryReaderPrincipalID string = 'b0d7a8aa-8447-4c83-b238-ec953ae990f6' //Service Principal used to Connect to SQL in Post Deployment script

@allowed([
  'default'
  'vNet'
])
@description('Deployment Mode')
param deploymentMode string = 'default'

@description('Resource Location')
param resourceLocation string = resourceGroup().location

@description('Unique Suffix')
param uniqueSuffix string = substring(uniqueString(resourceGroup().id),0,5)

//********************************************************
// Workload Deployment Control Parameters
//********************************************************

param ctrlDeployAzureRBAC bool = true   //Controls the deployment of Azure RBAC Assignments
param ctrlDeployPurview bool = true     //Controls the deployment of Azure Purview
param ctrlDeployAI bool = true          //Controls the deployment of Azure ML and Cognitive Services
param ctrlDeployStreaming bool = false   //Controls the deployment of EventHubs and Stream Analytics
param crtlDeployDataShare bool = true   //Controls the deployment of Azure Data Share
param ctrlPostDeployScript bool = true  //Controls the execution of post-deployment script
param ctrlAllowStoragePublicContainer bool = false //Controls the creation of data lake Public container
param ctrlDeployPrivateDNSZones bool = true //Controls the creation of private DNS zones for private links

//********************************************************
// Resource Config Parameters
//********************************************************

//vNet Parameters
@description('Virtual Network Name')
param vNetName string = 'azvnet${uniqueSuffix}'

@description('Virtual Network IP Address Space')
param vNetIPAddressPrefix string = '10.1.0.0/16'

@description('Virtual Network Subnet Name')
param vNetSubnetName string = 'default'

@description('Virtual Network Subnet Name')
param vNetSubnetIPAddressPrefix string = '10.1.0.0/24'
//----------------------------------------------------------------------

//Data Lake Parameters
@description('Data Lake Storage Account Name')
param dataLakeAccountName string = 'azdatalake${uniqueSuffix}'

@description('Data Lake Raw Zone Container Name')
param dataLakeRawZoneName string = 'raw'

@description('Data Lake Trusted Zone Container Name')
param dataLakeTrustedZoneName string = 'trusted'

@description('Data Lake Curated Zone Container Name')
param dataLakeCuratedZoneName string = 'curated'

@description('Data Lake Public Zone Container Name')
param dataLakePublicZoneName string = 'public'

@description('Data Lake Transient Zone Container Name')
param dataLakeTransientZoneName string = 'transient'

@description('Data Lake Sandpit Zone Container Name')
param dataLakeSandpitZoneName string = 'sandpit'

@description('Synapse Default Container Name')
param synapseDefaultContainerName string = 'system'
//----------------------------------------------------------------------


//Synapse Workspace Parameters
@description('Synapse Workspace Name')
param synapseWorkspaceName string = 'azsynapsewks${uniqueSuffix}'

@description('SQL Admin User Name')
param synapseSqlAdminUserName string = 'azsynapseadmin'

@description('SQL Admin User Name')
param synapseSqlAdminPassword string = 'P@ssw0rd123!'

@description('Synapse Managed Resource Group Name')
param synapseManagedRGName string = '${synapseWorkspaceName}-mrg'

@description('SQL Pool Name')
param synapseDedicatedSQLPoolName string = 'EnterpriseDW'

@description('SQL Pool SKU')
param synapseSQLPoolSKU string = 'DW200c'

@description('Spark Pool Name')
param synapseSparkPoolName string = 'SparkCluster'

@description('Spark Node Size')
param synapseSparkPoolNodeSize string = 'Small'

@description('Spark Min Node Count')
param synapseSparkPoolMinNodeCount int = 2

@description('Spark Max Node Count')
param synapseSparkPoolMaxNodeCount int = 2
//----------------------------------------------------------------------

//Synapse Private Link Hub Parameters
@description('Synapse Private Link Hub Name')
param synapsePrivateLinkHubName string = 'azsynapsehub${uniqueSuffix}'
//----------------------------------------------------------------------

//Purview Account Parameters
@description('Purview Account Name')
param purviewAccountName string = 'azpurview${uniqueSuffix}'
//----------------------------------------------------------------------

//Key Vault Parameters
@description('Data Lake Storage Account Name')
param keyVaultName string = 'azkeyvault${uniqueSuffix}'
//----------------------------------------------------------------------

//Azure Machine Learning Parameters
@description('Azure Machine Learning Workspace Name')
param azureMLWorkspaceName string = 'azmlwks${uniqueSuffix}'

@description('Azure Machine Learning Storage Account Name')
param azureMLStorageAccountName string = 'azmlstorage${uniqueSuffix}'

@description('Azure Machine Learning Application Insights Name')
param azureMLAppInsightsName string = 'azmlappinsights${uniqueSuffix}'
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

//Azure Data Share Parameters
@description('Azure Data Share Name')
param dataShareAccountName string = 'azdatashare${uniqueSuffix}'
//----------------------------------------------------------------------

//Azure Cognitive Services Account Parameters
@description('Azure Cognitive Services Account Name')
param cognitiveServiceAccountName string = 'azcognitivesvc${uniqueSuffix}'
//----------------------------------------------------------------------

//Azure Anomaly Detector Account Parameters
@description('Azure Anomaly Detector Account Name')
param anomalyDetectorName string = 'azanomalydetector${uniqueSuffix}'
//----------------------------------------------------------------------

//Azure EventHub Namespace Parameters
@description('Azure EventHub Namespace Name')
param eventHubNamespaceName string = 'azeventhubns${uniqueSuffix}'

@description('Azure EventHub Name')
param eventHubName string = 'azeventhub${uniqueSuffix}'

@description('Azure EventHub SKU')
param eventHubSku string = 'Standard'

@description('Azure EventHub Partition Count')
param eventHubPartitionCount int = 1
//----------------------------------------------------------------------

//Stream Analytics Job Parameters
@description('Azure Stream Analytics Job Name')
param streamAnalyticsJobName string = 'azstreamjob${uniqueSuffix}'

@description('Azure Stream Analytics Job Name')
param streamAnalyticsJobSku string = 'Standard'

//********************************************************
// Variables
//********************************************************
var dataLakeStorageAccountUrl = 'https://${dataLakeAccountName}.dfs.core.windows.net'

var azureRBACStorageBlobDataContributorRoleID = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' //Storage Blob Data Contributor Role
var azureRBACStorageBlobDataReaderRoleID = '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1' //Storage Blob Data Reader Role
var azureRBACReaderRoleID = 'acdd72a7-3385-48ef-bd42-f606fba81ae7' //Reader Role
var azureRBACOwnerRoleID = '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'  //Owner Role

var deploymentScriptUAMIName = toLower('${resourceGroup().name}-uami')

//********************************************************
// Resources
//********************************************************

//User-Assignment Managed Identity used to execute deployment scripts
resource r_deploymentScriptUAMI 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = if(ctrlPostDeployScript == true) {
  name: deploymentScriptUAMIName
  location: resourceLocation

}

//vNet created for network protected environments (deploymentMode == 'vNet')
resource r_vNet 'Microsoft.Network/virtualNetworks@2020-11-01' = if(deploymentMode == 'vNet'){
  name:vNetName
  location: resourceLocation
  properties:{
    addressSpace:{
      addressPrefixes:[
        vNetIPAddressPrefix
      ]
    }
  }
}

resource r_subNet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' = {
  name: vNetSubnetName
  parent: r_vNet
  properties: {
    addressPrefix: vNetSubnetIPAddressPrefix
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies:'Enabled'
  }
}

//Data Lake Storage Account
resource r_dataLakeStorageAccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: dataLakeAccountName
  location: resourceLocation
  properties:{
    isHnsEnabled: true
    accessTier:'Hot'
    allowBlobPublicAccess: (ctrlAllowStoragePublicContainer && deploymentMode != 'vNet')
    networkAcls: {
      defaultAction: (deploymentMode == 'vNet')? 'Deny' : 'Allow'
      bypass:'AzureServices'
    }
  }
  kind:'StorageV2'
  sku: {
      name: 'Standard_RAGRS'
  }
}

//Private Link for Data Lake DFS
resource r_dataLakeStorageAccountPrivateLink 'Microsoft.Network/privateEndpoints@2020-11-01' = if(deploymentMode == 'vNet') {
  name: '${r_dataLakeStorageAccount.name}-dfs'
  location:resourceLocation
  properties:{
    subnet:{
      id: r_subNet.id
    }
    privateLinkServiceConnections:[
      {
        name:'${r_dataLakeStorageAccount.name}-dfs'
        properties:{
          privateLinkServiceId: r_dataLakeStorageAccount.id
          groupIds:[
            'dfs'
          ]
        }
      }
    ]
  }

  resource r_vNetPrivateDNSZoneGroupStorageDFS 'privateDnsZoneGroups' = {
    name: 'default'
    properties:{
      privateDnsZoneConfigs:[
        {
          name:'privatelink-dfs-core-windows-net'
          properties:{
            privateDnsZoneId: m_privateDNSZoneStorageDFS.outputs.dnsZoneID
          }
        }
      ]
    }
  }
}

module m_privateDNSZoneStorageDFS './modules/PrivateDNSZone.bicep' = if(deploymentMode == 'vNet') {
  name: 'PrivateDNSZoneStorageDFS'
  params: {
    dnsZoneName: 'privatelink.dfs.core.windows.net'
    vNetID: r_vNet.id
    vNetName: r_vNet.name
  }
}


////Private DNS zone for privatelink.dfs.core.windows.net
// resource r_privateDNSZoneStorageDFS 'Microsoft.Network/privateDnsZones@2020-06-01' = if(deploymentMode == 'vNet') {
//   name: 'privatelink.dfs.core.windows.net'
//   location: 'global'

//   resource r_vNetPrivateDNSZoneStorageDFSLink 'virtualNetworkLinks' = {
//     name: 'privatelink.dfs.core.windows.net-${r_vNet.name}'
//     location: 'global'
//     properties:{
//       virtualNetwork:{
//         id:r_vNet.id
//       }
//       registrationEnabled:false
//     }
//   }
// }

//Data Lake Zone Containers

param privateContainerNames array = [
  dataLakeRawZoneName
  dataLakeTrustedZoneName
  dataLakeCuratedZoneName
  dataLakeSandpitZoneName
  synapseDefaultContainerName
]

resource r_dataLakePrivateContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-02-01' = [for containerName in privateContainerNames: {
  name:'${r_dataLakeStorageAccount.name}/default/${containerName}'
}]

//Public Zone Container
resource r_dataLakePublicContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-02-01' = if(ctrlAllowStoragePublicContainer == true && deploymentMode != 'vNet') {
  name:'${r_dataLakeStorageAccount.name}/default/${dataLakePublicZoneName}'
  properties:{
    publicAccess:'Blob' //TODO: Edit public access for SolutionAccelerator-vNet
  }
}

//Synapse Workspace
resource r_synapseWorkspace 'Microsoft.Synapse/workspaces@2021-03-01' = {
  name:synapseWorkspaceName
  location: resourceLocation
  identity:{
    type:'SystemAssigned'
  }
  properties:{
    defaultDataLakeStorage:{
      accountUrl: dataLakeStorageAccountUrl
      filesystem: synapseDefaultContainerName
    }
    sqlAdministratorLogin: synapseSqlAdminUserName
    sqlAdministratorLoginPassword: synapseSqlAdminPassword
    managedResourceGroupName: synapseManagedRGName
    managedVirtualNetwork: (deploymentMode == 'vNet') ? 'default' : ''
    managedVirtualNetworkSettings:{
      preventDataExfiltration:true
    }
    purviewConfiguration:{
      purviewResourceId: r_purviewAccount.id
    }
  }

  resource r_workspaceAADAdmin 'administrators' = {
    name:'activeDirectory'
    properties:{
      administratorType:'ActiveDirectory'
      tenantId: subscription().tenantId
      sid: r_deploymentScriptUAMI.properties.principalId
    }
  }

  //Dedicated SQL Pool
  resource r_sqlPool 'sqlPools' = {
    name: synapseDedicatedSQLPoolName
    location: resourceLocation
    sku:{
      name:synapseSQLPoolSKU
    }
    properties:{
      createMode:'Default'
      collation: 'SQL_Latin1_General_CP1_CI_AS'
    }
  }

  //Default Frewall Rules
  resource r_synapseWorkspaceDefaultFirewall 'firewallRules' = if (deploymentMode == 'default'){
    name: 'AllowAllNetworks'
    properties:{
      startIpAddress: '0.0.0.0'
      endIpAddress: '255.255.255.255'
    }
  }

  //Set Synapse MSI as SQL Admin
  resource r_managedIdentitySqlControlSettings 'managedIdentitySqlControlSettings' = {
    name: 'default'
    properties:{
      grantSqlControlToManagedIdentity:{
        desiredState: 'Enabled'
      }
    }
  }

  //Spark Pool
  resource r_sparkPool 'bigDataPools' = {
    name: synapseSparkPoolName
    location: resourceLocation
    properties:{
      autoPause:{
        enabled:true
        delayInMinutes: 15
      }
      nodeSize: synapseSparkPoolNodeSize
      nodeSizeFamily:'MemoryOptimized'
      sparkVersion: '2.4'
      autoScale:{
        enabled:true
        minNodeCount: synapseSparkPoolMinNodeCount
        maxNodeCount: synapseSparkPoolMaxNodeCount
      }
    }
  }
}

//Azure Synapse Private Link Hub
resource r_synapsePrivateLinkhub 'Microsoft.Synapse/privateLinkHubs@2021-03-01' = if (deploymentMode == 'vNet') {
  name: synapsePrivateLinkHubName
  location:resourceLocation
}


//Private DNS Zones required for Synapse Private Link
//privatelink.sql.azuresynapse.net
module m_privateDNSZoneSynapseSQL './modules/PrivateDNSZone.bicep' = if(deploymentMode == 'vNet') {
  name: 'PrivateDNSZoneSynapseSQL'
  params: {
    dnsZoneName: 'privatelink.sql.azuresynapse.net'
    vNetID: r_vNet.id
    vNetName: r_vNet.name
  }
}

//Private DNS Zones required for Synapse Private Link
//privatelink.dev.azuresynapse.net
module m_privateDNSZoneSynapseDev './modules/PrivateDNSZone.bicep' = if(deploymentMode == 'vNet') {
  name: 'PrivateDNSZoneSynapseDev'
  params: {
    dnsZoneName: 'privatelink.dev.azuresynapse.net'
    vNetID: r_vNet.id
    vNetName: r_vNet.name
  }
}

//Private DNS Zones required for Synapse Private Link
//privatelink.azuresynapse.net
module m_privateDNSZoneSynapseWeb './modules/PrivateDNSZone.bicep' = if(deploymentMode == 'vNet') {
  name: 'PrivateDNSZoneSynapseWeb'
  params: {
    dnsZoneName: 'privatelink.azuresynapse.net'
    vNetID: r_vNet.id
    vNetName: r_vNet.name
  }
}

//Private Endpoint for Synapse SQL
module m_synapseSQLPrivateLink 'modules/PrivateEndpoint.bicep' = if(deploymentMode == 'vNet') {
  name: 'SynapseSQLPrivateLink'
  params: {
    groupID: 'Sql'
    privateDnsZoneConfigName: 'privatelink-sql-azuresynapse-net'
    privateDnsZoneId: m_privateDNSZoneSynapseSQL.outputs.dnsZoneID
    privateEndpoitName: '${r_synapseWorkspace.name}-sql'
    privateLinkServiceId: r_synapseWorkspace.id
    resourceLocation: resourceLocation
    subnetID: r_subNet.id
  }
}

//Private Endpoint for Synapse SQL Serverless
module m_synapseSQLServerlessPrivateLink 'modules/PrivateEndpoint.bicep' = if(deploymentMode == 'vNet') {
  name: 'SynapseSQLServerlessPrivateLink'
  params: {
    groupID: 'SqlOnDemand'
    privateDnsZoneConfigName: 'privatelink-sql-azuresynapse-net'
    privateDnsZoneId: m_privateDNSZoneSynapseSQL.outputs.dnsZoneID
    privateEndpoitName: '${r_synapseWorkspace.name}-sqlserverless'
    privateLinkServiceId: r_synapseWorkspace.id
    resourceLocation: resourceLocation
    subnetID: r_subNet.id
    deployDNSZoneGroup:false
  }
}

//Private Endpoint for Synapse Dev
module m_synapseDevPrivateLink 'modules/PrivateEndpoint.bicep' = if(deploymentMode == 'vNet') {
  name: 'SynapseDevPrivateLink'
  params: {
    groupID: 'Dev'
    privateDnsZoneConfigName: 'privatelink-web-azuresynapse-net'
    privateDnsZoneId: m_privateDNSZoneSynapseDev.outputs.dnsZoneID
    privateEndpoitName: '${r_synapseWorkspace.name}-dev'
    privateLinkServiceId: r_synapseWorkspace.id
    resourceLocation: resourceLocation
    subnetID: r_subNet.id
  }
}

//Private Endpoint for Synapse Web
module m_synapseWebPrivateLink 'modules/PrivateEndpoint.bicep' = if(deploymentMode == 'vNet') {
  name: 'SynapseWebPrivateLink'
  params: {
    groupID: 'Web'
    privateDnsZoneConfigName: 'privatelink-dev-azuresynapse-net'
    privateDnsZoneId: m_privateDNSZoneSynapseWeb.outputs.dnsZoneID
    privateEndpoitName: '${r_synapseWorkspace.name}-web'
    privateLinkServiceId: r_synapsePrivateLinkhub.id
    resourceLocation: resourceLocation
    subnetID: r_subNet.id
  }
}

// //Private Endpoint for Synapse SQL
// resource r_synapseSQLPrivateLink 'Microsoft.Network/privateEndpoints@2020-11-01' = if(deploymentMode == 'vNet') {
//   name: '${r_synapseWorkspace.name}-sql'
//   location:resourceLocation
//   properties:{
//     subnet:{
//       id: r_subNet.id
//     }
//     privateLinkServiceConnections:[
//       {
//         name:'${r_synapseWorkspace.name}-sql'
//         properties:{
//           privateLinkServiceId: r_synapseWorkspace.id
//           groupIds:[
//             'Sql'
//           ]
//         }
//       }
//     ]
//   }

//   resource r_vNetPrivateDNSZoneGroupSynapseSQL 'privateDnsZoneGroups' = {
//     name: 'default'
//     properties:{
//       privateDnsZoneConfigs:[
//         {
//           name:'privatelink-sql-azuresynapse-net'
//           properties:{
//             privateDnsZoneId: m_privateDNSZoneSynapseSQL.outputs.dnsZoneID
//           }
//         }
//       ]
//     }
//   }
// }

// //Private Endpoint for Synapse SQL Serverless
// resource r_synapseSQLServerlessPrivateLink 'Microsoft.Network/privateEndpoints@2020-11-01' = if(deploymentMode == 'vNet') {
//   name: '${r_synapseWorkspace.name}-sqlserverless'
//   location:resourceLocation
//   properties:{
//     subnet:{
//       id: r_subNet.id
//     }
//     privateLinkServiceConnections:[
//       {
//         name:'${r_synapseWorkspace.name}-sqlserverless'
//         properties:{
//           privateLinkServiceId: r_synapseWorkspace.id
//           groupIds:[
//             'SqlOnDemand'
//           ]
//         }
//       }
//     ]
//   }
// }

// //Private Endpoint for Synapse DEV
// resource r_synapseDevPrivateLink 'Microsoft.Network/privateEndpoints@2020-11-01' = if(deploymentMode == 'vNet') {
//   name: '${r_synapseWorkspace.name}-dev'
//   location:resourceLocation
//   properties:{
//     subnet:{
//       id: r_subNet.id
//     }
//     privateLinkServiceConnections:[
//       {
//         name:'${r_synapseWorkspace.name}-dev'
//         properties:{
//           privateLinkServiceId: r_synapseWorkspace.id
//           groupIds:[
//             'Dev'
//           ]
//         }
//       }
//     ]
//   }

//   resource r_vNetPrivateDNSZoneGroupSynapseSQL 'privateDnsZoneGroups' = {
//     name: 'default'
//     properties:{
//       privateDnsZoneConfigs:[
//         {
//           name:'privatelink-dev-azuresynapse-net'
//           properties:{
//             privateDnsZoneId: m_privateDNSZoneSynapseDev.outputs.dnsZoneID
//           }
//         }
//       ]
//     }
//   }
// }

// //Private Endpoint for Synapse Web
// resource r_synapseWebPrivateLink 'Microsoft.Network/privateEndpoints@2020-11-01' = if(deploymentMode == 'vNet') {
//   name: '${r_synapseWorkspace.name}-web'
//   location:resourceLocation
//   properties:{
//     subnet:{
//       id: r_subNet.id
//     }
//     privateLinkServiceConnections:[
//       {
//         name:'${r_synapseWorkspace.name}-web'
//         properties:{
//           privateLinkServiceId: r_synapsePrivateLinkhub.id
//           groupIds:[
//             'Web'
//           ]
//         }
//       }
//     ]
//   }

//   resource r_vNetPrivateDNSZoneGroupSynapseWeb 'privateDnsZoneGroups' = {
//     name: 'default'
//     properties:{
//       privateDnsZoneConfigs:[
//         {
//           name:'privatelink-web-azuresynapse-net'
//           properties:{
//             privateDnsZoneId: m_privateDNSZoneSynapseWeb.outputs.dnsZoneID
//           }
//         }
//       ]
//     }
//   }
// }



// //Private DNS zone for privatelink.dfs.core.windows.net
// resource r_privateDNSZoneSynapseSQL 'Microsoft.Network/privateDnsZones@2020-06-01' = if(deploymentMode == 'vNet') {
//   name: 'privatelink.sql.azuresynapse.net'
//   location: 'global'

//   resource r_vNetPrivateDNSZoneStorageDFSLink 'virtualNetworkLinks' = {
//     name: 'privatelink.sql.azuresynapse.net-${r_vNet.name}'
//     location: 'global'
//     properties:{
//       virtualNetwork:{
//         id:r_vNet.id
//       }
//       registrationEnabled:false
//     }
//   }
// }

// //Private DNS zone for privatelink.dev.azuresynapse.net
// resource r_privateDNSZoneSynapseDev 'Microsoft.Network/privateDnsZones@2020-06-01' = if(deploymentMode == 'vNet') {
//   name: 'privatelink.dev.azuresynapse.net'
//   location: 'global'

//   resource r_vNetPrivateDNSZoneStorageDFSLink 'virtualNetworkLinks' = {
//     name: 'privatelink.dev.azuresynapse.net-${r_vNet.name}'
//     location: 'global'
//     properties:{
//       virtualNetwork:{
//         id:r_vNet.id
//       }
//       registrationEnabled:false
//     }
//   }
// }

// //Private DNS zone for privatelink.azuresynapse.net
// resource r_privateDNSZoneSynapseWeb 'Microsoft.Network/privateDnsZones@2020-06-01' = if(deploymentMode == 'vNet') {
//   name: 'privatelink.azuresynapse.net'
//   location: 'global'

//   resource r_vNetPrivateDNSZoneStorageDFSLink 'virtualNetworkLinks' = {
//     name: 'privatelink.azuresynapse.net-${r_vNet.name}'
//     location: 'global'
//     properties:{
//       virtualNetwork:{
//         id:r_vNet.id
//       }
//       registrationEnabled:false
//     }
//   }
// }

//Cognitive Services Account
resource r_cognitiveServices 'Microsoft.CognitiveServices/accounts@2017-04-18' = if(ctrlDeployAI == true){
  name: cognitiveServiceAccountName
  location: resourceLocation
  kind: 'CognitiveServices'
  sku:{
    name: 'S0'
  }
}

//Anomaly Detector Account
resource r_anomalyDetector 'Microsoft.CognitiveServices/accounts@2017-04-18' = if(ctrlDeployAI == true){
  name: anomalyDetectorName
  location: resourceLocation
  kind: 'AnomalyDetector'
  sku:{
    name: 'S0'
  }
}

//Key Vault
resource r_keyVault 'Microsoft.KeyVault/vaults@2021-04-01-preview' = {
  name: keyVaultName
  location: resourceLocation
  properties:{
    tenantId: subscription().tenantId
    enabledForDeployment:true
    enableSoftDelete:true
    sku:{
      name:'standard'
      family:'A'
    }
    networkAcls: {
      defaultAction: (deploymentMode == 'vNet')? 'Deny' : 'Allow'
      bypass:'AzureServices'
    }
    accessPolicies:[
      //Access Policy to allow Synapse to Get and List Secrets
      //https://docs.microsoft.com/en-us/azure/data-factory/how-to-use-azure-key-vault-secrets-pipeline-activities
      {
        objectId: r_synapseWorkspace.identity.principalId
        tenantId: subscription().tenantId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
      //Access Policy to allow Purview to Get and List Secrets
      //https://docs.microsoft.com/en-us/azure/purview/manage-credentials#grant-the-purview-managed-identity-access-to-your-azure-key-vault
      {
        objectId: r_purviewAccount.identity.principalId
        tenantId: subscription().tenantId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
      //Access Policy to allow Deployment Script UAMI to Get, Set and List Secrets
      //https://docs.microsoft.com/en-us/azure/purview/manage-credentials#grant-the-purview-managed-identity-access-to-your-azure-key-vault
      {
        objectId: r_deploymentScriptUAMI.properties.principalId
        tenantId: subscription().tenantId
        permissions: {
          secrets: [
            'get'
            'list'
            'set'
          ]
        }
      }
    ]
  }

  resource r_aadDirectoryReaderPrincipalIDSecret 'secrets' = {
    name:'AADDirectoryReaderPrincipalID'
    properties:{
      value:aadDirectoryReaderPrincipalID
    }
  }

  resource r_cognitiveServicesAccountKey 'secrets' = if(ctrlDeployAI == true){
    name:'${r_cognitiveServices.name}-Key'
    properties:{
      value: listKeys(r_cognitiveServices.id,r_cognitiveServices.apiVersion).key1
    }
  }

  resource r_anomalyDetectorAccountKey 'secrets' = if(ctrlDeployAI == true){
    name:'${r_anomalyDetector.name}-Key'
    properties:{
      value: listKeys(r_anomalyDetector.id,r_anomalyDetector.apiVersion).key1
    }
  }
}

module m_privateDNSZoneKeyVault 'modules/PrivateDNSZone.bicep' = if(deploymentMode == 'vNet') {
  name: 'privatelink.vaultcore.azure.net'
  params: {
    dnsZoneName: 'privatelink.vaultcore.azure.net-${r_vNet.name}'
    vNetID: r_vNet.id
    vNetName: r_vNet.name
  }
}

module m_keyVaultPrivateLink 'modules/PrivateEndpoint.bicep' = if(deploymentMode == 'vNet') {
  name: 'KeyVaultPrivateLink'
  params: {
    groupID: 'vault'
    privateDnsZoneConfigName: 'privatelink-vaultcore-azure-net'
    privateDnsZoneId: m_privateDNSZoneKeyVault.outputs.dnsZoneID
    privateEndpoitName: r_keyVault.name
    privateLinkServiceId: r_keyVault.id
    resourceLocation: resourceLocation
    subnetID: r_subNet.id
  }
}

// //Private DNS zone for privatelink.vaultcore.azure.net
// resource r_privateDNSZoneKeyVault 'Microsoft.Network/privateDnsZones@2020-06-01' = if(deploymentMode == 'vNet') {
//   name: 'privatelink.vaultcore.azure.net'
//   location: 'global'

//   resource r_vNetPrivateDNSZoneKeyVaultLink 'virtualNetworkLinks' = {
//     name: 'privatelink.vaultcore.azure.net-${r_vNet.name}'
//     location: 'global'
//     properties:{
//       virtualNetwork:{
//         id:r_vNet.id
//       }
//       registrationEnabled:false
//     }
//   }
// }



// //Private Link for Key Vault
// resource r_keyVaultPrivateLink 'Microsoft.Network/privateEndpoints@2020-11-01' = if(deploymentMode == 'vNet') {
//   name: r_keyVault.name
//   location:resourceLocation
//   properties:{
//     subnet:{
//       id: r_subNet.id
//     }
//     privateLinkServiceConnections:[
//       {
//         name:r_keyVault.name
//         properties:{
//           privateLinkServiceId: r_keyVault.id
//           groupIds:[
//             'vault'
//           ]
//         }
//       }
//     ]
//   }

//   resource r_vNetPrivateDNSZoneGroupStorageDFS 'privateDnsZoneGroups' = {
//     name: 'default'
//     properties:{
//       privateDnsZoneConfigs:[
//         {
//           name:'privatelink-vaultcore-azure-net'
//           properties:{
//             privateDnsZoneId: m_privateDNSZoneKeyVault.outputs.dnsZoneID
//           }
//         }
//       ]
//     }
//   }
// }

//Data Share Account
resource r_dataShareAccount 'Microsoft.DataShare/accounts@2020-09-01' = if(crtlDeployDataShare == true) {
  name:dataShareAccountName
  location:resourceLocation
  identity:{
    type:'SystemAssigned'
  }
}

//Purview Account
resource r_purviewAccount 'Microsoft.Purview/accounts@2020-12-01-preview' = if(ctrlDeployPurview == true){
  name: purviewAccountName
  location: resourceLocation
  identity:{
    type:'SystemAssigned'
  }
  sku:{
    name:'Standard'
    capacity: 4
  }
  properties:{
    publicNetworkAccess: (deploymentMode == 'vNet') ? 'Disabled' : 'Enabled'
  }
}

//Azure ML Storage Account
resource r_azureMLStorage 'Microsoft.Storage/storageAccounts@2021-02-01' = if(ctrlDeployAI == true) {
  name:azureMLStorageAccountName
  location:resourceLocation
  kind:'StorageV2'
  sku:{
    name:'Standard_LRS'
    tier:'Standard'
  }
  properties:{
    encryption:{
      services:{
        blob:{
          enabled:true
        }
        file:{
          enabled:true
        }
      }
      keySource:'Microsoft.Storage'
    }
  }
}

resource r_azureMLAppInsights 'Microsoft.Insights/components@2020-02-02-preview' = if(ctrlDeployAI == true) {
  name: azureMLAppInsightsName
  location:resourceLocation
  kind:'web'
  properties:{
    Application_Type:'web'
  }
}

resource r_azureMLWorkspace 'Microsoft.MachineLearningServices/workspaces@2021-04-01' = if(ctrlDeployAI == true) {
  name: azureMLWorkspaceName
  location: resourceLocation
  sku:{
    name: 'Basic'
    tier: 'Basic'
  }
  identity:{
    type:'SystemAssigned'
  }
  properties:{
    friendlyName: azureMLWorkspaceName
    keyVault: r_keyVault.id
    storageAccount: r_azureMLStorage.id
    applicationInsights: r_azureMLAppInsights.id
  }

  resource r_azureMLSynapseSparkCompute 'computes' = {
    name: 'SynapseSparkPool'
    location: resourceLocation
    properties:{
      computeType:'SynapseSpark'
      resourceId: r_synapseWorkspace::r_sparkPool.id
    }
  }
}

resource r_azureMLSynapseLinkedService 'Microsoft.MachineLearningServices/workspaces/linkedServices@2020-09-01-preview' = if(ctrlDeployAI == true) {
  name: r_synapseWorkspace.name
  location: resourceLocation
  parent: r_azureMLWorkspace
  identity:{
    type:'SystemAssigned'
  }
  properties:{
    linkedServiceResourceId: r_synapseWorkspace.id
  }
}

resource r_eventHubNamespace 'Microsoft.EventHub/namespaces@2017-04-01' = if(ctrlDeployStreaming == true) {
  name: eventHubNamespaceName
  location: resourceLocation
  sku:{
    name:eventHubSku
    tier:eventHubSku
    capacity:1
  }

  resource r_eventHub 'eventhubs' = {
    name:eventHubName
    properties:{
      messageRetentionInDays:7
      partitionCount:eventHubPartitionCount
      captureDescription:{
        enabled:true
        skipEmptyArchives: true
        encoding: 'Avro'
        intervalInSeconds: 300
        sizeLimitInBytes: 314572800
        destination: {
          name: 'EventHubArchive.AzureBlockBlob'
          properties: {
            storageAccountResourceId: r_dataLakeStorageAccount.id
            blobContainer: 'raw'
            archiveNameFormat: '{Namespace}/{EventHub}/{PartitionId}/{Year}/{Month}/{Day}/{Hour}/{Minute}/{Second}'
          }
        }
      }
    }
  }
}

resource r_streamAnalyticsJob 'Microsoft.StreamAnalytics/streamingjobs@2017-04-01-preview' = if(ctrlDeployStreaming == true) {
  name: streamAnalyticsJobName
  location: resourceLocation
  properties:{
    sku:{
      name:streamAnalyticsJobSku
    }
  }
}

//********************************************************
// Role Assignments
//********************************************************

//Synapse Workspace Role Assignment as Blob Data Contributor Role in the Data Lake Storage Account
//https://docs.microsoft.com/en-us/azure/synapse-analytics/security/how-to-grant-workspace-managed-identity-permissions
resource r_dataLakeRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (ctrlDeployAzureRBAC == true) {
  name: guid(r_synapseWorkspace.name, r_dataLakeStorageAccount.name)
  scope: r_dataLakeStorageAccount
  properties:{
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRBACStorageBlobDataContributorRoleID)
    principalId: r_synapseWorkspace.identity.principalId
    principalType:'ServicePrincipal'
  }
}

//Assign Reader Role to Purview MSI in the Resource Group as per https://docs.microsoft.com/en-us/azure/purview/register-scan-synapse-workspace
resource r_purviewRGReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (ctrlDeployAzureRBAC == true) {
  name: guid(resourceGroup().name, r_purviewAccount.name, 'Reader')
  properties:{
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRBACReaderRoleID)
    principalId: r_purviewAccount.identity.principalId
    principalType:'ServicePrincipal'
  }
}

//Assign Storage Blob Reader Role to Purview MSI in the Resource Group as per https://docs.microsoft.com/en-us/azure/purview/register-scan-synapse-workspace
resource r_purviewRGStorageBlobDataReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (ctrlDeployAzureRBAC == true) {
  name: guid(resourceGroup().name, r_purviewAccount.name, 'Storage Blob Reader')
  properties:{
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRBACStorageBlobDataReaderRoleID)
    principalId: r_purviewAccount.identity.principalId
    principalType:'ServicePrincipal'
  }
}

//Assign Storage Blob Data Reader Role to Azure ML MSI in the Data Lake Account as per https://docs.microsoft.com/en-us/azure/machine-learning/how-to-identity-based-data-access
resource r_azureMLStorageBlobDataReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (ctrlDeployAzureRBAC == true && ctrlDeployAI == true) {
  name: guid(r_dataLakeStorageAccount.name, r_azureMLWorkspace.name, 'Storage Blob Data Reader')
  scope:r_dataLakeStorageAccount
  properties:{
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRBACStorageBlobDataReaderRoleID)
    principalId: r_azureMLWorkspace.identity.principalId
    principalType:'ServicePrincipal'
  }
}

//Assign Storage Blob Data Reader Role to Azure Data Share in the Data Lake Account as per https://docs.microsoft.com/en-us/azure/data-share/concepts-roles-permissions
resource r_azureDataShareStorageBlobDataReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (ctrlDeployAzureRBAC == true) {
  name: guid(r_dataLakeStorageAccount.name, r_dataShareAccount.name, 'Storage Blob Data Reader')
  scope:r_dataLakeStorageAccount
  properties:{
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRBACStorageBlobDataReaderRoleID)
    principalId: r_dataShareAccount.identity.principalId
    principalType:'ServicePrincipal'
  }
}

//Assign Owner Role to UAMI in the Synapse Workspace. UAMI needs to be Owner so it can assign itself as Synapse Admin and create resources in the Data Plane.
resource r_synapseWorkspaceOwnerRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (ctrlDeployAzureRBAC == true) {
  name: guid(r_synapseWorkspace.name, r_deploymentScriptUAMI.name)
  scope: r_synapseWorkspace
  properties:{
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRBACOwnerRoleID)
    principalId: r_deploymentScriptUAMI.properties.principalId
    principalType:'ServicePrincipal'
  }
}

//********************************************************
// Post Deployment Scripts
//********************************************************

//Synapse Deployment Script
var synapsePostDeploymentPSScript = './scripts/PostDeploy.ps1'

resource r_synapsePostDeploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name:'SynapsePostDeploymentScript'
  dependsOn: [
    r_synapseWorkspaceOwnerRoleAssignment
  ]
  location:resourceLocation
  kind:'AzurePowerShell'
  identity:{
    type:'UserAssigned'
    userAssignedIdentities: {
      '${r_deploymentScriptUAMI.id}': {}
    }
  }
  properties:{
    azPowerShellVersion:'3.0'
    cleanupPreference: 'OnExpiration'
    retentionInterval: 'P1D'
    timeout:'PT30M'
    arguments: '-DeploymentMode ${deploymentMode} -WorkspaceName ${r_synapseWorkspace.name} -SynapseSqlAdminUserName ${synapseSqlAdminUserName} -SynapseSqlAdminPassword ${synapseSqlAdminPassword} -UAMIIdentityID ${r_deploymentScriptUAMI.properties.principalId} -KeyVaultName ${r_keyVault.name} -KeyVaultID ${r_keyVault.id} -PurviewAccountName ${r_purviewAccount.name} -AzureMLWorkspaceName ${r_azureMLWorkspace.name} -AzMLSynapseLinkedServiceIdentityID ${r_azureMLSynapseLinkedService.identity.principalId} -DataLakeStorageAccountName ${r_dataLakeStorageAccount.name} -DataLakeStorageAccountID ${r_dataLakeStorageAccount.id}'
    
    scriptContent: synapsePostDeploymentPSScript
  }
}

//********************************************************
// Output
//********************************************************

output dataLakeStorageAccountID string = r_dataLakeStorageAccount.id
output synapseWorkspaceID string = r_synapseWorkspace.id
output vNetSubNetID string = r_subNet.id
