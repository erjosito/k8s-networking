@description('Azure region')
param location string = 'swedencentral'

param clusterName string = 'ckne-dualstack'

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: '${clusterName}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/8'
        'fd00:db8::/48'
      ]
    }
    subnets: [
      {
        name: 'aks-subnet'
        properties: {
          addressPrefixes: [
            '10.240.0.0/16'
            'fd00:db8:1::/64'
          ]
        }
      }
    ]
  }
}

resource aks 'Microsoft.ContainerService/managedClusters@2024-01-01' = {
  name: clusterName
  location: location
  identity: { type: 'SystemAssigned' }
  properties: {
    dnsPrefix: clusterName
    kubernetesVersion: '1.30'
    agentPoolProfiles: [
      {
        name: 'default'
        count: 3
        vmSize: 'Standard_D2s_v5'
        mode: 'System'
        osType: 'Linux'
        vnetSubnetID: vnet.properties.subnets[0].id
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'calico'
      ipFamilies: ['IPv4', 'IPv6']
      serviceCidrs: ['10.0.0.0/16', 'fd00:db8:2::/112']
      dnsServiceIP: '10.0.0.10'
    }
  }
}

output clusterName string = aks.name
