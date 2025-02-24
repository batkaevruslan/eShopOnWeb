variable "my_public_ip_with_vpn" {
  type    = string
  default = "204.153.55.4"
}

variable "location" {
  type    = string
}

variable "resourceGroup" {
  type = string
}

variable "adminUser" {
  type = object({
    user_principal_name = string
    object_id = string
  })
}