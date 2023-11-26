output "CurrentSubscriptionId" {
  description = "Output current subscription id"
  value       = data.azurerm_subscription.current.id
}

output "Custom_Email" {
  description = "Operator email"
  value       = azuread_user.operator.user_principal_name
}