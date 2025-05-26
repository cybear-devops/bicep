using 'main.bicep'

@description('Required: The prefix/shortened name of the customer.')
param customerPrefix = 'cps'

@description('Required: The prefix/shortened name of the customer workload.')
param customerWorkload = 'example'

@description('Required: The environment into which your Azure resources should be deployed.')
param environment = 'dev'

@description('Optional: An Array of 1 or more IP Address Prefixes for the Virtual Network Subnets.')
param subnetAddressPrefixes = ['10.0.0.0/24', '10.0.1.0/24','10.0.2.0/27','10.0.2.32/27']
