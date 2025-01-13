param location string = resourceGroup().location

param mealsIdentityName string

var abbrs = loadJsonContent('../abbreviations.json')
var resourceToken = uniqueString(subscription().id, resourceGroup().id, location)
var kvName = '${abbrs.keyVaultVaults}${resourceToken}'

resource keyVaultRef 'Microsoft.KeyVault/vaults@2019-09-01' existing = {
  name: kvName
}

resource mealsIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' existing = {
  name: mealsIdentityName
}

// Assign kv secret reader role to managed identity
resource keyVaultRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, 'mealsidentity','keyvault-secret-reader')
  scope: keyVaultRef
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') 
    principalId: mealsIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
  ]
}
