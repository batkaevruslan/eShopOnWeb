terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.20.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "2.2.0"
    }
  }
}

resource "azurerm_mssql_server" "cloudXServer" {
  name                = "cloudx-sqlserver"
  resource_group_name = var.resourceGroup
  location            = var.location
  version             = "12.0"

  azuread_administrator {
    login_username              = var.adminUser.user_principal_name
    object_id                   = var.adminUser.object_id
    azuread_authentication_only = true
  }
}

resource "azurerm_mssql_firewall_rule" "cloudx-sqlserver_public_ip_exclusion1" {
  name             = "public_ip_exclusion1"
  server_id        = azurerm_mssql_server.cloudXServer.id
  start_ip_address = var.my_public_ip_with_vpn
  end_ip_address   = var.my_public_ip_with_vpn
}

#will work only when run with turned off VPN
data "http" "public_ip" {
  url = "https://ifconfig.me/ip"
}

resource "azurerm_mssql_firewall_rule" "cloudx-sqlserver_public_ip_exclusion2" {
  name             = "public_ip_exclusion2"
  server_id        = azurerm_mssql_server.cloudXServer.id
  start_ip_address = data.http.public_ip.response_body
  end_ip_address   = data.http.public_ip.response_body
}

# https://github.com/hashicorp/terraform-provider-azurerm/issues/23438#issuecomment-2495320829
resource "azapi_resource" "eShopOnWebCatalogDb" {
  type      = "Microsoft.Sql/servers/databases@2024-05-01-preview"
  name      = "Microsoft.eShopOnWeb.CatalogDb"
  location  = var.location
  parent_id = azurerm_mssql_server.cloudXServer.id

  body = {
    properties = {
      minCapacity                      = 0.5
      maxSizeBytes                     = 34359738368
      autoPauseDelay                   = 15
      zoneRedundant                    = false
      isLedgerOn                       = false
      useFreeLimit                     = true
      readScale                        = "Disabled"
      freeLimitExhaustionBehavior      = "BillOverUsage"
      availabilityZone                 = "NoPreference"
      requestedBackupStorageRedundancy = "Local"
    }

    sku = {
      name     = "GP_S_Gen5"
      tier     = "GeneralPurpose"
      family   = "Gen5"
      capacity = 2
    }
  }

  schema_validation_enabled = false

  response_export_values = ["*"]

  #provider = azapi.integration
}

resource "azapi_resource" "eShopOnWebIdentityDb" {
  type      = "Microsoft.Sql/servers/databases@2024-05-01-preview"
  name      = "Microsoft.eShopOnWeb.Identity"
  location  = var.location
  parent_id = azurerm_mssql_server.cloudXServer.id

  body = {
    properties = {
      minCapacity                      = 0.5
      maxSizeBytes                     = 34359738368
      autoPauseDelay                   = 15
      zoneRedundant                    = false
      isLedgerOn                       = false
      useFreeLimit                     = true
      readScale                        = "Disabled"
      freeLimitExhaustionBehavior      = "BillOverUsage"
      availabilityZone                 = "NoPreference"
      requestedBackupStorageRedundancy = "Local"
    }

    sku = {
      name     = "GP_S_Gen5"
      tier     = "GeneralPurpose"
      family   = "Gen5"
      capacity = 2
    }
  }

  schema_validation_enabled = false

  response_export_values = ["*"]

  #provider = azapi.integration
}

output "eShopOnWebCatalogDb" {
  value = azapi_resource.eShopOnWebCatalogDb
}

output "eShopOnWebIdentityDb" {
  value = azapi_resource.eShopOnWebIdentityDb
}

output "cloudXSqlServer" {
  value = azurerm_mssql_server.cloudXServer
}