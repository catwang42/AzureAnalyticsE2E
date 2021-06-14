
param vNetID string
param vNetName string

param ctrlDeployPurview bool
param ctrlDeployAI bool
param ctrlDeployStreaming bool
//param crtlDeployDataShare bool


var environmentStorageDNS = environment().suffixes.storage

//Private DNS Zones required for Storage DFS Private Link: privatelink.dfs.core.windows.net
//Required for Azure Data Lake Gen2
module m_privateDNSZoneStorageDFS './PrivateDNSZone.bicep' = {
  name: 'PrivateDNSZoneStorageDFS'
  params: {
    dnsZoneName: 'privatelink.dfs.${environmentStorageDNS}'
    vNetID: vNetID
    vNetName: vNetName
  }
}

//Private DNS Zones required for Storage Blob Private Link: privatelink.blob.core.windows.net
//Required for Purview, Azure ML
module m_privateDNSZoneStorageBlob 'PrivateDNSZone.bicep' = if (ctrlDeployPurview == true || ctrlDeployAI == true){
  name: 'PrivateDNSZoneStorageBlob'
  params: {
    dnsZoneName: 'privatelink.blob.${environmentStorageDNS}'
    vNetID: vNetID
    vNetName: vNetName
  }
}

//Private DNS Zones required for Storage Queue Private Link: privatelink.queue.core.windows.net
//Required for Purview
module m_privateDNSZoneStorageQueue 'PrivateDNSZone.bicep' = if (ctrlDeployPurview == true) {
  name: 'PrivateDNSZoneStorageQueue'
  params: {
    dnsZoneName: 'privatelink.queue.${environmentStorageDNS}'
    vNetID: vNetID
    vNetName: vNetName
  }
}

//Private DNS Zones required for Storage File Private Link: privatelink.queue.core.windows.net
//Required for Azure ML Storage Account
module m_privateDNSZoneStorageFile 'PrivateDNSZone.bicep' = if (ctrlDeployAI == true) {
  name: 'PrivateDNSZoneStorageFile'
  params: {
    dnsZoneName: 'privatelink.file.${environmentStorageDNS}'
    vNetID: vNetID
    vNetName: vNetName
  }
}

//Private DNS Zones required for Synapse Private Link: privatelink.sql.azuresynapse.net
//Required for Synapse
module m_privateDNSZoneSynapseSQL './PrivateDNSZone.bicep' = {
  name: 'PrivateDNSZoneSynapseSQL'
  params: {
    dnsZoneName: 'privatelink.sql.azuresynapse.net'
    vNetID: vNetID
    vNetName: vNetName
  }
}

//Private DNS Zones required for Synapse Private Link: privatelink.dev.azuresynapse.net
//Required for Synapse
module m_privateDNSZoneSynapseDev './PrivateDNSZone.bicep' = {
  name: 'PrivateDNSZoneSynapseDev'
  params: {
    dnsZoneName: 'privatelink.dev.azuresynapse.net'
    vNetID: vNetID
    vNetName: vNetName
  }
}

//Private DNS Zones required for Synapse Private Link: privatelink.azuresynapse.net
//Required for Synapse
module m_privateDNSZoneSynapseWeb './PrivateDNSZone.bicep' = {
  name: 'PrivateDNSZoneSynapseWeb'
  params: {
    dnsZoneName: 'privatelink.azuresynapse.net'
    vNetID: vNetID
    vNetName: vNetName
  }
}

//Private DNS Zones required for Synapse Private Link: privatelink.vaultcore.azure.net
//Required for KeyVault
module m_privateDNSZoneKeyVault './PrivateDNSZone.bicep' = {
  name: 'privatelink.vaultcore.azure.net'
  params: {
    dnsZoneName: 'privatelink.vaultcore.azure.net'
    vNetID: vNetID
    vNetName: vNetName
  }
}

//Private DNS Zones required for EventHubs: privatelink.servicebus.windows.net
//Required for Purview and Event Hubs
module m_privateDNSZoneServiceBus './PrivateDNSZone.bicep' = if(ctrlDeployPurview == true || ctrlDeployStreaming == true){
  name: 'PrivateDNSZoneServiceBus'
  params: {
    dnsZoneName: 'privatelink.servicebus.windows.net'
    vNetID: vNetID
    vNetName: vNetName
  }
}

//Purview Account and Portal private endpoints
module m_privateDNSZonePurviewAccount 'PrivateDNSZone.bicep' = if(ctrlDeployPurview == true) {
  name: 'privatelink.purview.azure.com'
  params: {
    dnsZoneName: 'privatelink.purview.azure.com'
    vNetID: vNetID
    vNetName: vNetName
  }
}

//Azure Container Registry DNS Zone privatelink.azurecr.io
//Required by Azure ML
module m_privateDNSZoneACR 'PrivateDNSZone.bicep' = if(ctrlDeployAI == true) {
  name: 'privatelink.azurecr.io'
  params: {
    dnsZoneName: 'privatelink.azurecr.io'
    vNetID: vNetID
    vNetName: vNetName
  }
}

//Azure Machine Learning Workspace DNS Zone: privatelink.azurecr.io
//Required by Azure ML
module m_privateDNSZoneAzureMLAPI 'PrivateDNSZone.bicep' = if(ctrlDeployAI == true) {
  name: 'privatelink.api.azureml.ms'
  params: {
    dnsZoneName: 'privatelink.api.azureml.ms'
    vNetID: vNetID
    vNetName: vNetName
  }
}

//Azure Machine Learning Workspace DNS Zone: privatelink.notebooks.azure.net
//Required by Azure ML
module m_privateDNSZoneAzureMLNotebooks 'PrivateDNSZone.bicep' = if(ctrlDeployAI == true) {
  name: 'privatelink.notebooks.azure.net'
  params: {
    dnsZoneName: 'privatelink.notebooks.azure.net'
    vNetID: vNetID
    vNetName: vNetName
  }
}

output storageDFSPrivateDNSZoneID string = m_privateDNSZoneStorageDFS.outputs.dnsZoneID
output storageBlobPrivateDNSZoneID string = m_privateDNSZoneStorageBlob.outputs.dnsZoneID
output storageQueuePrivateDNSZoneID string = m_privateDNSZoneStorageQueue.outputs.dnsZoneID
output storageFilePrivateDNSZoneID string = m_privateDNSZoneStorageFile.outputs.dnsZoneID
output synapseSQLPrivateDNSZoneID string = m_privateDNSZoneSynapseSQL.outputs.dnsZoneID
output synapseDevPrivateDNSZoneID string = m_privateDNSZoneSynapseDev.outputs.dnsZoneID
output synapseWebPrivateDNSZoneID string = m_privateDNSZoneSynapseWeb.outputs.dnsZoneID
output keyVaultPrivateDNSZoneID string = m_privateDNSZoneKeyVault.outputs.dnsZoneID
output serviceBusPrivateDNSZoneID string = m_privateDNSZoneServiceBus.outputs.dnsZoneID
output purviewAccountPrivateDNSZoneID string = m_privateDNSZonePurviewAccount.outputs.dnsZoneID
output acrPrivateDNSZoneID string = m_privateDNSZoneACR.outputs.dnsZoneID
output azureMLAPIPrivateDNSZoneID string = m_privateDNSZoneAzureMLAPI.outputs.dnsZoneID
output azureMLNotebooksPrivateDNSZoneID string = m_privateDNSZoneAzureMLNotebooks.outputs.dnsZoneID
