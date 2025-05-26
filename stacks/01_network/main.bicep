targetScope = 'subscription'

// ================ //
//    Parameters    //
// ================ //

// ################################################################################
// # Default Environment Configuration Parameters
// ################################################################################

@description('Required: The prefix/shortened name of the customer.')
param customerPrefix string

@description('Required: The prefix/shortened name of the customer workload.')
param customerWorkload string

@description('Required: The environment into which your Azure resources should be deployed.')
@allowed([
  'prd'
  'uat'
  'dev'
  'tst'
])
param environment string

// ################################################################################
// # Virtual Network,Subnet and DNS Address Prefix Parameters
// ################################################################################

@description('Optional: An Array of 1 or more IP Address Prefixes for the Virtual Network.')
param vnetAddressPrefixes array

@description('Optional: An Array of 1 or more IP Address Prefixes for the Virtual Network Subnets.')
param subnetAddressPrefixes array

@description('Optional: A count of the subnets based on the subnetAddressPrefixes array.')
param subnetCount int = length(subnetAddressPrefixes)

// ================ //
//     Variables    //
// ================ //

// ################################################################################
// # Default Environment Configuration Variables
// ################################################################################

@description('Optional: The location into which Azure resources should be deployed.')
var resourceLocation  = deployment().location

// ################################################################################
// # Default tags with values to be assigned to all tagged resources
// ################################################################################

// # Variable to convert environment shorthand variable
var environmentMap = {
  prd: 'Production'
  uat: 'User Acceptance Testing'
  tst: 'Test'
  dev: 'Development'
}

var fullEnvironment = environmentMap[environment]

@description('Optional: Timestamp to be generated dynamically (as a placeholder)')
param timestamp string = dateTimeAdd(utcNow(), 'PT1H', 'dd-MMM-yyyy HH:mm:ss')
// param timestamp string = dateTimeAdd(utcNow(), 'PT0H', 'dd-MMM-yyyy HH:mm:ss')

@description('Optional: The list of tags to be deployed with all Azure resources.')
var tags = {
  lastUpdated: timestamp
  ManagedByBicep: 'True'
  CustomerBudgetAmount: '£1000'
  CustomerCostCentre: '123456'
  CustomerDirectorate: 'DirectorateForDigital'
  CustomerDivision: 'CloudAndDigitalServices'
  CustomerOrganisation: 'CloudPlatformService'
  CustomerProgrammeName: 'CloudPlatform'
  Environment: fullEnvironment
  WorkloadName: 'Connectivity'
}

// ################################################################################
// # NSG Rules to be assigned to subnet NSG's
// ################################################################################

@description('Optional: The list of default Network Security Rules to be deployed with all Network Security Groups.')
var defaultSecurityRules = [
  {
    name: 'Deny-All-Inbound'
    properties: {
      priority: 4096
      direction: 'Inbound'
      access: 'Deny'
      description: 'Deny All Inbound to secure by default'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '*'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: '*'
    }
  }
  {
    name: 'Deny-All-Outbound'
    properties: {
      priority: 4096
      direction: 'Outbound'
      access: 'Deny'
      description: 'Deny All Outbound to secure by default'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '*'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: '*'
    }
  }
  {
    name: 'Allow-Azure-AD-Outbound'
    properties: {
      priority: 4050
      direction: 'Outbound'
      access: 'Allow'
      description: 'Allow All Outbound to Azure AD/Entra by default'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '*'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: 'AzureActiveDirectory'
    }
  }
  {
    name: 'Allow-Azure-Backup-Outbound'
    properties: {
      priority: 4045
      direction: 'Outbound'
      access: 'Allow'
      description: 'Allow All Outbound to Azure Backup by default'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '*'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: 'AzureBackup'
    }
  }
  {
    name: 'Allow-Azure-Cloud-Outbound'
    properties: {
      priority: 4040
      direction: 'Outbound'
      access: 'Allow'
      description: 'Allow All Outbound to Azure Cloud by default'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '*'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: 'AzureCloud'
    }
  }
  {
    name: 'Allow-Azure-KeyVault-Outbound'
    properties: {
      priority: 4035
      direction: 'Outbound'
      access: 'Allow'
      description: 'Allow All Outbound to Azure KeyVault by default'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '*'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: 'AzureKeyVault'
    }
  }
  {
    name: 'Allow-Azure-Load-Balancer-Outbound'
    properties: {
      priority: 4030
      direction: 'Outbound'
      access: 'Allow'
      description: 'Allow All Outbound to Azure Load Balancer by default'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '*'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: 'AzureLoadBalancer'
    }
  }
  {
    name: 'Allow-Azure-Monitor-Outbound'
    properties: {
      priority: 4025
      direction: 'Outbound'
      access: 'Allow'
      description: 'Allow All Outbound to Azure Monitor by default'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '*'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: 'AzureMonitor'
    }
  }
  {
    name: 'Allow-Azure-Storage-Outbound'
    properties: {
      priority: 4020
      direction: 'Outbound'
      access: 'Allow'
      description: 'Allow All Outbound to Azure Storage by default'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '*'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: 'Storage'
    }
  }
]


// ================ //
//   Dependencies   //
// ================ //

// ================ //
//       Main       //
// ================ //

// ################################################################################
// # 1. Create a Network Resource Group
// ################################################################################

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-${customerPrefix}-${customerWorkload}-${environment}-net'
  location: resourceLocation
  tags: tags
}

// ################################################################################
// # 2. Create Network Security Groups for the Subnet(s)
// #    This will be assigned to the Subnet(s) on Subnet Creation
// ################################################################################

module networkSecurityGroup 'br/public:avm/res/network/network-security-group:0.5.1' = [
  for i in range(0, subnetCount): {
    scope: resourceGroup
    name: '${uniqueString(deployment().name, resourceLocation)}-networkSecurityGroup${i+1}-${customerPrefix}-${customerWorkload}-${environment}'
    params: {
      name: 'nsg-snet${i+1}-${customerPrefix}-${customerWorkload}-${environment}'
      location: resourceLocation
      tags: tags
      enableTelemetry: false
      securityRules: defaultSecurityRules
    }
  }
]

// ################################################################################
// # 3. Create a Virtual Network and Subnet(s)
// ################################################################################

module virtualNetwork 'br/public:avm/res/network/virtual-network:0.6.1' = {
  scope: resourceGroup
  name: '${uniqueString(deployment().name, resourceLocation)}-virtualNetwork-${customerPrefix}-${customerWorkload}-${environment}'
  params: {
    name: 'vnet-${customerPrefix}-${customerWorkload}-${environment}'
    location: resourceLocation
    tags: tags
    enableTelemetry: false
    addressPrefixes: vnetAddressPrefixes
    vnetEncryption: true
    subnets: [
      for i in range (0, subnetCount): {
        name: 'snet${i+1}-vnet-${customerPrefix}-${customerWorkload}-${environment}'
        addressPrefixes: [subnetAddressPrefixes[i]]
        networkSecurityGroupResourceId: networkSecurityGroup[i].outputs.resourceId
      }
    ]
  }
}
