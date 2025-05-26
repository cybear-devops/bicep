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

// ================ //
//   Dependencies   //
// ================ //

// ================ //
//       Main       //
// ================ //

// ################################################################################
// # 1. Create a User Managed Identity Resource Group
// ################################################################################

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-${customerPrefix}-${customerWorkload}-${environment}-umi'
  location: resourceLocation
  tags: tags
}

// ################################################################################
// # 2. Create a User Assigned Managed Identity
// ################################################################################

  module userAssignedManagedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = {
  scope: resourceGroup
  name: '${uniqueString(deployment().name, resourceLocation)}-umi-app-${customerPrefix}-${customerWorkload}-${environment}'
  params: {
    name: 'umi-${customerPrefix}-${customerWorkload}-${environment}'
    location: resourceLocation
    tags: tags
    enableTelemetry: false
  }
}
