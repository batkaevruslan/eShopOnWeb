
resource "azurerm_key_vault" "cloudXKeyVault" {
  name                        = "cloudXKeyVault2"
  location                    = var.location
  resource_group_name         = var.resourceGroup
  enabled_for_disk_encryption = true
  tenant_id                   = var.tenantId
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  enable_rbac_authorization = true

  sku_name = "standard"
}

resource "azurerm_role_assignment" "currentUserKeyVaultAccessPolicy" {
  scope                = azurerm_key_vault.cloudXKeyVault.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.currentUserId
}

resource "azurerm_key_vault_secret" "catalogDbConnectionString" {
  name         = "ConnectionStrings--CatalogConnection"
  value        = var.catalogDbConnectionString
  key_vault_id = azurerm_key_vault.cloudXKeyVault.id
  depends_on = [ azurerm_role_assignment.currentUserKeyVaultAccessPolicy ]
}

resource "azurerm_key_vault_secret" "identityDbConnectionString" {
  name         = "ConnectionStrings--IdentityConnection"
  value        = var.identityDbConnectionString
  key_vault_id = azurerm_key_vault.cloudXKeyVault.id
  depends_on = [ azurerm_role_assignment.currentUserKeyVaultAccessPolicy ]
}

output "data" {
  value = azurerm_key_vault.cloudXKeyVault
}