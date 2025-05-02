<#
terraform init -upgrade
terraform apply -auto-approve
terraform apply -auto-approve -var createDeploymentSlots=true
terraform destroy -auto-approve

az config set core.login_experience_v2=off
az account set --subscription "Visual Studio Professional Subscription"
az login
$env:ARM_SUBSCRIPTION_ID = az account show --query "id" --output tsv
az extension add --name serviceconnector-passwordless --upgrade
#>

Connect-AzAccount -Subscription "Visual Studio Professional Subscription"

$vsSubscription = Get-AzSubscription -SubscriptionName "Visual Studio Professional Subscription"

$env:ARM_SUBSCRIPTION_ID = $vsSubscription.Id