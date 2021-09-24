param storageAccountName string
param storageContainerName string
param functionStorageAccountId string
param functionStorageQueueName string = 'events'

var location = resourceGroup().location
var eventGridName = '${storageAccountName}-eventgrid'

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2019-06-01' = {
  parent: storageAccount
  name: 'default'
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' = {
  parent: blobService
  name: storageContainerName
}

resource eventGrid 'Microsoft.EventGrid/systemTopics@2021-06-01-preview' = {
  name: eventGridName
  location: location
  properties: {
    source: storageAccount.id
    topicType: 'Microsoft.Storage.StorageAccounts'
  }
}

resource eventGridSubscription 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2021-06-01-preview' = {
  parent: eventGrid
  name: 'events'
  properties: {
    destination: {
      properties: {
        resourceId: functionStorageAccountId
        queueName: functionStorageQueueName
        queueMessageTimeToLiveInSeconds: 604800
      }
      endpointType: 'StorageQueue'
    }
    filter: {
      subjectBeginsWith: '/blobServices/default/containers/${container.name}/blobs'
      includedEventTypes: [
        'Microsoft.Storage.BlobCreated'
        'Microsoft.Storage.BlobDeleted'
        'Microsoft.Storage.BlobRenamed'
        'Microsoft.Storage.DirectoryCreated'
        'Microsoft.Storage.DirectoryDeleted'
        'Microsoft.Storage.DirectoryRenamed'
      ]
      enableAdvancedFilteringOnArrays: true
    }
    eventDeliverySchema: 'EventGridSchema'
    retryPolicy: {
      maxDeliveryAttempts: 30
      eventTimeToLiveInMinutes: 1440
    }
  }
}
