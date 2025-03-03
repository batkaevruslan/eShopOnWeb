# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.21.1"
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

resource "random_id" "rng" {
  keepers = {
  }
  byte_length = 8
}

locals {
  CatalogDbConnectionString         = "Data Source=${module.databases.cloudXSqlServer.fully_qualified_domain_name},1433;Initial Catalog=${module.databases.eShopOnWebCatalogDb.name};Authentication=ActiveDirectoryManagedIdentity"
  IdentityDbConnectionString        = "Data Source=${module.databases.cloudXSqlServer.fully_qualified_domain_name},1433;Initial Catalog=${module.databases.eShopOnWebIdentityDb.name};Authentication=ActiveDirectoryManagedIdentity"
  ServiceBusFullyQualifiedNamespace = "${azurerm_servicebus_namespace.cloudXServiceBus.name}.servicebus.windows.net"
}

resource "azurerm_resource_group" "rg" {
  name     = "CloudXResourceGroup"
  location = var.main_location
}

resource "azurerm_service_plan" "cloudXPlanMainRegion" {
  os_type             = "Windows"
  name                = "CloudXServicePlanMain"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.main_location
  sku_name            = var.app_service_plan_sku

}

resource "azurerm_monitor_autoscale_setting" "cloudXPlanMainRegionAutoscaling" {
  name                = "cloudXPlanMainRegionAutoscalingSetting"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
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

resource "azurerm_windows_web_app" "publicApi" {
  name                = "eShopPublicApi-d13jf"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.main_location
  service_plan_id     = azurerm_service_plan.cloudXPlanMainRegion.id

  site_config {
    application_stack {
      current_stack  = "dotnet"
      dotnet_version = var.app_service_dotnet_framework_version
    }
    always_on = false
    #use_32_bit_worker = false
    cors {
      allowed_origins = [
        "https://${azurerm_windows_web_app.eShopWeb1.default_hostname}",
        "https://${azurerm_windows_web_app.eShopWeb2.default_hostname}",
        "https://${azurerm_windows_web_app_slot.eShopWeb2StagingSlot.default_hostname}",
        "https://${azurerm_traffic_manager_profile.eShopWebTrafficManager.fqdn}"
      ]
    }
    
    virtual_application {
      physical_path = "site\\wwwroot"
      preload       = false
      virtual_path  = "/"
  }
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.cloudXApplicationInsights.connection_string
    VaultUri                              = module.CloudXKeyVault.data.vault_uri
  }
}

resource "azurerm_windows_web_app" "eShopWeb1" {
  name                = "eShopWeb1"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.main_location
  service_plan_id     = azurerm_service_plan.cloudXPlanMainRegion.id

  site_config {
    application_stack {
      current_stack  = "dotnet"
      dotnet_version = var.app_service_dotnet_framework_version
    }
    always_on = false
    
    virtual_application {
      physical_path = "site\\wwwroot"
      preload       = false
      virtual_path  = "/"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    OrderItemReserverUri      = "https://${azurerm_windows_function_app.orderItemsReserverFunctionApp.default_hostname}/api/ReserveItemFunction"
    DeliveryOrderProcessorUri = "https://${azurerm_windows_function_app.DeliveryOrderProcessorFunctionApp.default_hostname}/api/PrepareOrderForDelivery"
    VaultUri                  = module.CloudXKeyVault.data.vault_uri
    ServiceBusNamespace       = local.ServiceBusFullyQualifiedNamespace
  }
}

resource "azurerm_service_plan" "cloudXPlanSecondRegion" {
  os_type             = "Windows"
  name                = "CloudXServicePlanSecond"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.second_location
  sku_name            = var.app_service_plan_sku
}

resource "azurerm_windows_web_app" "eShopWeb2" {
  name                = "eShopWeb2"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.second_location
  service_plan_id     = azurerm_service_plan.cloudXPlanSecondRegion.id

  site_config {
    application_stack {
      current_stack  = "dotnet"
      dotnet_version = var.app_service_dotnet_framework_version
    }
    always_on = false

    virtual_application {
      physical_path = "site\\wwwroot"
      preload       = false
      virtual_path  = "/"
    }
  }
  
  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    OrderItemReserverUri      = "https://${azurerm_windows_function_app.orderItemsReserverFunctionApp.default_hostname}/api/ReserveItemFunction"
    DeliveryOrderProcessorUri = "https://${azurerm_windows_function_app.DeliveryOrderProcessorFunctionApp.default_hostname}/api/PrepareOrderForDelivery"
    VaultUri                  = module.CloudXKeyVault.data.vault_uri
    ServiceBusNamespace       = local.ServiceBusFullyQualifiedNamespace
  }
}

resource "azurerm_windows_web_app_slot" "eShopWeb2StagingSlot" {
  name           = "staging"
  app_service_id = azurerm_windows_web_app.eShopWeb2.id

  site_config {}

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    OrderItemReserverUri      = "https://${azurerm_windows_function_app.orderItemsReserverFunctionApp.default_hostname}/api/ReserveItemFunction"
    DeliveryOrderProcessorUri = "https://${azurerm_windows_function_app.DeliveryOrderProcessorFunctionApp.default_hostname}/api/PrepareOrderForDelivery"
    VaultUri                  = module.CloudXKeyVault.data.vault_uri
    ServiceBusNamespace       = local.ServiceBusFullyQualifiedNamespace
  }
}

