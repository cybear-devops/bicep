targetScope = 'subscription'

// ================ //
//    Parameters    //
// ================ //

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
// # Subnet Prefix Parameters to add to the KeyVault
// ################################################################################

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
// # Subnet Resource ID's to add to the Key Vault
// ################################################################################

@description('Optional: An Array of 1 or more AC Subnet Resource Ids to add to allow Key Vault access.')
var subnetResourceIds = [
  for i in range(0, subnetCount): {
    id: resourceId(subscription().subscriptionId, networkResourceGroup.name, 'Microsoft.Network/virtualNetworks/subnets', 'vnet-${customerPrefix}-${customerWorkload}-${environment}','snet${i+1}-vnet-${customerPrefix}-${customerWorkload}-${environment}')
  }
]

// ================ //
//   Dependencies   //
// ================ //

resource networkResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: 'rg-${customerPrefix}-${customerWorkload}-${environment}-net'
}

// ================ //
//       Main       //
// ================ //

// ################################################################################
// # 1. Create a KeyVault Resource Group
// ################################################################################

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-${customerPrefix}-${customerWorkload}-${environment}-kv'
  location: resourceLocation
  tags: tags
}

// ################################################################################
// # 2. Create a KeyVault
// ################################################################################

module keyvault 'br/public:avm/res/key-vault/vault:0.12.1' = {
  scope: resourceGroup
  name: '${uniqueString(deployment().name, resourceLocation)}-keyvault-${customerPrefix}-${customerWorkload}-${environment}'
  params: {
    name: 'kv-${customerPrefix}-${customerWorkload}-${environment}'
    location: resourceLocation
    tags: tags
    enableTelemetry: false
    sku: 'standard'
    enableRbacAuthorization: true
    enableSoftDelete: false  // For Test and Dev environments, set to false
    enablePurgeProtection: false  // For Test and Dev environments, set to false
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      virtualNetworkRules: subnetResourceIds
    }
  }
}
