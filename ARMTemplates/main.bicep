targetScope = 'subscription'

param storageRGName string
param storageAccountName string
param storageContainerName string = 'artifacts'
param functionRGName string

var location = deployment().location

resource storageRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: storageRGName
  location: location
}

module storageModule 'storage.bicep' = {
  name: 'storageModule'
  scope: storageRG
  params: {
    storageAccountName: storageAccountName
    storageContainerName: storageContainerName
    functionStorageAccountId: functionModule.outputs.storageAccountId
    functionStorageQueueName: functionModule.outputs.storageQueueName
  }
}

resource functionRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: functionRGName
  location: location
}

module functionModule 'function.bicep' = {
  name: 'functionModule'
  scope: functionRG
}
