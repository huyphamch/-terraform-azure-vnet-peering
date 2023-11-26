output "CurrentSubscriptionId" {
  description = "Output current subscription id"
  value       = data.azurerm_subscription.current.id
}

output "Email_Onboarded_User" {
  description = "Email from onboarded user"
  value       = azuread_user.onboarded.user_principal_name
}