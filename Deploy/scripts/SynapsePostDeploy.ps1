param(
  [string] $DeploymentMode,
  [string] $SubscriptionID,
  [string] $WorkspaceName,
  [string] $KeyVaultName,
  [string] $KeyVaultID,
  [string] $DataLakeStorageAccountName,
  [string] $DataLakeStorageAccountID,
  [string] $UAMIIdentityID,
  [AllowEmptyString()]
  [Parameter(Mandatory=$false)]
  [string] $AzMLSynapseLinkedServiceIdentityID
)

$retries = 10
$secondsDelay = 30

#------------------------------------------------------------------------------------------------------------
# ASSIGN WORKSPACE ADMINISTRATOR TO USER-ASSIGNED MANAGED IDENTITY
#------------------------------------------------------------------------------------------------------------

$token = (Get-AzAccessToken -Resource "https://dev.azuresynapse.net").Token
$headers = @{ Authorization = "Bearer $token" }

$uri = "https://$WorkspaceName.dev.azuresynapse.net/rbac/roleAssignments?api-version=2020-02-01-preview"

#Assign Synapse Workspace Administrator Role to UAMI
$body = "{
  roleId: ""6e4bf58a-b8e1-4cc3-bbf9-d73143322b78"",
  principalId: ""$UAMIIdentityID""
}"

Write-Host "Assign Synapse Administrator Role to UAMI..."

$result = Invoke-RestMethod -Method Post -ContentType "application/json" -Uri $uri -Headers $headers -Body $body

#------------------------------------------------------------------------------------------------------------
# ASSIGN SYNAPSE APACHE SPARK ADMINISTRATOR TO AZURE ML LINKED SERVICE MSI
#------------------------------------------------------------------------------------------------------------

if (-not ([string]::IsNullOrEmpty($AzMLSynapseLinkedServiceIdentityID))) {
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
}

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
    Write-Host "Linked service created successfully."
    $completed = $true
  }
  catch {
    if ($retrycount -ge $retries) {
        Write-Host "Linked service creation failed the maximum number of $retryCount times."
        throw
    } else {
        Write-Host "Linked service creation failed $retryCount time(s). Retrying in $secondsDelay seconds."
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
[string[]] $managedPrivateEndpointGroups = 'vault', 'dfs'

if ($DeploymentMode -eq "vNet") {
  for($i = 0; $i -le ($managedPrivateEndpointNames.Length - 1); $i += 1)
  {
    $managedPrivateEndpointName = $managedPrivateEndpointNames[$i]
    $managedPrivateEndpointID = $managedPrivateEndpointIDs[$i]
    $managedPrivateEndpointGroup = $managedPrivateEndpointGroups[$i] 

    $uri = "https://$WorkspaceName.dev.azuresynapse.net"
    $uri += "/managedVirtualNetworks/default/managedPrivateEndpoints/$managedPrivateEndpointName"
    $uri += "?api-version=2019-06-01-preview"

    $body = "{
        name: ""$managedPrivateEndpointName"",
        type: ""Microsoft.Synapse/workspaces/managedVirtualNetworks/managedPrivateEndpoints"",
        properties: {
            privateLinkResourceId: ""$managedPrivateEndpointID"",
            groupId: ""$managedPrivateEndpointGroup"",
            provisioningState: ""Succeeded"",
            privateLinkServiceConnectionState: {
            status: ""Approved"",
            description: ""Auto-Approved""
            }
        }
    }"

    Write-Host "Create Managed Private Endpoint for $managedPrivateEndpointName..."
    $retrycount = 1
    $completed = $false
    
    while (-not $completed) {
      try {
        Invoke-RestMethod -Method Put -ContentType "application/json" -Uri $uri -Headers $headers -Body $body -ErrorAction Stop
        Write-Host "Managed private endpoint for $managedPrivateEndpointName created successfully."
        $completed = $true
      }
      catch {
        if ($retrycount -ge $retries) {
          Write-Host "Managed private endpoint for $managedPrivateEndpointName creation failed the maximum number of $retryCount times."
          throw
        } else {
          Write-Host "Managed private endpoint creation for $managedPrivateEndpointName failed $retryCount time(s). Retrying in $secondsDelay seconds."
          Start-Sleep $secondsDelay
          $retrycount++
        }
      }
    }
  }

  #30 second delay interval for private link provisioning state = Succeeded
  $secondsDelay = 30

  #Approve Private Endpoints
  for($i = 0; $i -le ($managedPrivateEndpointNames.Length - 1); $i += 1)
  {
    $retrycount = 1
    $completed = $false
    
    while (-not $completed) {
      try {
        $managedPrivateEndpointName = $managedPrivateEndpointNames[$i]
        $managedPrivateEndpointID = $managedPrivateEndpointIDs[$i]

        # Approve KeyVault Private Endpoint
        $privateEndpoints = Get-AzPrivateEndpointConnection -PrivateLinkResourceId $managedPrivateEndpointID -ErrorAction Stop | select-object Id, ProvisioningState, PrivateLinkServiceConnectionState
        
        foreach ($privateEndpoint in $privateEndpoints) {
          if ($privateEndpoint.PrivateLinkServiceConnectionState.Status -eq "Pending") {
            if ($privateEndpoint.ProvisioningState -eq "Succeeded") {
              Write-Host "Approving private endpoint for $managedPrivateEndpointName."
              Approve-AzPrivateEndpointConnection -ResourceId $privateEndpoint.Id -Description "Auto-Approved" -ErrorAction Stop  
            }
            else {
              throw "Private endpoint connection not yet provisioned."
            }
          }
        }
        $completed = $true
      }
      catch {
        if ($retrycount -ge $retries) {
          Write-Host "Private endpoint approval for $managedPrivateEndpointName has failed the maximum number of $retryCount times."
          throw
        } else {
          Write-Host "Private endpoint approval for $managedPrivateEndpointName has failed $retryCount time(s). Retrying in $secondsDelay seconds."
          Write-Warning $PSItem.ToString()
          Start-Sleep $secondsDelay
          $retrycount++
        }
      }
    }
  }
}
