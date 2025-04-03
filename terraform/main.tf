terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.25.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

locals {
  servicePlanSku = var.createDeploymentSlots ? "P0v3" : "S1"
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

  site_config {
    application_stack {
      dotnet_version = var.app_service_dotnet_framework_version
    }
    always_on         = true
    use_32_bit_worker = true
    cors {
      allowed_origins = [
        "https://${azurerm_linux_web_app.eShopWeb1.default_hostname}",
        "https://${azurerm_linux_web_app.eShopWeb2.default_hostname}",
        "https://${azurerm_linux_web_app_slot.eShopWeb2StagingSlot.default_hostname}",
        "https://${azurerm_traffic_manager_profile.eShopWebTrafficManager.fqdn}"
      ]
    }
  }

  app_settings = {
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.cloudXApplicationInsights.connection_string
  }
}

resource "azurerm_linux_web_app" "eShopWeb1" {
  name                = "eShopWeb1"
  resource_group_name = azurerm_resource_group.cloudXResourceGroup.name
  location            = var.main_location
  service_plan_id     = azurerm_service_plan.cloudXPlanMainRegion.id

  site_config {
    application_stack {
      dotnet_version = var.app_service_dotnet_framework_version
    }
    always_on         = true
    use_32_bit_worker = true
  }

  app_settings = {
    ASPNETCORE_ENVIRONMENT = "Production"
    OrderItemReserverUri   = "https://${azurerm_linux_function_app.orderItemsReserverFunctionApp.default_hostname}/api/ReserveItemFunction"
  }
}

resource "azurerm_linux_web_app" "eShopWeb2" {
  name                = "eShopWeb2"
  resource_group_name = azurerm_resource_group.cloudXResourceGroup.name
  location            = var.second_location
  service_plan_id     = azurerm_service_plan.cloudXPlanSecondRegion.id

  site_config {
    application_stack {
      dotnet_version = var.app_service_dotnet_framework_version
    }
    always_on         = true
    use_32_bit_worker = true
  }
  app_settings = {
    ASPNETCORE_ENVIRONMENT = "Production"
    OrderItemReserverUri   = "https://${azurerm_linux_function_app.orderItemsReserverFunctionApp.default_hostname}/api/ReserveItemFunction"
  }
}

resource "azurerm_linux_web_app_slot" "eShopWeb2StagingSlot" {
  name           = "staging"
  app_service_id = azurerm_linux_web_app.eShopWeb2.id

  site_config {
    application_stack {
      dotnet_version = var.app_service_dotnet_framework_version
    }
    always_on         = true
    use_32_bit_worker = true
  }

  app_settings = {
    ASPNETCORE_ENVIRONMENT = "Production"
    OrderItemReserverUri   = "https://${azurerm_linux_function_app.orderItemsReserverFunctionApp.default_hostname}/api/ReserveItemFunction"
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
  name                = "example"
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
  }
}
