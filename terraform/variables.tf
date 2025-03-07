variable "main_location" {
  type    = string
  default = "uaenorth"
}

variable "second_location" {
  type    = string
  default = "qatarcentral"
}

variable "createDeploymentSlots" {
  type = bool
  default = false
  description = "If we do not need deployment slots, we can save money on service plan"
}

variable "app_service_dotnet_framework_version" {
  type        = string
  default     = "9.0"
  description = "The .NET Framework version for the App Service."
}