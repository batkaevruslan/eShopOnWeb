terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.26.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = false
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

locals {
  servicePlanSku                    = var.createDeploymentSlots ? "P0v3" : "S1"
  CatalogDbConnectionString         = "Data Source=${module.databases.cloudXSqlServer.fully_qualified_domain_name},1433;Initial Catalog=${module.databases.eShopOnWebCatalogDb.name};Authentication=ActiveDirectoryManagedIdentity"
  IdentityDbConnectionString        = "Data Source=${module.databases.cloudXSqlServer.fully_qualified_domain_name},1433;Initial Catalog=${module.databases.eShopOnWebIdentityDb.name};Authentication=ActiveDirectoryManagedIdentity"
  ServiceBusFullyQualifiedNamespace = "${azurerm_servicebus_namespace.cloudXServiceBus.name}.servicebus.windows.net"
}

data "azuread_user" "ruslanBatkaevUser" {
  user_principal_name = "ruslan_batkaev@epam.com"
}

resource "azurerm_resource_group" "cloudXResourceGroup" {
  name     = "CloudXResourceGroup"
  location = var.main_location
}

### Service plans ###
resource "azurerm_service_plan" "cloudXPlanMainRegion" {
  os_type             = "Linux"
  name                = "CloudXServicePlanMain"
  resource_group_name = azurerm_resource_group.cloudXResourceGroup.name
  location            = var.main_location
  sku_name            = local.servicePlanSku
}

resource "azurerm_monitor_autoscale_setting" "cloudXPlanMainRegionAutoscaling" {
  name                = "cloudXPlanMainRegionAutoscalingSetting"
  resource_group_name = azurerm_resource_group.cloudXResourceGroup.name
  location            = azurerm_resource_group.cloudXResourceGroup.location
  target_resource_id  = azurerm_service_plan.cloudXPlanMainRegion.id
  profile {
    name = "default"
    capacity {
      default = 1
      minimum = 1
      maximum = 2
    }
    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.cloudXPlanMainRegion.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 30
      }
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.cloudXPlanMainRegion.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 5
      }
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }
}

resource "azurerm_service_plan" "cloudXPlanSecondRegion" {
  os_type             = "Linux"
  name                = "CloudXServicePlanSecond"
  resource_group_name = azurerm_resource_group.cloudXResourceGroup.name
  location            = var.second_location
  sku_name            = local.servicePlanSku
}

### Apps ###
resource "azurerm_linux_web_app" "publicApi" {
  name                = "eShopPublicApi-d13jf"
  resource_group_name = azurerm_resource_group.cloudXResourceGroup.name
  location            = var.main_location
  service_plan_id     = azurerm_service_plan.cloudXPlanMainRegion.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    container_registry_use_managed_identity = true

    application_stack {
      docker_image_name   = "eshoppublicapi:latest"
      docker_registry_url = "https://${azurerm_container_registry.cloudXContainerRegistry.login_server}"
    }
    always_on         = true
    use_32_bit_worker = true
    cors {
      allowed_origins = var.createDeploymentSlots ? [
        "https://${azurerm_linux_web_app.eShopWeb1.default_hostname}",
        "https://${azurerm_linux_web_app.eShopWeb2.default_hostname}",
        "https://${azurerm_linux_web_app_slot.eShopWeb2StagingSlot[0].default_hostname}",
        "https://${azurerm_traffic_manager_profile.eShopWebTrafficManager.fqdn}"
        ] : [
        "https://${azurerm_linux_web_app.eShopWeb1.default_hostname}",
        "https://${azurerm_linux_web_app.eShopWeb2.default_hostname}",
        "https://${azurerm_traffic_manager_profile.eShopWebTrafficManager.fqdn}"
      ]
    }
  }

  app_settings = {
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.cloudXApplicationInsights.connection_string
    VaultUri                              = module.CloudXKeyVault.data.vault_uri
    ServiceBusNamespace                   = local.ServiceBusFullyQualifiedNamespace
    DOCKER_ENABLE_CI                      = true
    WEBSITES_PORT                         = "8080"
  }
}

