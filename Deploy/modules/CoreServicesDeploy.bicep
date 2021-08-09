param deploymentMode string
param resourceLocation string

param ctrlAllowStoragePublicContainer bool
param ctrlDeployPrivateDNSZones bool

param vNetSubnetID string

param dataLakeAccountName string
param allowSharedKeyAccess bool
param dataLakeRawZoneName string
param dataLakeTrustedZoneName string
param dataLakeCuratedZoneName string
param dataLakePublicZoneName string
param dataLakeTransientZoneName string
param dataLakeSandpitZoneName string
param synapseDefaultContainerName string

param synapseWorkspaceName string
param synapseSqlAdminUserName string
param synapseSqlAdminPassword string
param synapseManagedRGName string
param synapseDedicatedSQLPoolName string
param synapseSQLPoolSKU string
param synapseSparkPoolName string
param synapseSparkPoolNodeSize string
param synapseSparkPoolMinNodeCount int
param synapseSparkPoolMaxNodeCount int
param synapsePrivateLinkHubName string

param purviewAccountID string
param uamiPrincipalID string

var storageEnvironmentDNS = environment().suffixes.storage
var dataLakeStorageAccountUrl = 'https://${dataLakeAccountName}.dfs.${storageEnvironmentDNS}'
var azureRBACStorageBlobDataContributorRoleID = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' //Storage Blob Data Contributor Role
var azureRBACOwnerRoleID = '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'  //Owner Role

//Data Lake Storage Account
resource r_dataLakeStorageAccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: dataLakeAccountName
  location: resourceLocation
  properties:{
    isHnsEnabled: true
    accessTier:'Hot'
    allowBlobPublicAccess: (ctrlAllowStoragePublicContainer && deploymentMode != 'vNet')
    allowSharedKeyAccess: allowSharedKeyAccess
    networkAcls: {
      defaultAction: (deploymentMode == 'vNet')? 'Deny' : 'Allow'
      bypass:'AzureServices'
      resourceAccessRules: [
        {
          tenantId: subscription().tenantId
          resourceId: r_synapseWorkspace.id
        }
    ]
    }
  }
  kind:'StorageV2'
  sku: {
      name: 'Standard_RAGRS'
  }
}

//Private Link for Data Lake DFS
module m_dataLakeStorageAccountPrivateLink './PrivateEndpoint.bicep' = if(deploymentMode == 'vNet'){
  name: '${r_dataLakeStorageAccount.name}-dfs'
  params: {
    groupID: 'dfs'
    privateEndpoitName: '${r_dataLakeStorageAccount.name}-dfs'
    privateLinkServiceId: r_dataLakeStorageAccount.id
    resourceLocation: resourceLocation
    subnetID: vNetSubnetID
    deployDNSZoneGroup: ctrlDeployPrivateDNSZones
    privateDNSZoneConfigs: [
      {
        name:'privatelink-dfs-core-windows-net'
        properties:{
          privateDnsZoneId: r_privateDNSZoneStorageDFS.id
        }
      }
    ]
  }
}

resource r_privateDNSZoneStorageDFS 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.dfs.${storageEnvironmentDNS}'
}

