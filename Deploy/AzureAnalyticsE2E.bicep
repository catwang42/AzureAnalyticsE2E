//********************************************************
// Parameters
//********************************************************

param rerun bool = true

@allowed([
  'Workshop'
  'SolutionAccelerator'
  'SolutionAccelerator-vNet'
])
@description('Deployment Mode')
param deploymenMode string = 'Workshop'

@description('Resource Location')
param resourceLocation string = resourceGroup().location

@description('Unique Suffix')
param uniqueSuffix string = substring(uniqueString(resourceGroup().id),0,5)

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

//Purview Account Parameters
@description('Purview Account Name')
param purviewAccountName string = 'azpurview${uniqueSuffix}'

//Key Vault Parameters
@description('Data Lake Storage Account Name')
param keyVaultName string = 'azkeyvault${uniqueSuffix}'


//Azure Machiine Learning Parameters
@description('Azure Machine Learning Workspace Name')
param azureMLWokspaceName string = 'azmlwks${uniqueSuffix}'

@description('Azure Machine Learning Storage Account Name')
param azureMLStorageAccountName string = 'azmlstorage${uniqueSuffix}'

@description('Azure Machine Learning Application Insights Name')
param azureMLAppInsightsName string = 'azmlappinsights${uniqueSuffix}'


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
resource r_deploymentScriptUAMI 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: deploymentScriptUAMIName
  location: resourceLocation

}

//Data Lake Storage Account
resource r_dataLakeStorageAccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: dataLakeAccountName
  location: resourceLocation
  properties:{
    isHnsEnabled: true
    accessTier:'Hot'
    allowBlobPublicAccess:true //TODO: Edit networkAcls for SolutionAccelerator-vNet
    networkAcls:{
      defaultAction:'Allow' //TODO: Edit networkAcls for SolutionAccelerator-vNet
      bypass:'AzureServices'
    }
  }
  kind:'StorageV2'
  sku: {
      name: 'Standard_RAGRS'
  }
}

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
resource r_dataLakePublicContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-02-01' = {
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
    purviewConfiguration:{
      purviewResourceId: r_purviewAccount.id
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

  //Default Frewall Rules
  resource r_synapseWorkspaceFirewall 'firewallRules' = {
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
}

//Key Vault
resource r_keyVault 'Microsoft.KeyVault/vaults@2021-04-01-preview' = {
  name: keyVaultName
  location: resourceLocation
  properties:{
    tenantId: subscription().tenantId
    sku:{
      name:'standard'
      family:'A'
    }
    networkAcls:{
      defaultAction:'Allow'
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
      ////Access Policy to allow Purview to Get and List Secrets
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
    ]
  }
}

//Purview Account
resource r_purviewAccount 'Microsoft.Purview/accounts@2020-12-01-preview' = {
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
    publicNetworkAccess:'Enabled'
  }
}


//Azure ML Storage Account
resource r_azureMLStorage 'Microsoft.Storage/storageAccounts@2021-02-01' = {
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

resource r_azureMLAppInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: azureMLAppInsightsName
  location:resourceLocation
  kind:'web'
  properties:{
    Application_Type:'web'
  }
}

resource r_azureMLWorkspace 'Microsoft.MachineLearningServices/workspaces@2021-01-01' = {
  name: azureMLWokspaceName
  location: resourceLocation
  sku:{
    name: 'Basic'
    tier: 'Basic'
  }
  properties:{
    friendlyName: azureMLWokspaceName
    keyVault: r_keyVault.name
    storageAccount: r_azureMLStorage.name
    applicationInsights: r_azureMLAppInsights.name
  }
}

//********************************************************
// Role Assignments
//********************************************************

//Synapse Workspace Role Assignment as Blob Data Contributor Role in the Data Lake Storage Account
//https://docs.microsoft.com/en-us/azure/synapse-analytics/security/how-to-grant-workspace-managed-identity-permissions
resource r_dataLakeRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (rerun == false) {
  name: guid(r_synapseWorkspace.name, r_dataLakeStorageAccount.name)
  scope: r_dataLakeStorageAccount
  properties:{
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRBACStorageBlobDataContributorRoleID)
    principalId: r_synapseWorkspace.identity.principalId
    principalType:'ServicePrincipal'
  }
}