resource "azurerm_linux_web_app" "eShopWeb1" {
  name                = "eShopWeb1"
  resource_group_name = azurerm_resource_group.cloudXResourceGroup.name
  location            = var.main_location
  service_plan_id     = azurerm_service_plan.cloudXPlanMainRegion.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    container_registry_use_managed_identity = true

    application_stack {
      docker_image_name   = "eshopwebmvc:latest"
      docker_registry_url = "https://${azurerm_container_registry.cloudXContainerRegistry.login_server}"
    }
    always_on         = true
    use_32_bit_worker = true
  }

  app_settings = {
    ASPNETCORE_ENVIRONMENT    = "Production"
    OrderItemReserverUri      = "https://${azurerm_linux_function_app.orderItemsReserverFunctionApp.default_hostname}/api/ReserveItemFunction"
    DeliveryOrderProcessorUri = "https://${azurerm_linux_function_app.DeliveryOrderProcessorFunctionApp.default_hostname}/api/PrepareOrderForDelivery"
    VaultUri                  = module.CloudXKeyVault.data.vault_uri
    ServiceBusNamespace       = local.ServiceBusFullyQualifiedNamespace
    DOCKER_ENABLE_CI          = true
    WEBSITES_PORT             = "8080"
  }
}

resource "azurerm_linux_web_app" "eShopWeb2" {
  name                = "eShopWeb2"
  resource_group_name = azurerm_resource_group.cloudXResourceGroup.name
  location            = var.second_location
  service_plan_id     = azurerm_service_plan.cloudXPlanSecondRegion.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      dotnet_version = var.app_service_dotnet_framework_version
    }
    always_on         = true
    use_32_bit_worker = true
  }
  app_settings = {
    ASPNETCORE_ENVIRONMENT    = "Production"
    OrderItemReserverUri      = "https://${azurerm_linux_function_app.orderItemsReserverFunctionApp.default_hostname}/api/ReserveItemFunction"
    DeliveryOrderProcessorUri = "https://${azurerm_linux_function_app.DeliveryOrderProcessorFunctionApp.default_hostname}/api/PrepareOrderForDelivery"
    VaultUri                  = module.CloudXKeyVault.data.vault_uri
    ServiceBusNamespace       = local.ServiceBusFullyQualifiedNamespace
  }
}

resource "azurerm_linux_web_app_slot" "eShopWeb2StagingSlot" {
  count          = var.createDeploymentSlots ? 1 : 0
  name           = "staging"
  app_service_id = azurerm_linux_web_app.eShopWeb2.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      dotnet_version = var.app_service_dotnet_framework_version
    }
    always_on         = true
    use_32_bit_worker = true
  }

  app_settings = {
    ASPNETCORE_ENVIRONMENT    = "Production"
    OrderItemReserverUri      = "https://${azurerm_linux_function_app.orderItemsReserverFunctionApp.default_hostname}/api/ReserveItemFunction"
    DeliveryOrderProcessorUri = "https://${azurerm_linux_function_app.DeliveryOrderProcessorFunctionApp.default_hostname}/api/PrepareOrderForDelivery"
    VaultUri                  = module.CloudXKeyVault.data.vault_uri
    ServiceBusNamespace       = local.ServiceBusFullyQualifiedNamespace
  }
}

resource "azurerm_traffic_manager_profile" "eShopWebTrafficManager" {
  name                   = "eShopWebTrafficManager"
  resource_group_name    = azurerm_resource_group.cloudXResourceGroup.name
  traffic_routing_method = "Performance"

  dns_config {
    relative_name = "eshopwebtrafficmanager"
    ttl           = 100
  }

  monitor_config {
    protocol                     = "HTTP"
    port                         = 80
    path                         = "/"
    interval_in_seconds          = 30
    timeout_in_seconds           = 9
    tolerated_number_of_failures = 3
  }
}

resource "azurerm_traffic_manager_azure_endpoint" "eShopWeb1TrafficManagerEndpoint" {
  name               = "eShopWeb1TrafficManagerEndpoint"
  profile_id         = azurerm_traffic_manager_profile.eShopWebTrafficManager.id
  weight             = 50
  target_resource_id = azurerm_linux_web_app.eShopWeb1.id
}

resource "azurerm_traffic_manager_azure_endpoint" "eShopWeb2TrafficManagerEndpoint" {
  name               = "eShopWeb2TrafficManagerEndpoint"
  profile_id         = azurerm_traffic_manager_profile.eShopWebTrafficManager.id
  weight             = 50
  target_resource_id = azurerm_linux_web_app.eShopWeb2.id
}

