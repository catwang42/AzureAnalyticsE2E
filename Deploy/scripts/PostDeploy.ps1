param(
  [string] $DeploymentMode,
  [string] $WorkspaceName,
  #[string] $SynapseSqlAdminUserName,
  #[string] $SynapseSqlAdminPassword,
  [string] $KeyVaultName,
  [string] $KeyVaultID,
  [string] $DataLakeStorageAccountName,
  [string] $DataLakeStorageAccountID,
  [string] $UAMIIdentityID,
  [string] $AzMLSynapseLinkedServiceIdentityID,
  [string] $PurviewAccountName,
  [string] $AzureMLWorkspaceName,
  [string] $SQLServerlessDBName
)

# $Context = Get-AzContext
# $tenantID = $Context.Tenant.Id

#Try {
#  Write-Host "Getting secrets from KeyVault"
#  $AADDirectoryReaderPrincipalID = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "AADDirectoryReaderPrincipalID" -AsPlainText
#  $SecureString = $AADDirectoryReaderPrincipalID | ConvertTo-SecureString -AsPlainText -Force
#  $Cred = New-Object System.Management.Automation.PSCredential "ignore", $AADDirectoryReaderPrincipalID
#}
#Catch {
#  $ErrorMessage = "Failed to retrieve the secret from $($KeyVault)."
#  $ErrorMessage += " `n"
#  $ErrorMessage += 'Error: '
#  $ErrorMessage += $_
#  Write-Error -Message $ErrorMessage `
#              -ErrorAction Stop
#}

#------------------------------------------------------------------------------------------------------------
# ASSIGN WORKSPACE ADMINISTRATOR TO USER-ASSIGNED MANAGED IDENTITY
#------------------------------------------------------------------------------------------------------------

$token = (Get-AzAccessToken -Resource "https://dev.azuresynapse.net").Token
$headers = @{ Authorization = "Bearer $token" }
$retries = 10
$secondsDelay = 30

$uri = "https://$WorkspaceName.dev.azuresynapse.net/rbac/roleAssignments?api-version=2020-02-01-preview"

#Assign Synapse Workspace Administrator Role to UAMI
$body = "{
  roleId: ""6e4bf58a-b8e1-4cc3-bbf9-d73143322b78"",
  principalId: ""$UAMIIdentityID""
}"

Write-Host "Assign Synapse Administrator Role to UAMI..."
Invoke-RestMethod -Method Post -ContentType "application/json" -Uri $uri -Headers $headers -Body $body

#------------------------------------------------------------------------------------------------------------
# ASSIGN SYNAPSE APACHE SPARK ADMINISTRATOR TO AZURE ML LINKED SERVICE MSI
#------------------------------------------------------------------------------------------------------------

#Assign Synapse Apache Spark Administrator Role to Azure ML Linked Service Managed Identity
# https://docs.microsoft.com/en-us/azure/machine-learning/how-to-link-synapse-ml-workspaces#link-workspaces-with-the-python-sdk

$body = "{
  roleId: ""c3a6d2f1-a26f-4810-9b0f-591308d5cbf1"",
  principalId: ""$AzMLSynapseLinkedServiceIdentityID""
}"

Write-Host "Assign Synapse Apache Spark Administrator Role to Azure ML Linked Service Managed Identity..."
Invoke-RestMethod -Method Post -ContentType "application/json" -Uri $uri -Headers $headers -Body $body

# From: https://docs.microsoft.com/en-us/azure/synapse-analytics/security/how-to-manage-synapse-rbac-role-assignments
# Changes made to Synapse RBAC role assignments may take 2-5 minutes to take effect.
# Retry logic required before calling further APIs

#------------------------------------------------------------------------------------------------------------
# CREATE AZURE KEY VAULT LINKED SERVICE
#------------------------------------------------------------------------------------------------------------

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
    Invoke-RestMethod -Method Put -ContentType "application/json" -Uri $uri -Headers $headers -Body $body -ErrorAction Stop
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

#------------------------------------------------------------------------------------------------------------
# CREATE MANAGED PRIVATE ENDPOINTS
#------------------------------------------------------------------------------------------------------------

[string[]] $managedPrivateEndpointNames = $KeyVaultName, $DataLakeStorageAccountName
[string[]] $managedPrivateEndpointIDs = $KeyVaultID, $DataLakeStorageAccountID

if ($DeploymentMode -eq "vNet") {
  for($i = 0; $i -le ($managedPrivateEndpointNames.lenght - 1); $i += 1)
  {
    $uri = "https://$WorkspaceName.dev.azuresynapse.net"
    $uri += "/managedVirtualNetworks/default/managedPrivateEndpoints/$managedPrivateEndpointNames[$i]"
    $uri += "?api-version=2019-06-01-preview"
    
    $body = "{
      name: ""$managedPrivateEndpointNames[$i]"",
      type: ""Microsoft.Synapse/workspaces/managedVirtualNetworks/managedPrivateEndpoints"",
      properties: {
          privateLinkResourceId: ""$managedPrivateEndpointIDs[$i]"",
          groupId: ""vault"",
          provisioningState: ""Succeeded"",
          privateLinkServiceConnectionState: {
            status: ""Approved"",
            description: ""Auto-Approved""
          }
      }
    }"
    
    Write-Host "Create Managed Private Endpoint for $managedPrivateEndpointNames[$i]..."
    $retrycount = 1
    $completed = $false
    
    while (-not $completed) {
      try {
        Invoke-RestMethod -Method Put -ContentType "application/json" -Uri $uri -Headers $headers -Body $body -ErrorAction Stop
        Write-Host "Managed private endpoint for $managedPrivateEndpointNames[$i] created successfully."
        $completed = $true
      }
      catch {
        if ($retrycount -ge $retries) {
            Write-Host "Managed private endpoint for $managedPrivateEndpointNames[$i] creation failed the maximum number of $retryCount times."
            throw
        } else {
            Write-Host "Managed private endpoint creation for $managedPrivateEndpointNames[$i] failed $retryCount time(s). Retrying in $secondsDelay seconds."
            Start-Sleep $secondsDelay
            $retrycount++
        }
      }
    }
  }
}