//Assign Reader Role to Purview MSI in the Resource Group as per https://docs.microsoft.com/en-us/azure/purview/register-scan-synapse-workspace
resource r_purviewRGReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (rerun == false) {
  name: guid(resourceGroup().name, r_purviewAccount.name, 'Reader')
  properties:{
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRBACReaderRoleID)
    principalId: r_purviewAccount.identity.principalId
    principalType:'ServicePrincipal'
  }
}

//Assign Storage Blob Reader Role to Purview MSI in the Resource Group as per https://docs.microsoft.com/en-us/azure/purview/register-scan-synapse-workspace
resource r_purviewRGStorageBlobDataReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (rerun == false) {
  name: guid(resourceGroup().name, r_purviewAccount.name, 'Storage Blob Reader')
  properties:{
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRBACStorageBlobDataReaderRoleID)
    principalId: r_purviewAccount.identity.principalId
    principalType:'ServicePrincipal'
  }
}

//Assign Owner Role to UAMI in the Synapse Workspace. UAMI needs to be Owner so it can assign itself as Synapse Admin and create resources in the Data Plane.
resource r_synapseWorkspaceOwnerRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (rerun == false) {
  name: guid(r_synapseWorkspace.name, r_deploymentScriptUAMI.name)
  scope: r_synapseWorkspace
  properties:{
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRBACOwnerRoleID)
    principalId: r_deploymentScriptUAMI.properties.principalId
    principalType:'ServicePrincipal'
  }
}