var privateContainerNames = [
  dataLakeTransientZoneName
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
resource r_dataLakePublicContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-02-01' = if(ctrlAllowStoragePublicContainer == true && deploymentMode == 'default') {
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
    managedVirtualNetworkSettings: (deploymentMode == 'vNet')? {
      preventDataExfiltration:true
    }: null
    purviewConfiguration:{
      purviewResourceId: purviewAccountID
    }
  }

  resource r_workspaceAADAdmin 'administrators' = {
    name:'activeDirectory'
    properties:{
      administratorType:'ActiveDirectory'
      tenantId: subscription().tenantId
      sid: uamiPrincipalID
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

  //Default Firewall Rules - Allow All Traffic
  resource r_synapseWorkspaceFirewallAllowAll 'firewallRules' = if (deploymentMode == 'default'){
    name: 'AllowAllNetworks'
    properties:{
      startIpAddress: '0.0.0.0'
      endIpAddress: '255.255.255.255'
    }
  }

  //Firewall Allow Azure Sevices
  //Required for Post-Deployment Scripts
  resource r_synapseWorkspaceFirewallAllowAzure 'firewallRules' = {
    name: 'AllowAllWindowsAzureIps'
    properties:{
      startIpAddress: '0.0.0.0'
      endIpAddress: '0.0.0.0'
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
resource r_privateDNSZoneSynapseSQL 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.sql.azuresynapse.net'
}

//Private DNS Zones required for Synapse Private Link
//privatelink.dev.azuresynapse.net
resource r_privateDNSZoneSynapseDev 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.dev.azuresynapse.net'
}

//Private DNS Zones required for Synapse Private Link
//privatelink.azuresynapse.net
resource r_privateDNSZoneSynapseWeb 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.azuresynapse.net'
}


//Private Endpoint for Synapse SQL
module m_synapseSQLPrivateLink './PrivateEndpoint.bicep' = if(deploymentMode == 'vNet') {
  name: 'SynapseSQLPrivateLink'
  params: {
    groupID: 'Sql'
    privateEndpoitName: '${r_synapseWorkspace.name}-sql'
    privateLinkServiceId: r_synapseWorkspace.id
    resourceLocation: resourceLocation
    subnetID: vNetSubnetID
    deployDNSZoneGroup: ctrlDeployPrivateDNSZones
    privateDNSZoneConfigs: [
      {
        name:'privatelink-sql-azuresynapse-net'
        properties:{
          privateDnsZoneId: r_privateDNSZoneSynapseSQL.id
        }
      }
    ]
  }
}

//Private Endpoint for Synapse SQL Serverless
module m_synapseSQLServerlessPrivateLink './PrivateEndpoint.bicep' = if(deploymentMode == 'vNet') {
  name: 'SynapseSQLServerlessPrivateLink'
  params: {
    groupID: 'SqlOnDemand'
    privateEndpoitName: '${r_synapseWorkspace.name}-sqlserverless'
    privateLinkServiceId: r_synapseWorkspace.id
    resourceLocation: resourceLocation
    subnetID: vNetSubnetID
    deployDNSZoneGroup: ctrlDeployPrivateDNSZones
    privateDNSZoneConfigs: [
      {
        name: 'privatelink-sql-azuresynapse-net'
        properties:{
          privateDnsZoneId: r_privateDNSZoneSynapseSQL.id
        }
      }
    ]
  }
}

//Private Endpoint for Synapse Dev
module m_synapseDevPrivateLink './PrivateEndpoint.bicep' = if(deploymentMode == 'vNet') {
  name: 'SynapseDevPrivateLink'
  params: {
    groupID: 'Dev'
    privateEndpoitName: '${r_synapseWorkspace.name}-dev'
    privateLinkServiceId: r_synapseWorkspace.id
    resourceLocation: resourceLocation
    subnetID: vNetSubnetID
    deployDNSZoneGroup: ctrlDeployPrivateDNSZones
    privateDNSZoneConfigs: [
      {
        name:'privatelink-web-azuresynapse-net'
        properties:{
          privateDnsZoneId: r_privateDNSZoneSynapseDev.id
        }
      }
    ]
  }
}

//Private Endpoint for Synapse Web
module m_synapseWebPrivateLink './PrivateEndpoint.bicep' = if(deploymentMode == 'vNet') {
  name: 'SynapseWebPrivateLink'
  params: {
    groupID: 'Web'
    privateEndpoitName: '${r_synapseWorkspace.name}-web'
    privateLinkServiceId: r_synapsePrivateLinkhub.id
    resourceLocation: resourceLocation
    subnetID: vNetSubnetID
    deployDNSZoneGroup: ctrlDeployPrivateDNSZones
    privateDNSZoneConfigs: [
      {
        name:'privatelink-dev-azuresynapse-net'
        properties:{
          privateDnsZoneId: r_privateDNSZoneSynapseWeb.id
        }
      }
    ]
  }
}



//Synapse Workspace Role Assignment as Blob Data Contributor Role in the Data Lake Storage Account
//https://docs.microsoft.com/en-us/azure/synapse-analytics/security/how-to-grant-workspace-managed-identity-permissions
resource r_dataLakeRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(r_synapseWorkspace.name, r_dataLakeStorageAccount.name)
  scope: r_dataLakeStorageAccount
  properties:{
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRBACStorageBlobDataContributorRoleID)
    principalId: r_synapseWorkspace.identity.principalId
    principalType:'ServicePrincipal'
  }
}

//Assign Owner Role to UAMI in the Synapse Workspace. UAMI needs to be Owner so it can assign itself as Synapse Admin and create resources in the Data Plane.
resource r_synapseWorkspaceOwnerRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(r_synapseWorkspace.name, uamiPrincipalID)
  scope: r_synapseWorkspace
  properties:{
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRBACOwnerRoleID)
    principalId: uamiPrincipalID
    principalType:'ServicePrincipal'
  }
}

output dataLakeStorageAccountID string = r_dataLakeStorageAccount.id
output dataLakeStorageAccountName string = r_dataLakeStorageAccount.name
output synapseWorkspaceID string = r_synapseWorkspace.id
output synapseWorkspaceName string = r_synapseWorkspace.name
output synapseSQLDedicatedEndpoint string = r_synapseWorkspace.properties.connectivityEndpoints.sql
output synapseSQLServerlessEndpoint string = r_synapseWorkspace.properties.connectivityEndpoints.sqlOnDemand
output synapseWorkspaceSparkID string = r_synapseWorkspace::r_sparkPool.id
output synapseWorkspaceIdentityPrincipalID string = r_synapseWorkspace.identity.principalId
