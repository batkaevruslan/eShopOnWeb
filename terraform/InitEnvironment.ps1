<#
terraform init
terraform plan
terraform apply -auto-approve
terraform destroy
#>

Connect-AzAccount -Subscription "Visual Studio Professional Subscription"

$vsSubscription = Get-AzSubscription -SubscriptionName "Visual Studio Professional Subscription"

$env:ARM_SUBSCRIPTION_ID = $vsSubscription.Id

$terraformServicePrincipal = New-AzADServicePrincipal -DisplayName "TerraformApp"
