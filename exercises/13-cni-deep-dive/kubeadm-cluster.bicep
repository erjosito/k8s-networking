// exercises/13-cni-deep-dive/kubeadm-cluster.bicep
//
// Deploys 3 Ubuntu VMs (1 control-plane + 2 workers) for a kubeadm-based
// Kubernetes cluster.  CNI is deliberately NOT installed — the student
// will install it manually as part of the exercise.

@description('Azure region')
param location string = 'swedencentral'

@description('Prefix for all resource names')
param prefix string = 'ckne-cni'

@description('Admin username for the VMs')
param adminUsername string = 'azureuser'

@description('SSH public key for VM access')
@secure()
param sshPublicKey string

@description('VM size')
param vmSize string = 'Standard_D2s_v5'

@description('Kubernetes version to install')
param kubernetesVersion string = '1.30'

var vnetName = '${prefix}-vnet'
var subnetName = 'default'
var nsgName = '${prefix}-nsg'
var vmNames = ['${prefix}-cp', '${prefix}-w1', '${prefix}-w2']

// --- Network Security Group ---
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSSH'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowKubeAPI'
        properties: {
          priority: 1010
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '6443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// --- Virtual Network ---
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.0.0.0/16'] }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: { id: nsg.id }
        }
      }
    ]
  }
}

// --- Public IPs ---
resource publicIps 'Microsoft.Network/publicIPAddresses@2023-11-01' = [for name in vmNames: {
  name: '${name}-pip'
  location: location
  sku: { name: 'Standard' }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}]

// --- NICs ---
resource nics 'Microsoft.Network/networkInterfaces@2023-11-01' = [for (name, i) in vmNames: {
  name: '${name}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: { id: vnet.properties.subnets[0].id }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: { id: publicIps[i].id }
        }
      }
    ]
    enableIPForwarding: true
  }
}]

// --- Cloud-init: install containerd + kubeadm (but NOT a CNI plugin) ---
var cloudInit = '''
#!/bin/bash
set -euxo pipefail

# Disable swap
swapoff -a
sed -i '/swap/d' /etc/fstab

# Load required kernel modules
cat <<EOF > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

# Sysctl settings
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

# Install containerd
apt-get update -qq
apt-get install -y -qq containerd apt-transport-https ca-certificates curl gpg
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# Add Kubernetes apt repo
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${KUBE_VERSION}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBE_VERSION}/deb/ /" > /etc/apt/sources.list.d/kubernetes.list

# Install kubeadm, kubelet, kubectl
apt-get update -qq
apt-get install -y -qq kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
systemctl enable kubelet
'''

// --- VMs ---
resource vms 'Microsoft.Compute/virtualMachines@2024-03-01' = [for (name, i) in vmNames: {
  name: name
  location: location
  properties: {
    hardwareProfile: { vmSize: vmSize }
    osProfile: {
      computerName: name
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
      }
      customData: base64(replace(cloudInit, '\${KUBE_VERSION}', kubernetesVersion))
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: { storageAccountType: 'StandardSSD_LRS' }
        diskSizeGB: 64
      }
    }
    networkProfile: {
      networkInterfaces: [{ id: nics[i].id }]
    }
  }
}]

// --- Outputs ---
output controlPlanePublicIP string = publicIps[0].properties.ipAddress
output worker1PublicIP string = publicIps[1].properties.ipAddress
output worker2PublicIP string = publicIps[2].properties.ipAddress
output controlPlanePrivateIP string = nics[0].properties.ipConfigurations[0].properties.privateIPAddress
output sshCommand string = 'ssh ${adminUsername}@${publicIps[0].properties.ipAddress}'
