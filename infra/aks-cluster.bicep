// ============================================================================
// AKS Cluster — Shared infrastructure for CKNE exercises
// ============================================================================
// Deploys a basic AKS cluster with Azure CNI Overlay and Calico network policy.
// CNI Overlay gives pods their own CIDR (separate from the node subnet),
// which is the more common pattern in Kubernetes.
// Most exercises (01-10) can share this single cluster.
// Exercises 11 and 12 have additional Bicep templates for multi-zone and
// dual-stack configurations respectively.
// ============================================================================

@description('Azure region for the AKS cluster')
param location string = resourceGroup().location

@description('Name of the AKS cluster')
param clusterName string = 'ckne-aks'


@description('VM size for the default node pool')
param vmSize string = 'Standard_D2s_v5'

@description('Number of nodes in the default node pool')
param nodeCount int = 3

@description('Network plugin to use')
@allowed(['azure', 'kubenet'])
param networkPlugin string = 'azure'

@description('Network policy to use')
@allowed(['calico', 'azure', 'none'])
param networkPolicy string = 'calico'

@description('Virtual network address prefix')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Subnet address prefix for the AKS nodes')
param subnetAddressPrefix string = '10.0.0.0/24'

@description('Service CIDR for Kubernetes Services')
param serviceCidr string = '10.1.0.0/16'

@description('DNS service IP (must be within serviceCidr)')
param dnsServiceIP string = '10.1.0.10'

@description('Pod CIDR for overlay networking')
param podCidr string = '10.244.0.0/16'

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: '${clusterName}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'aks-subnet'
        properties: {
          addressPrefix: subnetAddressPrefix
        }
      }
    ]
  }
}

// AKS Cluster
resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-01-01' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: clusterName
    agentPoolProfiles: [
      {
        name: 'default'
        count: nodeCount
        vmSize: vmSize
        mode: 'System'
        osType: 'Linux'
        vnetSubnetID: vnet.properties.subnets[0].id
      }
    ]
    networkProfile: {
      networkPlugin: networkPlugin
      networkPluginMode: 'overlay'
      networkPolicy: networkPolicy
      serviceCidr: serviceCidr
      dnsServiceIP: dnsServiceIP
      podCidr: podCidr
    }
  }
}

output clusterName string = aksCluster.name
output clusterFqdn string = aksCluster.properties.fqdn