### Application Insights
resource "azurerm_log_analytics_workspace" "cloudXApplicationInsightsWorkspace" {
  name                = "cloudXApplicationInsightsWorkspace"
  location            = var.main_location
  resource_group_name = azurerm_resource_group.cloudXResourceGroup.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_application_insights" "cloudXApplicationInsights" {
  name                = "CloudXApplicationInsights"
  resource_group_name = azurerm_resource_group.cloudXResourceGroup.name
  location            = var.main_location
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.cloudXApplicationInsightsWorkspace.id
}

### Storage

resource "azurerm_storage_account" "cloudXStorageAccount" {
  name                     = "cloudxstorageaccount"
  resource_group_name      = azurerm_resource_group.cloudXResourceGroup.name
  location                 = var.main_location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_role_assignment" "blobStorageContibutorToRBAssignment" {
  scope                = azurerm_storage_account.cloudXStorageAccount.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azuread_user.ruslanBatkaevUser.object_id
}

### Functions
resource "azurerm_role_assignment" "blobStorageContibutorToOrderItemsReserverFunctionAppAssignment" {
  scope                = azurerm_storage_account.cloudXStorageAccount.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_function_app.orderItemsReserverFunctionApp.identity[0].principal_id
}

resource "azurerm_linux_function_app" "orderItemsReserverFunctionApp" {
  name                       = "orderItemsReserverFunctionApp"
  resource_group_name        = azurerm_resource_group.cloudXResourceGroup.name
  location                   = var.main_location
  service_plan_id            = azurerm_service_plan.cloudXPlanMainRegion.id
  storage_account_access_key = azurerm_storage_account.cloudXStorageAccount.primary_access_key
  storage_account_name       = azurerm_storage_account.cloudXStorageAccount.name

  site_config {
    always_on = true
    application_stack {
      dotnet_version              = var.app_service_dotnet_framework_version
      use_dotnet_isolated_runtime = true
    }
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    AzureStorageConfig__ServiceUri                            = "https://${azurerm_storage_account.cloudXStorageAccount.primary_blob_host}",
    AzureStorageConfig__FileContainerName                     = "cloud-x-azure-hosted"
    WEBSITE_USE_PLACEHOLDER_DOTNETISOLATED                    = 1
    WEBSITE_RUN_FROM_PACKAGE                                  = 1
    FUNCTIONS_WORKER_RUNTIME                                  = "dotnet-isolated"
    APPLICATIONINSIGHTS_CONNECTION_STRING                     = azurerm_application_insights.cloudXApplicationInsights.connection_string
    CloudXServiceBusConnectionString__fullyQualifiedNamespace = "${azurerm_servicebus_namespace.cloudXServiceBus.name}.servicebus.windows.net"
  }
}

resource "azurerm_linux_function_app" "DeliveryOrderProcessorFunctionApp" {
  name                       = "deliveryOrderProcessorFunctionApp"
  resource_group_name        = azurerm_resource_group.cloudXResourceGroup.name
  location                   = var.main_location
  service_plan_id            = azurerm_service_plan.cloudXPlanMainRegion.id
  storage_account_access_key = azurerm_storage_account.cloudXStorageAccount.primary_access_key
  storage_account_name       = azurerm_storage_account.cloudXStorageAccount.name

  site_config {
    always_on = true
    application_stack {
      dotnet_version              = var.app_service_dotnet_framework_version
      use_dotnet_isolated_runtime = true
    }
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    CosmosDbAccountEndpoint                = azurerm_cosmosdb_account.cosmosDbAccount.endpoint
    WEBSITE_USE_PLACEHOLDER_DOTNETISOLATED = 1
    WEBSITE_RUN_FROM_PACKAGE               = 1
    FUNCTIONS_WORKER_RUNTIME               = "dotnet-isolated"
    APPLICATIONINSIGHTS_CONNECTION_STRING  = azurerm_application_insights.cloudXApplicationInsights.connection_string
  }
}

### Databases
module "databases" {
  source        = "./sql_databases"
  location      = var.main_location
  resourceGroup = azurerm_resource_group.cloudXResourceGroup.name
  adminUser     = data.azuread_user.ruslanBatkaevUser
}

