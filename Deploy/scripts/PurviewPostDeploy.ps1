param(
  [string] $PurviewAccountName,
  [string] $ScanEndpoint,
  [string] $APIVersion,
  [string] $KeyVaultName,
  [string] $KeyVaultID,
  [string] $UAMIIdentityID,
  [string] $DataLakeAccountName,
  [string] $SynapseWorkspaceName
)

$retries = 10
$secondsDelay = 5

#Connect-AzAccount -Subscription 96bd7145-ad7f-445a-9763-862e32480bf1

$token = (Get-AzAccessToken -Resource "https://purview.azure.net").Token
$headers = @{ Authorization = "Bearer $token" }

#------------------------------------------------------------------------------------------------------------
# ADD UAMIIdentityID TO COLLECTION ADMINISTRATOR AND DATA SOURCE ADMINISTRATOR ROLES
#------------------------------------------------------------------------------------------------------------

$PolicyId = ""
$uri = "https://$PurviewAccountName.purview.azure.com/policystore/metadataPolicies/`?api-version=$APIVersion"

$retrycount = 1
$completed = $false

while (-not $completed) {
  try {
    #Retrieve Purview default metadata policy ID
    Write-Host "List Metadata Policies..."
    $result = Invoke-RestMethod -Method Get -ContentType "application/json" -Uri $uri -Headers $headers -Body $body -ErrorAction Stop
    $PolicyId = $result.values.Id

    Write-Host "Retrieve metadata policy (ID $PolicyId) details..."
    $uri = "https://$PurviewAccountName.purview.azure.com/policystore/metadataPolicies/$PolicyId`?api-version=$APIVersion"

    #Retrieve Metadata Policy details and add Deployment Script UAMI PrincipalID to Collection Administrator and Data Source Administrator Roles.
    $result = Invoke-RestMethod -Method Get -ContentType "application/json" -Uri $uri -Headers $headers -Body $body -ErrorAction Stop
    foreach ($attributeRule in $result.properties.attributeRules) {
      if ($attributeRule.id -like "*collection-administrator*" -or $attributeRule.id -like "*data-source-administrator*") {
        if (-not ($attributeRule.dnfCondition[0][0].attributeValueIncludedIn -contains $UAMIIdentityID)) {
          Write-Host "Add user to $attributeRule.id role..."
          $attributeRule.dnfCondition[0][0].attributeValueIncludedIn += $UAMIIdentityID  
        }
      } 
    }

    #Update Metadata Policy
    Write-Host "Update metadata policy (ID $PolicyId)..."
    $body = ConvertTo-Json -InputObject $result -Depth 10
    Invoke-RestMethod -Method Put -ContentType "application/json" -Uri $uri -Headers $headers -Body $body -ErrorAction Stop
    $completed = $true
  }
  catch {
    if ($retrycount -ge $retries) {
        Write-Host "Metadata policy update failed the maximum number of $retryCount times."
        throw
    } else {
        Write-Host "Metadata policy update failed $retryCount time(s). Retrying in $secondsDelay seconds."
        Write-Warning $Error[0]
        Start-Sleep $secondsDelay
        $retrycount++
    }
  }
}

#------------------------------------------------------------------------------------------------------------
# CREATE KEY VAULT CONNECTION
#------------------------------------------------------------------------------------------------------------

$uri = $ScanEndpoint + "/azureKeyVaults/$KeyVaultName`?api-version=$APIVersion"
#Create KeyVault Connection
$body = "{
  ""name"": ""$KeyVaultName"",
  ""id"": ""$KeyVaultID"",
  ""properties"": {
      ""baseUrl"": ""https://$KeyVaultName.vault.azure.net/""
  }
}"

Write-Host "Creating Azure KeyVault connection..."

$retrycount = 1
$completed = $false

while (-not $completed) {
  try {
    $result = Invoke-RestMethod -Method Put -ContentType "application/json" -Uri $uri -Headers $headers -Body $body -ErrorAction Stop
    Write-Host "KeyVault connection created successfully."
    $completed = $true
  }
  catch {
    if ($retrycount -ge $retries) {
        Write-Host "KeyVault connection failed the maximum number of $retryCount times."
        throw
    } else {
        Write-Host "KeyVault connection failed $retryCount time(s). Retrying in $secondsDelay seconds."
        Write-Warning $Error[0]
        Start-Sleep $secondsDelay
        $retrycount++
    }
  }
}

Write-Host "Registering Azure Data Lake data source..."

$uri = $ScanEndpoint + "/datasources/$DataLakeAccountName`?api-version=$APIVersion"

#------------------------------------------------------------------------------------------------------------
# REGISTER DATA SOURCES
#------------------------------------------------------------------------------------------------------------

#Register Azure Data Lake data source
$body = "{
  ""kind"": ""AdlsGen2"",
  ""name"": ""$DataLakeAccountName"",
  ""properties"": {
      ""endpoint"": ""https://$DataLakeAccountName.dfs.core.windows.net/"",
      ""collection"": {
        ""type"": ""CollectionReference"",
        ""referenceName"": ""$PurviewAccountName""
      }
  }
}"

$retrycount = 1
$completed = $false

while (-not $completed) {
  try {
    $result = Invoke-RestMethod -Method Put -ContentType "application/json" -Uri $uri -Headers $headers -Body $body -ErrorAction Stop
    Write-Host "Azure Data Lake source registered successfully."
    $completed = $true
  }
  catch {
    if ($retrycount -ge $retries) {
        Write-Host "Azure Data Lake source registration failed the maximum number of $retryCount times."
        throw
    } else {
        Write-Host "Azure Data Lake source registration failed $retryCount time(s). Retrying in $secondsDelay seconds."
        Write-Warning $Error[0]
        Start-Sleep $secondsDelay
        $retrycount++
    }
  }
}
#------------------------------------------------------------------------------------------------------------

#Register Synapse Workspace Data Source
$uri = $ScanEndpoint + "/datasources/$SynapseWorkspaceName\?api-version=$APIVersion"

$SynapseSQLDedicatedEndpoint = $SynapseWorkspaceName + ".sql.azuresynapse.net"
$SynapseSQLServerlessEndpoint =  $SynapseWorkspaceName + "-ondemand.sql.azuresynapse.net"

$body = "{
  ""kind"": ""AzureSynapseWorkspace"",
  ""name"": ""$SynapseWorkspaceName"",
  ""properties"": {
      ""dedicatedSqlEndpoint"": ""$SynapseSQLDedicatedEndpoint"",
      ""serverlessSqlEndpoint"": ""$SynapseSQLServerlessEndpoint"",
      ""resourceName"": ""$SynapseWorkspaceName"",
      ""collection"": {
        ""type"": ""CollectionReference"",
        ""referenceName"": ""$PurviewAccountName""
      }
  }
}"

$retrycount = 1
$completed = $false

while (-not $completed) {
  try {
    $result = Invoke-RestMethod -Method Put -ContentType "application/json" -Uri $uri -Headers $headers -Body $body -ErrorAction Stop
    Write-Host "Azure Synapse source registered successfully."
    $completed = $true
  }
  catch {
    if ($retrycount -ge $retries) {
        Write-Host "Azure Synapse source registration failed the maximum number of $retryCount times."
        throw
    } else {
        Write-Host "Azure Synapse source registration failed $retryCount time(s). Retrying in $secondsDelay seconds."
        Write-Warning $Error[0]
        Start-Sleep $secondsDelay
        $retrycount++
    }
  }
}
#------------------------------------------------------------------------------------------------------------
