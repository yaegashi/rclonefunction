param srcStorageAccountName string
param srcStorageContainerName string
param appStorageAccountId string
param appStorageQueueName string = 'events'

var location = resourceGroup().location
var eventGridName = '${srcStorageAccountName}-eventgrid'

resource srcStorageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: srcStorageAccountName
}

resource eventGrid 'Microsoft.EventGrid/systemTopics@2021-06-01-preview' = {
  name: eventGridName
  location: location
  properties: {
    source: srcStorageAccount.id
    topicType: 'Microsoft.Storage.StorageAccounts'
  }
}

resource eventGridSubscription 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2021-06-01-preview' = {
  parent: eventGrid
  name: 'events'
  properties: {
    destination: {
      properties: {
        resourceId: appStorageAccountId
        queueName: appStorageQueueName
        queueMessageTimeToLiveInSeconds: 604800
      }
      endpointType: 'StorageQueue'
    }
    filter: {
      subjectBeginsWith: '/blobServices/default/containers/${srcStorageContainerName}/blobs'
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