//Assign Owner Role to UAMI in the Synapse Workspace. UAMI needs to be Owner so it can assign itself as Synapse Admin and create resources in the Data Plane.
resource r_azureMLOwnerRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (rerun == false) {
  name: guid(r_azureMLWorkspace.name, r_deploymentScriptUAMI.name)
  scope: r_azureMLWorkspace
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
var synapsePostDeploymentPSScript = '''
param(
  [string] $WorkspaceName,
  [string] $SynapseSqlAdminUserName,
  [string] $SynapseSqlAdminPassword,
  [string] $KeyVaultName,
  [string] $UAMIIdentityID,
  [string] $PurviewAccountName,
  [string] $SQLServerlessDBName
)

If(-not(Get-InstalledModule SQLServer -ErrorAction silentlycontinue)) {
  Set-PSRepository PSGallery -InstallationPolicy Trusted
  Install-Module SQLServer -Confirm:$False -Force
}

$token = (Get-AzAccessToken -Resource "https://dev.azuresynapse.net").Token
$headers = @{ Authorization = "Bearer $token" }
$retries = 10
$secondsDelay = 30


$uri = "https://$WorkspaceName.dev.azuresynapse.net/rbac/roleAssignments?api-version=2020-02-01-preview" 

#Assign Workspace Administrator Role to UAMI
$body = "{
  roleId: ""6e4bf58a-b8e1-4cc3-bbf9-d73143322b78"",
  principalId: ""$UAMIIdentityID""
}"

Write-Host "Assign Synapse Administrator Role to UAMI..."
$result = Invoke-RestMethod -Method Post -ContentType "application/json" -Uri $uri -Headers $headers -Body $body

#Assign Synapse Administrator Role to UAMI
$body = "{
  roleId: ""7af0c69a-a548-47d6-aea3-d00e69bd83aa"",
  principalId: ""$UAMIIdentityID""
}"

Write-Host "Assign SQL Administrator Role to UAMI..."
$result = Invoke-RestMethod -Method Post -ContentType "application/json" -Uri $uri -Headers $headers -Body $body

# From: https://docs.microsoft.com/en-us/azure/synapse-analytics/security/how-to-manage-synapse-rbac-role-assignments
# Changes made to Synapse RBAC role assignments may take 2-5 minutes to take effect.
# Retry logic required before calling further APIs

#Create AKV Linked Service. Linked Service name same as Key Vault's.
$uri = "https://$WorkspaceName.dev.azuresynapse.net" 
$uri += "/linkedservices/$KeyVaultName"
$uri += "?api-version=2019-06-01-preview"

$body = "{
  name: ""$linkedServiceName"",
  properties: {
      annotations: [],
      type: ""AzureKeyVault"",
      typeProperties: {
          baseUrl: ""https://$KeyVaultName.vault.azure.net/""
      }
  }
}"

Write-Host "Create Azure Key Vault Linked Service..."
$retrycount = 1
$completed = $false

while (-not $completed) {
  try {
    $result = Invoke-RestMethod -Method Put -ContentType "application/json" -Uri $uri -Headers $headers -Body $body -ErrorAction Stop
    Write-Host "Role assignment successful."
    $completed = $true
  }
  catch {
    if ($retrycount -ge $retries) {
        Write-Host "Role assignment failed the maximum number of $retryCount times."
        throw
    } else {
        Write-Host "Role assignment failed $retryCount time(s). Retrying in $secondsDelay seconds."
        Start-Sleep $secondsDelay
        $retrycount++
    }
  }
}

#Configure SQL Serverless and Dedicated SQL Pool with access for Azure Purview.
$sqlServerlessEndpoint = "$WorkspaceName-ondemand.sql.azuresynapse.net"
$sqlDedicatedPoolEndpoint = "$WorkspaceName.sql.azuresynapse.net"

#Retrieve AccessToken for UAMI
$access_token = (Get-AzAccessToken -ResourceUrl https://sql.azuresynapse.net).Token

#Create SQL Serverless Database
$sql = "CREATE DATABASE $SQLServerlessDatabaseName"

#Create Login for Azure Purview and set it as sysadmin 
#as per https://docs.microsoft.com/en-us/azure/purview/register-scan-synapse-workspace#setting-up-authentication-for-enumerating-serverless-sql-database-resources-under-a-synapse-workspace

$sql = "CREATE LOGIN [$PurviewAccountName] FROM EXTERNAL PROVIDER;
ALTER SERVER ROLE sysadmin ADD MEMBER [$PurviewAccountName];"

Write-Host $sql
Write-Host "Create SQL Serverless Database and Purview Login"

$retrycount = 1
$retries = 5
$secondsDelay = 10
$completed = $false

while (-not $completed) {
  try {
    #$result = Invoke-Sqlcmd -ServerInstance $sqlServerlessEndpoint -Database master -AccessToken $access_token -query $sql
    #$result = Invoke-Sqlcmd -ServerInstance $sqlServerlessEndpoint -Database master -UserName $SynapseSqlAdminUserName -Password $SynapseSqlAdminPassword -query $sql
    Write-Host "SQL Serverless config successful."
    Write-Host ($result | ConvertTo-Json)
    $completed = $true
  }
  catch {
    if ($retrycount -ge $retries) {
        Write-Host "SQL Serverless config failed the maximum number of $retryCount times."
        throw
    } else {
        Write-Host "SQL Serverless config $retryCount time(s). Retrying in $secondsDelay seconds."
        Start-Sleep $secondsDelay
        $retrycount++
    }
  }
}
'''

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
    retentionInterval: 'PT1H'
    arguments: '-WorkspaceName ${r_synapseWorkspace.name} -SynapseSqlAdminUserName ${synapseSqlAdminUserName} -SynapseSqlAdminPassword ${synapseSqlAdminPassword} -UAMIIdentityID ${r_deploymentScriptUAMI.properties.principalId} -KeyVaultName ${r_keyVault.name} -PurviewAccountName ${r_purviewAccount.name}'
    scriptContent: synapsePostDeploymentPSScript
  }
}

//********************************************************
// Output
//********************************************************

output dataLakeStorageAccountID string = r_dataLakeStorageAccount.id
output synapseWorkspaceID string = r_synapseWorkspace.id

