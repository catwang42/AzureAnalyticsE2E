//********************************************************
// Global Parameters
//********************************************************

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

param ctrlDeployPurview bool = true     //Controls the deployment of Azure Purview
param ctrlDeployAI bool = false     //Controls the deployment of Azure ML and Cognitive Services
param ctrlDeployStreaming bool = false   //Controls the deployment of EventHubs and Stream Analytics
param ctrlDeployDataShare bool = false   //Controls the deployment of Azure Data Share
param ctrlPostDeployScript bool = true  //Controls the execution of post-deployment script
param ctrlAllowStoragePublicContainer bool = false //Controls the creation of data lake Public container
param ctrlDeployPrivateDNSZones bool = true //Controls the creation of private DNS zones for private links
param ctrlDeploySynapseSQLPool bool = false //Controls the creation of Synapse SQL Pool
param deploymentDatetime string = utcNow()
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

@description('Allow Shared Key Access')
param allowSharedKeyAccess bool = false

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
param synapseSQLPoolSKU string = 'DW100c'

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

@description('Purview Managed Resource Group Name')
param purviewManagedRGName string = '${purviewAccountName}-mrg'

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

@description('Azure Machine Learning Container Registry Name')
param azureMLContainerRegistryName string = 'azmlcontainerreg${uniqueSuffix}'


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

var azureRBACStorageBlobDataReaderRoleID = '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1' //Storage Blob Data Reader Role
var azureRBACContributorRoleID = 'b24988ac-6180-42a0-ab88-20f7382dd24c' //Contributor
var azureRBACOwnerRoleID = '8e3af657-a8ff-443c-a75c-2fe8c4bcb635' //Owner
var deploymentScriptUAMIName = toLower('${resourceGroup().name}-uami')

//********************************************************
// Shared Resources
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

resource r_subNet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' = if(deploymentMode == 'vNet') {
  name: vNetSubnetName
  parent: r_vNet
  properties: {
    addressPrefix: vNetSubnetIPAddressPrefix
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies:'Enabled'
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
        objectId: m_CoreServicesDeploy.outputs.synapseWorkspaceIdentityPrincipalID
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

  resource r_PurviewAccessPolicy 'accessPolicies' = if (ctrlDeployPurview == true) {
    name: 'add'
    properties:{
      accessPolicies: [
        //Access Policy to allow Purview to Get and List Secrets
        //https://docs.microsoft.com/en-us/azure/purview/manage-credentials#grant-the-purview-managed-identity-access-to-your-azure-key-vault
        {
          objectId: ctrlDeployPurview ? m_PurviewDeploy.outputs.purviewIdentityPrincipalID : ''
          tenantId: subscription().tenantId
          permissions: {
            secrets: [
              'get'
              'list'
            ]
          }
        }
      ]
    }
  }
}

//Private DNS Zones required for Synapse Private Link: privatelink.vaultcore.azure.net
//Required for KeyVault
resource r_privateDNSZoneKeyVault 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.vaultcore.azure.net'
}

module m_keyVaultPrivateLink './modules/PrivateEndpoint.bicep' = if(deploymentMode == 'vNet') {
  name: 'KeyVaultPrivateLink'
  params: {
    groupID: 'vault'
    privateEndpoitName: r_keyVault.name
    privateLinkServiceId: r_keyVault.id
    resourceLocation: resourceLocation
    subnetID: r_subNet.id
    deployDNSZoneGroup:ctrlDeployPrivateDNSZones
    privateDNSZoneConfigs: [
      {
        name:'privatelink-vaultcore-azure-net'
        properties:{
          privateDnsZoneId: r_privateDNSZoneKeyVault.id
        }
      }
    ]
  }
}

//********************************************************
// Modules
//********************************************************

//Deploy Private DNS Zones required to suppport Private Endpoints
module m_DeployPrivateDNSZones 'modules/PrivateDNSZonesDeploy.bicep' = if (deploymentMode == 'vNet' && ctrlDeployPrivateDNSZones == true){
  name: 'DeployPrivateDNSZones'
  params: {
    vNetID: r_vNet.id
    vNetName: r_vNet.name
    ctrlDeployAI: ctrlDeployAI
    ctrlDeployPurview: ctrlDeployPurview
    ctrlDeployStreaming: ctrlDeployStreaming
  }
}