resource "azurerm_traffic_manager_profile" "eShopWebTrafficManager" {
  name                   = "eShopWebTrafficManager"
  resource_group_name    = azurerm_resource_group.rg.name
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
  target_resource_id = azurerm_windows_web_app.eShopWeb1.id
}

resource "azurerm_traffic_manager_azure_endpoint" "eShopWeb2TrafficManagerEndpoint" {
  name               = "eShopWeb2TrafficManagerEndpoint"
  profile_id         = azurerm_traffic_manager_profile.eShopWebTrafficManager.id
  weight             = 50
  target_resource_id = azurerm_windows_web_app.eShopWeb2.id
}

resource "azurerm_application_insights" "cloudXApplicationInsights" {
  name                = "CloudXApplicationInsights"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.main_location
  application_type    = "web"
}

data "azuread_user" "ruslanBatkaevUser" {
  user_principal_name = "ruslan_batkaev@epam.com"
}

resource "azurerm_storage_account" "cloudXStorageAccount" {
  name                     = "cloudxstorageaccount"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.main_location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_role_assignment" "blobStorageContibutorToRBAssignment" {
  scope                = azurerm_storage_account.cloudXStorageAccount.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azuread_user.ruslanBatkaevUser.object_id
}

resource "azurerm_role_assignment" "blobStorageContibutorToOrderItemsReserverFunctionAppAssignment" {
  scope                = azurerm_storage_account.cloudXStorageAccount.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_windows_function_app.orderItemsReserverFunctionApp.identity[0].principal_id
}

resource "azurerm_windows_function_app" "orderItemsReserverFunctionApp" {
  name                       = "orderItemsReserverFunctionApp"
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = var.main_location
  service_plan_id            = azurerm_service_plan.cloudXPlanMainRegion.id
  storage_account_access_key = azurerm_storage_account.cloudXStorageAccount.primary_access_key
  storage_account_name       = azurerm_storage_account.cloudXStorageAccount.name

  site_config {
    #use_32_bit_worker = false
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
    CloudXServiceBusConnectionString__fullyQualifiedNamespace = "${azurerm_servicebus_namespace.cloudXServiceBus.name}.servicebus.windows.net"
    WEBSITE_USE_PLACEHOLDER_DOTNETISOLATED                    = 1
    WEBSITE_RUN_FROM_PACKAGE                                  = 1
    FUNCTIONS_WORKER_RUNTIME                                  = "dotnet-isolated"
    APPLICATIONINSIGHTS_CONNECTION_STRING                     = azurerm_application_insights.cloudXApplicationInsights.connection_string
  }
}

module "databases" {
  source        = "./sql_databases"
  location      = var.main_location
  resourceGroup = azurerm_resource_group.rg.name
  adminUser     = data.azuread_user.ruslanBatkaevUser
}

resource "azurerm_cosmosdb_account" "cosmosDbAccount" {
  name                = "cloudx-cosmos-db-d13jf"
  location            = var.main_location
  resource_group_name = azurerm_resource_group.rg.name
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
  resource_group_name = azurerm_resource_group.rg.name
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
  resource_group_name = azurerm_resource_group.rg.name
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
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmosDbAccount.name
  role_definition_id  = azurerm_cosmosdb_sql_role_definition.cosmosdb_readwrite_role.id
  principal_id        = data.azuread_user.ruslanBatkaevUser.object_id
  scope               = azurerm_cosmosdb_account.cosmosDbAccount.id
}

