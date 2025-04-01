<#
terraform init -upgrade
terraform apply -auto-approve
terraform apply -auto-approve -var createDeploymentSlots=true
terraform destroy -auto-approve
#>

Connect-AzAccount -Subscription "Visual Studio Professional Subscription"

$vsSubscription = Get-AzSubscription -SubscriptionName "Visual Studio Professional Subscription"

$env:ARM_SUBSCRIPTION_ID = $vsSubscription.Id