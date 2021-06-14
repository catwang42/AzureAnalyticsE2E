param(
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
# CREATE KEY VAULT CONNECTION
#------------------------------------------------------------------------------------------------------------

$uri = $ScanEndpoint + "/azureKeyVaults/$KeyVaultName\?api-version=$APIVersion"
Write-Host $uri
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

$uri = $ScanEndpoint + "/datasources/$DataLakeAccountName\?api-version=$APIVersion"

#------------------------------------------------------------------------------------------------------------
# REGISTER DATA SOURCES
#------------------------------------------------------------------------------------------------------------

#Register Azure Data Lake data source
$body = "{
  ""kind"": ""AdlsGen2"",
  ""name"": ""$DataLakeAccountName"",
  ""properties"": {
      ""endpoint"": ""https://$DataLakeAccountName.dfs.core.windows.net/""
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
      ""resourceName"": ""$SynapseWorkspaceName""
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
