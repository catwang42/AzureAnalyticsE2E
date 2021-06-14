param resourceLocation string
param eventHubNamespaceName string
param eventHubName string
param eventHubSku string
param eventHubPartitionCount int
param streamAnalyticsJobName string
param streamAnalyticsJobSku string
param dataLakeStorageAccountID string

resource r_eventHubNamespace 'Microsoft.EventHub/namespaces@2017-04-01' = {
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
            storageAccountResourceId: dataLakeStorageAccountID
            blobContainer: 'raw'
            archiveNameFormat: '{Namespace}/{EventHub}/{PartitionId}/{Year}/{Month}/{Day}/{Hour}/{Minute}/{Second}'
          }
        }
      }
    }
  }
}

resource r_streamAnalyticsJob 'Microsoft.StreamAnalytics/streamingjobs@2017-04-01-preview' = {
  name: streamAnalyticsJobName
  location: resourceLocation
  properties:{
    sku:{
      name:streamAnalyticsJobSku
    }
  }
}
