@description('Private Endpoint Name')
param privateEndpoitName string 

@description('Resource Location')
param resourceLocation string 

@description('Private Link Service ID')
param privateLinkServiceId string

@description('Private Link Group ID')
param groupID string

@description('Subnet ID')
param subnetID string 

@description('Private DNS Zone Config Name')
param privateDnsZoneConfigName string 

@description('Private DNS Zone ID')
param privateDnsZoneId string

@description('Deploy DNS Zone Group')
param deployDNSZoneGroup bool = true


resource r_privateEndpoint 'Microsoft.Network/privateEndpoints@2020-11-01' = {
  name: privateEndpoitName
  location:resourceLocation
  properties:{
    subnet:{
      id: subnetID
    }
    privateLinkServiceConnections:[
      {
        name:privateEndpoitName
        properties:{
          privateLinkServiceId: privateLinkServiceId
          groupIds:[
            groupID
          ]
        }
      }
    ]
  }

  resource r_vNetPrivateDNSZoneGroupSynapseSQL 'privateDnsZoneGroups' = if(deployDNSZoneGroup) {
    name: 'default'
    properties:{
      privateDnsZoneConfigs:[
        {
          name:privateDnsZoneConfigName
          properties:{
            privateDnsZoneId: privateDnsZoneId
          }
        }
      ]
    }
  }
}
