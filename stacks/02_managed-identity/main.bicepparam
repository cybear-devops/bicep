using 'main.bicep'

@description('Required: The prefix/shortened name of the customer.')
param customerPrefix = 'cps'

@description('Required: The prefix/shortened name of the customer workload.')
param customerWorkload = 'dmz'

@description('Required: The environment into which your Azure resources should be deployed.')
param environment = 'dev'
