targetScope = 'subscription'

param appRGName string
param srcRGName string
param storageAccountName string
param storageContainerName string = 'artifacts'

var location = deployment().location

resource srcRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: srcRGName
  location: location
}

module srcModule 'src.bicep' = {
  name: 'srcModule'
  scope: srcRG
  params: {
    storageAccountName: storageAccountName
    storageContainerName: storageContainerName
  }
}

module eventgridModule 'eventgrid.bicep' = {
  name: 'eventgridModule'
  scope: srcRG
  params: {
    srcStorageAccountName: srcModule.outputs.storageAccountName
    srcStorageContainerName: srcModule.outputs.storageContainerName
    appStorageAccountId: appModule.outputs.storageAccountId
    appStorageQueueName: appModule.outputs.storageQueueName
  }
}

resource appRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: appRGName
  location: location
}

module appModule 'app.bicep' = {
  name: 'appModule'
  scope: appRG
  params: {
    srcRGName: srcRGName
    srcStorageAccountName: srcModule.outputs.storageAccountName
  }
}