//Deploy Core Services: Data Lake Account, Synapse Workspace and Key Vault.
module m_CoreServicesDeploy 'modules/CoreServicesDeploy.bicep' = {
  name: 'CoreServicesDeploy'
  params: {
    deploymentMode: deploymentMode
    resourceLocation: resourceLocation
    allowSharedKeyAccess: allowSharedKeyAccess
    ctrlAllowStoragePublicContainer: ctrlAllowStoragePublicContainer
    ctrlDeployPrivateDNSZones: ctrlDeployPrivateDNSZones
    ctrlDeploySynapseSQLPool: ctrlDeploySynapseSQLPool
    dataLakeAccountName: dataLakeAccountName
    dataLakeCuratedZoneName: dataLakeCuratedZoneName
    dataLakePublicZoneName: dataLakePublicZoneName
    dataLakeRawZoneName: dataLakeRawZoneName
    dataLakeSandpitZoneName: dataLakeSandpitZoneName
    dataLakeTransientZoneName: dataLakeTransientZoneName
    dataLakeTrustedZoneName: dataLakeTrustedZoneName
    synapseDefaultContainerName: synapseDefaultContainerName
    purviewAccountID: (ctrlDeployPurview == true)? m_PurviewDeploy.outputs.purviewAccountID : ''
    synapseDedicatedSQLPoolName: synapseDedicatedSQLPoolName
    synapseManagedRGName: synapseManagedRGName
    synapsePrivateLinkHubName: synapsePrivateLinkHubName
    synapseSparkPoolMaxNodeCount: synapseSparkPoolMaxNodeCount
    synapseSparkPoolMinNodeCount: synapseSparkPoolMinNodeCount
    synapseSparkPoolName: synapseSparkPoolName
    synapseSparkPoolNodeSize: synapseSparkPoolNodeSize
    synapseSqlAdminPassword: synapseSqlAdminPassword
    synapseSqlAdminUserName: synapseSqlAdminUserName
    synapseSQLPoolSKU: synapseSQLPoolSKU
    synapseWorkspaceName: synapseWorkspaceName
    uamiPrincipalID: r_deploymentScriptUAMI.properties.principalId
    vNetSubnetID: r_subNet.id
  }
}


//Deploy Purview Account
module m_PurviewDeploy 'modules/PurviewDeploy.bicep' = if (ctrlDeployPurview == true){
  name: 'PurviewDeploy'
  params: {
    deploymentMode: deploymentMode
    ctrlDeployPrivateDNSZones: ctrlDeployPrivateDNSZones
    purviewAccountName: purviewAccountName
    purviewManagedRGName: purviewManagedRGName
    resourceLocation: resourceLocation
    subnetID: r_subNet.id
    uamiPrincipalID: r_deploymentScriptUAMI.properties.principalId
  }
}


//Deploy AI Services: Azure Machine Learning Workspace (and dependent services) and Cognitive Services
module m_AIServicesDeploy 'modules/AIServicesDeploy.bicep' = if(ctrlDeployAI == true) {
  name: 'AIServicesDeploy'
  params: {
    anomalyDetectorName: anomalyDetectorName
    azureMLAppInsightsName: azureMLAppInsightsName
    azureMLContainerRegistryName: azureMLContainerRegistryName
    azureMLStorageAccountName: azureMLStorageAccountName
    azureMLWorkspaceName: azureMLWorkspaceName
    cognitiveServiceAccountName: cognitiveServiceAccountName
    keyVaultName: keyVaultName
    resourceLocation: resourceLocation
    synapseSparkPoolID: m_CoreServicesDeploy.outputs.synapseWorkspaceSparkID
    synapseWorkspaceID: m_CoreServicesDeploy.outputs.synapseWorkspaceID
    synapseWorkspaceName: m_CoreServicesDeploy.outputs.synapseWorkspaceName
    deploymentMode: deploymentMode
    vNetSubnetID: r_subNet.id
    ctrlDeployPrivateDNSZones: ctrlDeployPrivateDNSZones
  }
}

module m_DataShareDeploy 'modules/DataShareDeploy.bicep' = if(ctrlDeployDataShare == true){
  name: 'DataShareDeploy'
  params: {
    dataShareAccountName: dataShareAccountName
    resourceLocation: resourceLocation
  }
}

