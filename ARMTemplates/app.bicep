param srcRGName string
param srcStorageAccountName string
param appNamePrefix string = uniqueString(resourceGroup().id)
param appWorkspaceId string = ''

var location = resourceGroup().location
var appStorageAccountName = format('{0}storage', replace(appNamePrefix, '-', ''))
var appStorageQueueName = 'events'
var appServiceName = '${appNamePrefix}-appservice'
var functionAppName = '${appNamePrefix}-functionapp'
var appInsightsName = '${appNamePrefix}-appinsights'
var rcloneScript = 'chmod +x rclone && ./rclone copy app:config config && ./rclone --config config/rclone.conf -v copy src:artifacts dst: && ./rclone copy config app:config'

resource srcStorageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' existing = {
  name: srcStorageAccountName
  scope: resourceGroup(srcRGName)
}

resource appStorageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: appStorageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2021-04-01' = {
  parent: appStorageAccount
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' = {
  parent: blobService
  name: 'config'
}

resource queueService 'Microsoft.Storage/storageAccounts/queueServices@2021-04-01' = {
  parent: appStorageAccount
  name: 'default'
}

resource queue 'Microsoft.Storage/storageAccounts/queueServices/queues@2021-04-01' = {
  parent: queueService
  name: appStorageQueueName
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: appWorkspaceId
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource appService 'Microsoft.Web/serverfarms@2021-01-15' = {
  name: appServiceName
  location: location
  kind: 'functionapp'
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
    size: 'Y1'
    family: 'Y'
    capacity: 0
  }
  properties: {
    perSiteScaling: false
    maximumElasticWorkerCount: 1
    isSpot: false
    reserved: true
    isXenon: false
    hyperV: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
  }
}

resource functionApp 'Microsoft.Web/sites@2021-01-15' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  properties: {
    enabled: true
    hostNameSslStates: [
      {
        name: '${functionAppName}.azurewebsites.net'
        sslState: 'Disabled'
        hostType: 'Standard'
      }
      {
        name: '${functionAppName}.scm.azurewebsites.net'
        sslState: 'Disabled'
        hostType: 'Standard'
      }
    ]
    serverFarmId: appService.id
    reserved: false
    isXenon: false
    hyperV: false
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${appStorageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${appStorageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: 'InstrumentationKey=${appInsights.properties.InstrumentationKey}'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'custom'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'WEBSITE_MAX_DYNAMIC_APPLICATION_SCALE_OUT'
          value: '1'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: 'https://github.com/yaegashi/rclonefunction/releases/latest/download/rclonefunction.zip'
        }
        {
          name: 'RCLONE_CONFIG_SRC_TYPE'
          value: 'azureblob'
        }
        {
          name: 'RCLONE_CONFIG_SRC_ACCOUNT'
          value: srcStorageAccount.name
        }
        {
          name: 'RCLONE_CONFIG_SRC_KEY'
          value: srcStorageAccount.listKeys().keys[0].value
        }
        {
          name: 'RCLONE_CONFIG_APP_TYPE'
          value: 'azureblob'
        }
        {
          name: 'RCLONE_CONFIG_APP_ACCOUNT'
          value: appStorageAccount.name
        }
        {
          name: 'RCLONE_CONFIG_APP_KEY'
          value: appStorageAccount.listKeys().keys[0].value
        }
        {
          name: 'RCLONE_SCRIPT'
          value: rcloneScript
        }
      ]
    }
    scmSiteAlsoStopped: false
    clientAffinityEnabled: false
    clientCertEnabled: false
    hostNamesDisabled: false
    dailyMemoryTimeQuota: 0
    httpsOnly: true
    redundancyMode: 'None'
  }
}

resource functionAppConfig 'Microsoft.Web/sites/config@2021-01-15' = {
  parent: functionApp
  name: 'web'
  properties: {
    numberOfWorkers: -1
    defaultDocuments: [
      'Default.htm'
      'Default.html'
      'Default.asp'
      'index.htm'
      'index.html'
      'iisstart.htm'
      'default.aspx'
      'index.php'
      'hostingstart.html'
    ]
    netFrameworkVersion: 'v4.0'
    phpVersion: '5.6'
    requestTracingEnabled: false
    remoteDebuggingEnabled: false
    httpLoggingEnabled: false
    logsDirectorySizeLimit: 35
    detailedErrorLoggingEnabled: false
    publishingUsername: '$${functionAppName}'
    scmType: 'None'
    use32BitWorkerProcess: true
    webSocketsEnabled: false
    alwaysOn: false
    managedPipelineMode: 'Integrated'
    virtualApplications: [
      {
        virtualPath: '/'
        physicalPath: 'site\\wwwroot'
        preloadEnabled: true
      }
    ]
    loadBalancing: 'LeastRequests'
    experiments: {
      rampUpRules: []
    }
    autoHealEnabled: false
    localMySqlEnabled: false
    ipSecurityRestrictions: [
      {
        ipAddress: 'Any'
        action: 'Allow'
        priority: 1
        name: 'Allow all'
        description: 'Allow all access'
      }
    ]
    scmIpSecurityRestrictions: [
      {
        ipAddress: 'Any'
        action: 'Allow'
        priority: 1
        name: 'Allow all'
        description: 'Allow all access'
      }
    ]
    scmIpSecurityRestrictionsUseMain: false
    http20Enabled: true
    minTlsVersion: '1.2'
    ftpsState: 'AllAllowed'
    preWarmedInstanceCount: 0
  }
}

resource functionAppBinding 'Microsoft.Web/sites/hostNameBindings@2021-01-15' = {
  parent: functionApp
  name: '${functionApp.name}.azurewebsites.net'
  properties: {
    siteName: functionApp.name
    hostNameType: 'Verified'
  }
}

output storageAccountId string = appStorageAccount.id
output storageQueueName string = queue.name