# resource "azurerm_app_service_connection" "apiToIdentityDbConnection" {
#   name               = "apiToIdentityDbConnection"
#   app_service_id     = azurerm_linux_web_app.publicApi.id
#   target_resource_id = module.databases.eShopOnWebIdentityDb.id
#   client_type        = "dotnet"
#   authentication {
#     type = "systemAssignedIdentity"
#   }
#   provisioner "local-exec" {
#     command = "az webapp connection create sql --connection ${azurerm_app_service_connection.apiToIdentityDbConnection.name} --source-id ${azurerm_linux_web_app.publicApi.id} --target-id ${module.databases.eShopOnWebIdentityDb.id} --client-type dotnet --system-identity"
#   }
# }

# resource "azurerm_app_service_connection" "apiToCatalogyDbConnection" {
#   name               = "apiToCatalogyDbConnection"
#   app_service_id     = azurerm_linux_web_app.publicApi.id
#   target_resource_id = module.databases.eShopOnWebCatalogDb.id
#   client_type        = "dotnet"
#   authentication {
#     type = "systemAssignedIdentity"
#   }
#   provisioner "local-exec" {
#     command = "az webapp connection create sql --connection ${azurerm_app_service_connection.apiToCatalogyDbConnection.name} --source-id ${azurerm_linux_web_app.publicApi.id} --target-id ${module.databases.eShopOnWebCatalogDb.id} --client-type dotnet --system-identity --customized-keys AZURE_SQL_CONNECTIONSTRING=ConnectionStrings__CatalogConnection"
#   }
# }

resource "azurerm_cosmosdb_account" "cosmosDbAccount" {
  name                = "cloudx-cosmos-db-d13jf"
  location            = var.main_location
  resource_group_name = azurerm_resource_group.cloudXResourceGroup.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  free_tier_enabled   = true

  consistency_policy {
    consistency_level       = "BoundedStaleness"
    max_interval_in_seconds = 300
    max_staleness_prefix    = 100000
  }

  geo_location {
    location          = var.main_location
    failover_priority = 0
  }
}

resource "azurerm_cosmosdb_sql_database" "DeliveryDb" {
  name                = "DeliveryDb"
  resource_group_name = azurerm_resource_group.cloudXResourceGroup.name
  account_name        = azurerm_cosmosdb_account.cosmosDbAccount.name
}

resource "azurerm_cosmosdb_sql_container" "DeliveryDbOrdersContainer" {
  name                = "Orders"
  resource_group_name = azurerm_cosmosdb_account.cosmosDbAccount.resource_group_name
  account_name        = azurerm_cosmosdb_account.cosmosDbAccount.name
  database_name       = azurerm_cosmosdb_sql_database.DeliveryDb.name
  partition_key_paths = ["/shippingAddress/country"]
}

resource "azurerm_cosmosdb_sql_role_definition" "cosmosdb_readwrite_role" {
  name                = "CosmosDBReadWriteRole"
  resource_group_name = azurerm_resource_group.cloudXResourceGroup.name
  account_name        = azurerm_cosmosdb_account.cosmosDbAccount.name
  type                = "CustomRole"
  assignable_scopes   = [azurerm_cosmosdb_account.cosmosDbAccount.id]
  permissions {
    data_actions = [
      "Microsoft.DocumentDB/databaseAccounts/readMetadata",
      "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/*",
      "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/*"
    ]
  }
}

resource "azurerm_cosmosdb_sql_role_assignment" "CosmosDBReadWriteRoleToMyUserAssignment" {
  resource_group_name = azurerm_resource_group.cloudXResourceGroup.name
  account_name        = azurerm_cosmosdb_account.cosmosDbAccount.name
  role_definition_id  = azurerm_cosmosdb_sql_role_definition.cosmosdb_readwrite_role.id
  principal_id        = data.azuread_user.ruslanBatkaevUser.object_id
  scope               = azurerm_cosmosdb_account.cosmosDbAccount.id
}