module m_StreamingServicesDeploy 'modules/StreamingServicesDeploy.bicep' = if(ctrlDeployStreaming == true) {
  name: 'StreamingServicesDeploy'
  params: {
    dataLakeStorageAccountID: m_CoreServicesDeploy.outputs.dataLakeStorageAccountID 
    eventHubName: eventHubName
    eventHubNamespaceName: eventHubNamespaceName
    eventHubPartitionCount: eventHubPartitionCount
    eventHubSku: eventHubSku
    resourceLocation: resourceLocation
    streamAnalyticsJobName: streamAnalyticsJobName
    streamAnalyticsJobSku: streamAnalyticsJobSku
    ctrlDeployPrivateDNSZones: ctrlDeployPrivateDNSZones
    deploymentMode: deploymentMode
    vNetSubnetID: r_subNet.id
  }
}

//********************************************************
// RBAC Role Assignments
//********************************************************
resource r_dataLakeStorageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: dataLakeAccountName
}

resource r_azureMLWorkspace 'Microsoft.MachineLearningServices/workspaces@2021-04-01' existing = {
  name: azureMLWorkspaceName
}

resource r_synapseWorkspace 'Microsoft.Synapse/workspaces@2021-06-01-preview' existing = {
  name: synapseWorkspaceName
}

//Assign Owner Role to UAMI in the Synapse Workspace. UAMI needs to be Owner so it can assign itself as Synapse Admin and create resources in the Data Plane.
resource r_synapseWorkspaceOwnerRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(r_synapseWorkspace.name, 'DeploymentScriptUAMI')
  scope: r_synapseWorkspace
  properties:{
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRBACOwnerRoleID)
    principalId: r_deploymentScriptUAMI.properties.principalId
    principalType:'ServicePrincipal'
  }
}

//Assign Storage Blob Reader Role to Purview MSI in the Resource Group as per https://docs.microsoft.com/en-us/azure/purview/register-scan-synapse-workspace
resource r_purviewRGStorageBlobDataReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (ctrlDeployPurview == true) {
  name: guid(resourceGroup().name, purviewAccountName, 'Storage Blob Reader')
  properties:{
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRBACStorageBlobDataReaderRoleID)
    principalId: ctrlDeployPurview ? m_PurviewDeploy.outputs.purviewIdentityPrincipalID : ''
    principalType:'ServicePrincipal'
  }
}

//Deployment script UAMI is set as Resource Group owner so it can have authorisation to perform post deployment tasks
resource r_deploymentScriptUAMIRGOwnerRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().name, deploymentScriptUAMIName, 'Owner')
  properties:{
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRBACOwnerRoleID)
    principalId: r_deploymentScriptUAMI.properties.principalId
    principalType:'ServicePrincipal'
  }
}

//Azure Synaspe MSI needs to have Contributor permissions in the Azure ML workspace.
//https://docs.microsoft.com/en-us/azure/synapse-analytics/machine-learning/quickstart-integrate-azure-machine-learning#give-msi-permission-to-the-azure-ml-workspace
resource r_synapseAzureMLContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if(ctrlDeployAI == true) {
  name: guid(synapseWorkspaceName, azureMLWorkspaceName, 'Contributor')
  scope: r_azureMLWorkspace
  dependsOn:[
    m_AIServicesDeploy
    m_CoreServicesDeploy
  ]
  properties:{
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRBACContributorRoleID)
    principalId: m_CoreServicesDeploy.outputs.synapseWorkspaceIdentityPrincipalID
    principalType:'ServicePrincipal'
  }
}

//Assign Storage Blob Data Reader Role to Azure ML MSI in the Data Lake Account as per https://docs.microsoft.com/en-us/azure/machine-learning/how-to-identity-based-data-access
resource r_azureMLStorageBlobDataReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if(ctrlDeployAI == true) {
  name: guid(r_dataLakeStorageAccount.name, azureMLWorkspaceName, 'Storage Blob Data Reader')
  scope:r_dataLakeStorageAccount
  dependsOn: [
    m_CoreServicesDeploy
    m_AIServicesDeploy
  ]
  properties:{
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRBACStorageBlobDataReaderRoleID)
    principalId: ctrlDeployAI ? m_AIServicesDeploy.outputs.azureMLSynapseLinkedServicePrincipalID : ''
    principalType:'ServicePrincipal'
  }
}

