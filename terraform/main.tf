terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.22"
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
  servicePlanSku = var.createDeploymentSlots ? "P0v3" : "B1"
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
