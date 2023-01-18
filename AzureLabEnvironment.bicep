@description('Suffix added to all resource names to make them unique.')
param uniqueSuffix string

@description('The workload that this resource/resource group will be handling')
param workload string

@description('The type of environment that this resource/resource group will be. eg. train, dev, prod')
param environment string

@description('The Azure region that this resource/resource group will be deployed in to')
param region string

@description('The email address of the owner of the API Management service')
@minLength(1)
param publisherEmail string

@description('The name of the owner of the API Management service')
@minLength(1)
param publisherName string

param location string = resourceGroup().location
param cosmosDbAccountName string = 'cosmos-${workload}-${environment}-${uniqueSuffix}'
param cosmosDbName string = 'HealthCheckDB'
param cosmosContainerName string = 'HealthCheck'
param apiManagementServiceName string = 'apim-${workload}-${environment}-${uniqueSuffix}'
param hostingPlanName string = 'plan-${workload}-${environment}-${region}-${uniqueSuffix}'
param appServiceAccountName string = 'app-${workload}-${environment}-${region}-${uniqueSuffix}'

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2022-08-15' = {
  kind: 'GlobalDocumentDB'
  name: cosmosDbAccountName
  location: location
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        // id: '${cosmosDbAccountName}-${location}'
        failoverPriority: 0
        locationName: location
      }
    ]
    backupPolicy: {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: 240
        backupRetentionIntervalInHours: 8
        backupStorageRedundancy: 'Geo'
      }
    }
    isVirtualNetworkFilterEnabled: false
    virtualNetworkRules: []
    ipRules: []
    enableMultipleWriteLocations: false
    capabilities: []
    enableFreeTier: false
  }
  tags: {
    defaultExperience: 'Core (SQL)'
    'hidden-cosmos-mmspecial': ''
  }
}

resource cosmosDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2022-08-15' = {
  name: '${cosmosDbAccount.name}/${cosmosDbName}'
  properties: {
    resource: {
      id: cosmosDbName
    }
  }
}

resource cosmosDatabaseContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2022-08-15' = {
  name: '${cosmosDatabase.name}/${cosmosContainerName}'
  properties: {
    resource: {
      id: cosmosContainerName
      partitionKey: {
        paths: [
          '/id'
        ]
        kind: 'Hash'
      }
    }
    options: {
      throughput: 400
    }
  }
}

resource hostingPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: hostingPlanName
  location: location
  properties: {
    targetWorkerSizeId: 0
    targetWorkerCount: 1
  }
  sku: {
    tier: 'Standard'
    name: 'S1'
  }
}

resource appServiceAccount 'Microsoft.Web/sites@2022-03-01' = {
  name: appServiceAccountName
  location: location
  properties: {
    siteConfig: {
      appSettings: []
      metadata: [
        {
          name: 'CURRENT_STACK'
          value: 'dotnet'
        }
      ]
      phpVersion: 'OFF'
      netFrameworkVersion: 'v5.0'
      alwaysOn: true
    }
    serverFarmId: hostingPlan.id
    clientAffinityEnabled: true
  }
}

resource apiManagementService 'Microsoft.ApiManagement/service@2022-04-01-preview' = {
  name: apiManagementServiceName
  location: location
  sku: {
    name: 'Consumption'
    capacity: 0
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}