//Assign Storage Blob Data Reader Role to Azure Data Share in the Data Lake Account as per https://docs.microsoft.com/en-us/azure/data-share/concepts-roles-permissions
resource r_azureDataShareStorageBlobDataReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (ctrlDeployDataShare == true) {
  name: guid(r_dataLakeStorageAccount.name, dataShareAccountName, 'Storage Blob Data Reader')
  scope:r_dataLakeStorageAccount
  dependsOn: [
    m_CoreServicesDeploy
    m_DataShareDeploy
  ]
  properties:{
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRBACStorageBlobDataReaderRoleID)
    principalId: ctrlDeployDataShare ? m_DataShareDeploy.outputs.dataShareAccountPrincipalID : ''
    principalType:'ServicePrincipal'
  }
}

//********************************************************
// Post Deployment Scripts
//********************************************************

//Synapse Deployment Script
var synapsePostDeploymentPSScript = 'aHR0cHM6Ly9hemFuYWx5dGljc2VuZDJlbmQuYmxvYi5jb3JlLndpbmRvd3MubmV0L2RlcGxveXNjcmlwdHMvU3luYXBzZVBvc3REZXBsb3kucHMx'
var azMLSynapseLinkedServiceIdentityID = ctrlDeployAI ? '-AzMLSynapseLinkedServiceIdentityID ${m_AIServicesDeploy.outputs.azureMLSynapseLinkedServicePrincipalID}' : ''
var azMLWorkspaceName = ctrlDeployAI ? '-AzMLWorkspaceName ${azureMLWorkspaceName}' : ''

resource r_synapsePostDeployScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name:'SynapsePostDeploymentScript-${deploymentDatetime}'
  dependsOn: [
    m_CoreServicesDeploy
    m_AIServicesDeploy
    r_deploymentScriptUAMIRGOwnerRoleAssignment
    //r_synapseAzureMLContributorRoleAssignment
    r_keyVault
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
    azPowerShellVersion:'6.2'
    cleanupPreference:'OnSuccess'
    retentionInterval: 'P1D'
    timeout:'PT30M'
    arguments: '-DeploymentMode ${deploymentMode} -SubscriptionID ${subscription().subscriptionId} -ResourceGroupName ${resourceGroup().name} -WorkspaceName ${synapseWorkspaceName} -UAMIIdentityID ${r_deploymentScriptUAMI.properties.principalId} -KeyVaultName ${keyVaultName} -KeyVaultID ${r_keyVault.id} ${azMLSynapseLinkedServiceIdentityID} ${azMLWorkspaceName} -DataLakeStorageAccountName ${dataLakeAccountName} -DataLakeStorageAccountID ${m_CoreServicesDeploy.outputs.dataLakeStorageAccountID}'
    primaryScriptUri: base64ToString(synapsePostDeploymentPSScript)
  }
}

//Purview Deployment Script
var purviewPostDeploymentPSScript = 'aHR0cHM6Ly9hemFuYWx5dGljc2VuZDJlbmQuYmxvYi5jb3JlLndpbmRvd3MubmV0L2RlcGxveXNjcmlwdHMvUHVydmlld1Bvc3REZXBsb3kucHMx'

resource r_purviewPostDeployScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = if(ctrlDeployPurview == true){
  name:'PurviewPostDeploymentScript-${deploymentDatetime}'
  dependsOn: [
    m_PurviewDeploy
    m_CoreServicesDeploy
    r_deploymentScriptUAMIRGOwnerRoleAssignment
    r_keyVault
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
    azPowerShellVersion:'6.2'
    cleanupPreference:'OnSuccess'
    retentionInterval: 'P1D'
    timeout:'PT30M'
    arguments: '-PurviewAccountName ${purviewAccountName} -SubscriptionID ${subscription().subscriptionId} -ResourceGroupName ${resourceGroup().name} -UAMIIdentityID ${r_deploymentScriptUAMI.properties.principalId} -ScanEndpoint ${ctrlDeployPurview ? m_PurviewDeploy.outputs.purviewScanEndpoint : ''} -APIVersion ${ctrlDeployPurview ? m_PurviewDeploy.outputs.purviewAPIVersion : ''} -SynapseWorkspaceName ${m_CoreServicesDeploy.outputs.synapseWorkspaceName} -KeyVaultName ${keyVaultName} -KeyVaultID ${r_keyVault.id} -DataLakeAccountName ${m_CoreServicesDeploy.outputs.dataLakeStorageAccountName}'
    primaryScriptUri: base64ToString(purviewPostDeploymentPSScript)
  }
}

//********************************************************
// Outputs
//********************************************************

