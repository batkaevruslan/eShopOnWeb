variable "main_location" {
  type    = string
  default = "uaenorth"
}

variable "second_location" {
  type    = string
  default = "qatarcentral"
}

variable "app_service_plan_sku" {
  type        = string
  default     = "S1" #"P0v3" #https://learn.microsoft.com/en-us/azure/app-service/overview-hosting-plans#should-i-put-an-app-in-a-new-plan-or-an-existing-plan
  description = "The SKU of the App Service Plan."
}

variable "app_service_dotnet_framework_version" {
  type        = string
  default     = "v9.0"
  description = "The .NET Framework version for the App Service."
}