resource "azurerm_cosmosdb_sql_role_assignment" "CosmosDBReadWriteRoleToDeliveryOrderProcessorFunctionApp" {
  resource_group_name = azurerm_resource_group.cloudXResourceGroup.name
  account_name        = azurerm_cosmosdb_account.cosmosDbAccount.name
  role_definition_id  = azurerm_cosmosdb_sql_role_definition.cosmosdb_readwrite_role.id
  principal_id        = azurerm_linux_function_app.DeliveryOrderProcessorFunctionApp.identity[0].principal_id
  scope               = azurerm_cosmosdb_account.cosmosDbAccount.id
}

### Key Vault
data "azurerm_client_config" "current" {}

module "CloudXKeyVault" {
  source                     = "./key_vault"
  resourceGroup              = azurerm_resource_group.cloudXResourceGroup.name
  location                   = var.main_location
  catalogDbConnectionString  = local.CatalogDbConnectionString
  identityDbConnectionString = local.IdentityDbConnectionString
  tenantId                   = data.azurerm_client_config.current.tenant_id
  currentUserId              = data.azuread_user.ruslanBatkaevUser.object_id
}

resource "azurerm_role_assignment" "eShopWeb1KeyVaultReaderAccessPolicy" {
  scope                = module.CloudXKeyVault.data.id
  role_definition_name = "Key Vault Reader"
  principal_id         = azurerm_linux_web_app.eShopWeb1.identity[0].principal_id
}

resource "azurerm_role_assignment" "eShopWeb1KeyVaultSecretsUserAccessPolicy" {
  scope                = module.CloudXKeyVault.data.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.eShopWeb1.identity[0].principal_id
}

resource "azurerm_role_assignment" "eShopWeb2KeyVaultReaderAccessPolicy" {
  scope                = module.CloudXKeyVault.data.id
  role_definition_name = "Key Vault Reader"
  principal_id         = azurerm_linux_web_app.eShopWeb2.identity[0].principal_id
}

resource "azurerm_role_assignment" "eShopWeb2KeyVaultSecretsUserAccessPolicy" {
  scope                = module.CloudXKeyVault.data.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.eShopWeb2.identity[0].principal_id
}

resource "azurerm_role_assignment" "eShopWeb2StagingSlotKeyVaultReaderAccessPolicy" {
  count                = var.createDeploymentSlots ? 1 : 0
  scope                = module.CloudXKeyVault.data.id
  role_definition_name = "Key Vault Reader"
  principal_id         = azurerm_linux_web_app_slot.eShopWeb2StagingSlot[0].identity[0].principal_id
}

resource "azurerm_role_assignment" "eShopWeb2StagingSlotKeyVaultSecretsUserAccessPolicy" {
  count                = var.createDeploymentSlots ? 1 : 0
  scope                = module.CloudXKeyVault.data.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app_slot.eShopWeb2StagingSlot[0].identity[0].principal_id
}

resource "azurerm_role_assignment" "publicApiKeyVaultReaderAccessPolicy" {
  scope                = module.CloudXKeyVault.data.id
  role_definition_name = "Key Vault Reader"
  principal_id         = azurerm_linux_web_app.publicApi.identity[0].principal_id
}

resource "azurerm_role_assignment" "publicApiKeyVaultSecretsUserAccessPolicy" {
  scope                = module.CloudXKeyVault.data.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.publicApi.identity[0].principal_id
}

### Service bus ###
resource "azurerm_servicebus_namespace" "cloudXServiceBus" {
  resource_group_name = azurerm_resource_group.cloudXResourceGroup.name
  location            = var.main_location
  sku                 = "Basic"
  name                = "cloudXServiceBus"
}

resource "azurerm_servicebus_queue" "cloudXServiceBusOrderReservationQueue" {
  name         = "order-reservation"
  namespace_id = azurerm_servicebus_namespace.cloudXServiceBus.id
}

resource "azurerm_role_assignment" "eShopOnWeb1ServiceBusAccessPolicy" {
  scope                = azurerm_servicebus_namespace.cloudXServiceBus.id
  role_definition_name = "Azure Service Bus Data Owner"
  principal_id         = azurerm_linux_web_app.eShopWeb1.identity[0].principal_id
}

resource "azurerm_role_assignment" "eShopOnWeb2ServiceBusAccessPolicy" {
  scope                = azurerm_servicebus_namespace.cloudXServiceBus.id
  role_definition_name = "Azure Service Bus Data Owner"
  principal_id         = azurerm_linux_web_app.eShopWeb2.identity[0].principal_id
}

