param(
  [string] $ScanEndpoint,
  [string] $KeyVaultName,
  [string] $KeyVaultID,
  [string] $UAMIIdentityID
)

$retries = 10
$secondsDelay = 30

#------------------------------------------------------------------------------------------------------------
# ASSIGN WORKSPACE ADMINISTRATOR TO USER-ASSIGNED MANAGED IDENTITY
#------------------------------------------------------------------------------------------------------------

Connect-AzAccount -Subscription 96bd7145-ad7f-445a-9763-862e32480bf1

$token = (Get-AzAccessToken -Resource "https://purview.azure.net").Token
$headers = @{ Authorization = "Bearer $token" }

$uri = $ScanEndpoint
$uri += "/azureKeyVaults/keyVault-A3r?api-version=2018-12-01-preview"

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