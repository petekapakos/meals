@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Tags that will be applied to all resources')
param tags object = {}

param mealsExists bool

@secure()
param mealsDefinition object

@secure()
param openAiApiKey string

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = uniqueString(subscription().id, resourceGroup().id, location)
var storageAccountName = '${abbrs.storageStorageAccounts}${resourceToken}'
var mealsIdentityName = '${abbrs.managedIdentityUserAssignedIdentities}meals-${resourceToken}'

// Monitor application with Azure Monitor
module monitoring 'br/public:avm/ptn/azd/monitoring:0.1.0' = {
  name: 'monitoring'
  params: {
    logAnalyticsName: '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: '${abbrs.insightsComponents}${resourceToken}'
    applicationInsightsDashboardName: '${abbrs.portalDashboards}${resourceToken}'
    location: location
    tags: tags
  }
}

// Container registry
module containerRegistry 'br/public:avm/res/container-registry/registry:0.1.1' = {
  name: 'registry'
  params: {
    name: '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    acrAdminUserEnabled: true
    tags: tags
    publicNetworkAccess: 'Enabled'
    roleAssignments: [
      {
        principalId: mealsIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: subscriptionResourceId(
          'Microsoft.Authorization/roleDefinitions',
          '7f951dda-4ed3-4680-a7ca-43fe172d538d'
        )
      }
    ]
  }
}

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

module mealsIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: 'mealsidentity'
  params: {
    name: mealsIdentityName
    location: location
  }
}

// Assign Storage Table Data Contributor role to managed identity
resource storageRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, 'mealsidentity', 'storage-table-data-contributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
    ) // Storage Table Data Contributor
    principalId: mealsIdentity.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

// Deployment script to create table
resource createTableScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: '${resourceToken}-create-table'
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${resourceId(subscription().subscriptionId, resourceGroup().name, 'Microsoft.ManagedIdentity/userAssignedIdentities', '${abbrs.managedIdentityUserAssignedIdentities}meals-${resourceToken}')}': {}
    }
  }
  properties: {
    azPowerShellVersion: '8.3'
    timeout: 'PT30M'
    retentionInterval: 'P1D'
    cleanupPreference: 'OnSuccess'
    scriptContent: '''
      param(
        [string] $StorageAccountName,
        [string] $TableName
      )
      
      $ctx = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount
      New-AzStorageTable -Name $TableName -Context $ctx -ErrorAction SilentlyContinue
    '''
    arguments: '-StorageAccountName ${storageAccount.name} -TableName "mealplans"'
  }
  dependsOn: [
    storageRole
  ]
}

// Create a keyvault to store secrets
module keyVault 'br/public:avm/res/key-vault/vault:0.6.1' = {
    name: 'keyvault'
    params: {
      name: '${abbrs.keyVaultVaults}${resourceToken}'
      location: location
      tags: tags
      enableRbacAuthorization: true
      secrets: [
        {
          name: 'openai-api-key'
          value: openAiApiKey
        }
      ]
    }
  }

module kv './modules/kv.bicep' = {
  name: 'kv'
  params: {
    mealsIdentityName: mealsIdentityName
  }
  dependsOn: [
    mealsIdentity
  ]
}

// Container apps environment
module containerAppsEnvironment 'br/public:avm/res/app/managed-environment:0.4.5' = {
  name: 'container-apps-environment'
  dependsOn: [
    kv
  ]
  params: {
    logAnalyticsWorkspaceResourceId: monitoring.outputs.logAnalyticsWorkspaceResourceId
    name: '${abbrs.appManagedEnvironments}${resourceToken}'
    location: location
    zoneRedundant: false
  }
}

module mealsFetchLatestImage './modules/fetch-container-image.bicep' = {
  name: 'meals-fetch-image'
  params: {
    exists: mealsExists
    name: 'meals'
  }
}

var mealsAppSettingsArray = filter(array(mealsDefinition.settings), i => i.name != '')
var mealsSecrets = map(filter(mealsAppSettingsArray, i => i.?secret != null), i => {
  name: i.name
  value: i.value
  secretRef: i.?secretRef ?? take(replace(replace(toLower(i.name), '_', '-'), '.', '-'), 32)
})
var mealsEnv = map(filter(mealsAppSettingsArray, i => i.?secret == null), i => {
  name: i.name
  value: i.value
})

module meals 'br/public:avm/res/app/container-app:0.8.0' = {
  name: 'meals'
  dependsOn: []
  params: {
    name: 'meals'
    ingressTargetPort: 3000
    scaleMinReplicas: 1
    scaleMaxReplicas: 10
    secrets: {
      secureList: union(
        [
          {
            name: 'openai-api-key'
            value: openAiApiKey
          }
          {
            name: 'openai-kv-api-key'
            keyVaultUrl: '${keyVault.outputs.uri}secrets/openai-api-key'
            identity: mealsIdentity.outputs.resourceId
          }
        ],
        map(mealsSecrets, secret => {
          name: secret.secretRef
          value: secret.value
        })
      )
    }
    containers: [
      {
        image: mealsFetchLatestImage.outputs.?containers[?0].?image ?? 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
        name: 'main'
        resources: {
          cpu: json('0.5')
          memory: '1.0Gi'
        }
        env: union(
          [
            {
              name: 'AZURE_STORAGE_ACCOUNT_NAME'
              value: storageAccount.name
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: monitoring.outputs.applicationInsightsConnectionString
            }
            {
              name: 'AZURE_CLIENT_ID'
              value: mealsIdentity.outputs.clientId
            }
            {
              name: 'PORT'
              value: '3000'
            }
            {
              name: 'NODE_ENV'
              value: 'production'
            }
            {
              name: 'OPENAI_API_KEY'
              secretRef: 'openai-api-key'
            }
            // {
            //   name: 'OPENAI_KV_API_KEY'
            //   secretRef: 'openai-kv-api-key'
            // }
          ],
          mealsEnv,
          map(mealsSecrets, secret => {
            name: secret.name
            secretRef: secret.secretRef
          })
        )
      }
    ]
    managedIdentities: {
      systemAssigned: false
      userAssignedResourceIds: [mealsIdentity.outputs.resourceId]
    }
    registries: [
      {
        server: containerRegistry.outputs.loginServer
        identity: mealsIdentity.outputs.resourceId
      }
    ]
    environmentResourceId: containerAppsEnvironment.outputs.resourceId
    location: location
    tags: union(tags, { 'azd-service-name': 'meals' })
  }
}

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.outputs.loginServer
output AZURE_KEY_VAULT_ENDPOINT string = keyVault.outputs.uri
output AZURE_KEY_VAULT_NAME string = keyVault.outputs.name
output AZURE_RESOURCE_MEALS_ID string = meals.outputs.resourceId