resource "azurerm_role_assignment" "eShopOnWeb2StagingServiceBusAccessPolicy" {
  count                = var.createDeploymentSlots ? 1 : 0
  scope                = azurerm_servicebus_namespace.cloudXServiceBus.id
  role_definition_name = "Azure Service Bus Data Owner"
  principal_id         = azurerm_linux_web_app_slot.eShopWeb2StagingSlot[0].identity[0].principal_id
}

resource "azurerm_role_assignment" "currentUserServiceBusAccessPolicy" {
  scope                = azurerm_servicebus_namespace.cloudXServiceBus.id
  role_definition_name = "Azure Service Bus Data Owner"
  principal_id         = data.azuread_user.ruslanBatkaevUser.object_id
}

resource "azurerm_role_assignment" "orderItemsReserverFunctionAppServiceBusAccessPolicy" {
  scope                = azurerm_servicebus_namespace.cloudXServiceBus.id
  role_definition_name = "Azure Service Bus Data Owner"
  principal_id         = azurerm_linux_function_app.orderItemsReserverFunctionApp.identity[0].principal_id
}


### Logic App ###
resource "azurerm_logic_app_workflow" "cloudXLogicApp" {
  name                = "cloudXLogicApp"
  location            = var.main_location
  resource_group_name = azurerm_resource_group.cloudXResourceGroup.name

  identity {
    type = "SystemAssigned"
  }
}

data "azurerm_managed_api" "example" {
  name     = "servicebus"
  location = var.main_location
}

resource "azurerm_api_connection" "cloudXLogicAppToServiceBusConnection" {
  name                = "logicAppToServiceBusConnection"
  resource_group_name = azurerm_resource_group.cloudXResourceGroup.name
  managed_api_id      = data.azurerm_managed_api.example.id

  parameter_values = {
    connectionString = azurerm_servicebus_namespace.cloudXServiceBus.default_primary_connection_string
  }

  lifecycle {
    ignore_changes = [parameter_values]
  }
}

### Azure Container Registry ###
resource "azurerm_container_registry" "cloudXContainerRegistry" {
  name                = "cloudXContainerRegistry"
  resource_group_name = azurerm_resource_group.cloudXResourceGroup.name
  location            = var.main_location
  sku                 = "Basic"
  admin_enabled       = true
}

resource "azurerm_role_assignment" "eShopOnWeb1ContainerRegistryAccessPolicy" {
  scope                = azurerm_container_registry.cloudXContainerRegistry.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_web_app.eShopWeb1.identity[0].principal_id
}

resource "azurerm_container_registry_webhook" "eShopOnWeb1ConainerWebhook" {
  name                = "eShopOnWeb1ConainerWebhook"
  resource_group_name = azurerm_resource_group.cloudXResourceGroup.name
  registry_name       = azurerm_container_registry.cloudXContainerRegistry.name
  location            = var.main_location
  service_uri         = "https://${azurerm_linux_web_app.eShopWeb1.site_credential[0].name}:${azurerm_linux_web_app.eShopWeb1.site_credential[0].password}@${azurerm_linux_web_app.eShopWeb1.name}.scm.azurewebsites.net/api/registry/webhook"
  status              = "enabled"
  actions             = ["push"]
  scope               = "eshopwebmvc"
}

resource "azurerm_role_assignment" "publicApiContainerRegistryAccessPolicy" {
  scope                = azurerm_container_registry.cloudXContainerRegistry.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_web_app.publicApi.identity[0].principal_id
}

# we need to change SKU from "Basic" in order to not exceed webhooks quota
# resource "azurerm_container_registry_webhook" "publicApiConainerWebhook" {
#   name                = "publicApiConainerWebhook"
#   resource_group_name = azurerm_resource_group.rg.name
#   registry_name       = azurerm_container_registry.cloudXContainerRegistry.name
#   location            = var.main_location
#   service_uri         = "https://${azurerm_linux_web_app.publicApi.site_credential[0].name}:${azurerm_linux_web_app.publicApi.site_credential[0].password}@${azurerm_linux_web_app.publicApi.name}.scm.azurewebsites.net/api/registry/webhook"
#   status              = "enabled"
#   actions             = ["push"]
#   scope               = "eshoppublicapi"
# }
