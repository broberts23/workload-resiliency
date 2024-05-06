param profilesName string = 'dev-webapp-tm'
param webAppNameAUE string
param aue_rg string
param webAppNameSEA string
param sea_rg string
param umiName string
param location string = resourceGroup().location

resource webappAUE 'Microsoft.Web/sites@2023-01-01' existing = {
  scope: resourceGroup(aue_rg)
  name: webAppNameAUE
}

resource webappSEA 'Microsoft.Web/sites@2023-01-01' existing = {
  scope: resourceGroup(sea_rg)
  name: webAppNameSEA
}

resource trafficManagerProfiles 'Microsoft.Network/trafficmanagerprofiles@2022-04-01' = {
  name: profilesName
  location: 'global'
  properties: {
    profileStatus: 'Enabled'
    trafficRoutingMethod: 'Priority'
    dnsConfig: {
      relativeName: profilesName
      ttl: 5
    }
    monitorConfig: {
      protocol: 'HTTPS'
      port: 443
      path: '/'
      intervalInSeconds: 30
      toleratedNumberOfFailures: 3
      timeoutInSeconds: 10
    }
    endpoints: [
      {
        name: '${webAppNameAUE}-endpoint'
        type: 'Microsoft.Network/trafficManagerProfiles/azureEndpoints'
        properties: {
          endpointStatus: 'Enabled'
          endpointMonitorStatus: 'Online'
          targetResourceId: webappAUE.id
          weight: 1
          priority: 1
          endpointLocation: 'Australia East'
          alwaysServe: 'Disabled'
        }
      }
      {
        name: '${webAppNameSEA}-endpoint'
        type: 'Microsoft.Network/trafficManagerProfiles/azureEndpoints'
        properties: {
          endpointStatus: 'Enabled'
          endpointMonitorStatus: 'Online'
          targetResourceId: webappSEA.id
          weight: 1
          priority: 2
          endpointLocation: 'Southeast Asia' // Choas Studio not available in 'Australia SouthEast'
          alwaysServe: 'Disabled'
        }
      }
    ]
    trafficViewEnrollmentStatus: 'Disabled'
  }
}

resource umi 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' existing = {
  name: umiName
}

resource choasStudio 'Microsoft.Chaos/experiments@2024-01-01' = {
  name: 'dev-aue-cs-01'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${umi.id}': {}
    }
  }
  properties: {
    selectors: [
      {
        type: 'List'
        targets: [
          {
            id: extensionResourceId(
              resourceId(aue_rg, 'Microsoft.Web/sites', webAppNameAUE),
              'Microsoft.Chaos/targets',
              'microsoft-appservice'
            )
            type: 'ChaosTarget'
          }
        ]
        id: 'Selector1'
      }
    ]
    steps: [
      {
        name: 'Step 1: Failover an App Service web app'
        branches: [
          {
            name: 'Branch 1: Emulate an App Service failure'
            actions: [
              {
                type: 'continuous'
                selectorId: 'Selector1'
                duration: 'PT10M'
                parameters: []
                name: 'urn:csci:microsoft:appService:stop/1.0'
              }
            ]
          }
        ]
      }
    ]
  }
}
