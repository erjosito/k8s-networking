@description('Azure region (must support availability zones)')
param location string = 'swedencentral'

param clusterName string = 'ckne-multizone'

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: '${clusterName}-vnet'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.0.0.0/8'] }
    subnets: [{ name: 'aks-subnet', properties: { addressPrefix: '10.240.0.0/16' } }]
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
        availabilityZones: ['1', '2', '3']
        vnetSubnetID: vnet.properties.subnets[0].id
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'calico'
      serviceCidr: '10.0.0.0/16'
      dnsServiceIP: '10.0.0.10'
    }
  }
}

output clusterName string = aks.name