resource "azurerm_windows_function_app" "DeliveryOrderProcessorFunctionApp" {
  name                       = "deliveryOrderProcessorFunctionApp"
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = var.main_location
  service_plan_id            = azurerm_service_plan.cloudXPlanMainRegion.id
  storage_account_access_key = azurerm_storage_account.cloudXStorageAccount.primary_access_key
  storage_account_name       = azurerm_storage_account.cloudXStorageAccount.name

  site_config {
    #use_32_bit_worker = false
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

resource "azurerm_cosmosdb_sql_role_assignment" "CosmosDBReadWriteRoleToDeliveryOrderProcessorFunctionApp" {
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmosDbAccount.name
  role_definition_id  = azurerm_cosmosdb_sql_role_definition.cosmosdb_readwrite_role.id
  principal_id        = azurerm_windows_function_app.DeliveryOrderProcessorFunctionApp.identity[0].principal_id
  scope               = azurerm_cosmosdb_account.cosmosDbAccount.id
}

data "azurerm_client_config" "current" {}

module "CloudXKeyVault" {
  source                     = "./key_vault"
  resourceGroup              = azurerm_resource_group.rg.name
  location                   = var.main_location
  catalogDbConnectionString  = local.CatalogDbConnectionString
  identityDbConnectionString = local.IdentityDbConnectionString
  tenantId                   = data.azurerm_client_config.current.tenant_id
  currentUserId              = data.azuread_user.ruslanBatkaevUser.object_id
}

resource "azurerm_role_assignment" "eShopWeb1KeyVaultReaderAccessPolicy" {
  scope                = module.CloudXKeyVault.data.id
  role_definition_name = "Key Vault Reader"
  principal_id         = azurerm_windows_web_app.eShopWeb1.identity[0].principal_id
}

resource "azurerm_role_assignment" "eShopWeb1KeyVaultSecretsUserAccessPolicy" {
  scope                = module.CloudXKeyVault.data.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_windows_web_app.eShopWeb1.identity[0].principal_id
}

resource "azurerm_role_assignment" "eShopWeb2KeyVaultReaderAccessPolicy" {
  scope                = module.CloudXKeyVault.data.id
  role_definition_name = "Key Vault Reader"
  principal_id         = azurerm_windows_web_app.eShopWeb2.identity[0].principal_id
}

resource "azurerm_role_assignment" "eShopWeb2KeyVaultSecretsUserAccessPolicy" {
  scope                = module.CloudXKeyVault.data.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_windows_web_app.eShopWeb2.identity[0].principal_id
}

resource "azurerm_role_assignment" "eShopWeb2StagingSlotKeyVaultReaderAccessPolicy" {
  scope                = module.CloudXKeyVault.data.id
  role_definition_name = "Key Vault Reader"
  principal_id         = azurerm_windows_web_app_slot.eShopWeb2StagingSlot.identity[0].principal_id
}

resource "azurerm_role_assignment" "eShopWeb2StagingSlotKeyVaultSecretsUserAccessPolicy" {
  scope                = module.CloudXKeyVault.data.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_windows_web_app_slot.eShopWeb2StagingSlot.identity[0].principal_id
}

resource "azurerm_role_assignment" "publicApiKeyVaultReaderAccessPolicy" {
  scope                = module.CloudXKeyVault.data.id
  role_definition_name = "Key Vault Reader"
  principal_id         = azurerm_windows_web_app.publicApi.identity[0].principal_id
}

resource "azurerm_role_assignment" "publicApiKeyVaultSecretsUserAccessPolicy" {
  scope                = module.CloudXKeyVault.data.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_windows_web_app.publicApi.identity[0].principal_id
}

### Service bus ###
resource "azurerm_servicebus_namespace" "cloudXServiceBus" {
  resource_group_name = azurerm_resource_group.rg.name
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
  principal_id         = azurerm_windows_web_app.eShopWeb1.identity[0].principal_id
}

resource "azurerm_role_assignment" "eShopOnWeb2ServiceBusAccessPolicy" {
  scope                = azurerm_servicebus_namespace.cloudXServiceBus.id
  role_definition_name = "Azure Service Bus Data Owner"
  principal_id         = azurerm_windows_web_app.eShopWeb2.identity[0].principal_id
}

resource "azurerm_role_assignment" "eShopOnWeb2StagingServiceBusAccessPolicy" {
  scope                = azurerm_servicebus_namespace.cloudXServiceBus.id
  role_definition_name = "Azure Service Bus Data Owner"
  principal_id         = azurerm_windows_web_app_slot.eShopWeb2StagingSlot.identity[0].principal_id
}

resource "azurerm_role_assignment" "currentUserServiceBusAccessPolicy" {
  scope                = azurerm_servicebus_namespace.cloudXServiceBus.id
  role_definition_name = "Azure Service Bus Data Owner"
  principal_id         = data.azuread_user.ruslanBatkaevUser.object_id
}

resource "azurerm_role_assignment" "orderItemsReserverFunctionAppServiceBusAccessPolicy" {
  scope                = azurerm_servicebus_namespace.cloudXServiceBus.id
  role_definition_name = "Azure Service Bus Data Owner"
  principal_id         = azurerm_windows_function_app.orderItemsReserverFunctionApp.identity[0].principal_id
}