param env string
param region string
param acrName string
param appVersion string
param appName string = 'app2003'
param location string = resourceGroup().location
param umiName string

var webAppName = '${env}-${region}-webapp'
var aspName = '${env}-${region}-asp'

resource umi 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' existing = {
  scope: resourceGroup('RG1')
  name: umiName
}

resource asp 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: aspName
  location: location
  properties: {
    reserved: true
  }
  sku: {
    name: 'S1'
    tier: 'Standard'
    size: 'S1'
    family: 'S'
    capacity: 1
  }
  kind: 'linux'
}

resource webapp 'Microsoft.Web/sites@2023-01-01' = {
  name: webAppName
  location: location
  kind: 'linux'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${umi.id}': {}
    }
  }
  properties: {
    enabled: true
    reserved: true
    serverFarmId: asp.id
    publicNetworkAccess: 'Enabled'
    siteConfig: {
      acrUseManagedIdentityCreds: true
      acrUserManagedIdentityID: umi.properties.clientId // not the resource id!
      numberOfWorkers: 1
      linuxFxVersion: 'DOCKER|${acrName}.azurecr.io/${appName}:${appVersion}'
      healthCheckPath: '/'
      alwaysOn: true
    }
  }
}

resource target_appservice 'Microsoft.Chaos/targets@2024-01-01' = {
  scope: webapp
  name: 'microsoft-appservice'
  location: location
  properties: {}
  dependsOn: []
}

resource microsoft_appservice_Stop_1_0 'Microsoft.Chaos/targets/capabilities@2024-01-01' = {
  parent: target_appservice
  name: 'Stop-1.0'
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, umi.name, 'Website Contributor')
  scope: webapp
  properties: {
    principalType: 'ServicePrincipal'
    principalId: umi.properties.principalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'de139f84-1756-47ae-9be6-808fbbe84772')
  }
}
