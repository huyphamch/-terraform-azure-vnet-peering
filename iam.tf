# Add onboarded user and assign him custom role with least privilege 
resource "azuread_user" "onboarded" {
  user_principal_name   = var.custom_email
  display_name          = "Onboarded user"
  mail_nickname         = "onboarded"
  password              = var.admin_password
  force_password_change = true
}

data "azurerm_subscription" "current" {
}

resource "azurerm_role_definition" "custom" {
  name        = "Virtual Machine User"
  scope       = data.azurerm_subscription.current.id
  description = "Can (re-)start virtual machines and read storage/network/subscriptions"

  permissions {
    actions = [
      "Microsoft.Compute/virtualMachines/read",
      "Microsoft.Compute/virtualMachines/start/action",
      "Microsoft.Compute/virtualMachines/restart/action",
      "Microsoft.Network/virtualNetworks/read",
      "Microsoft.Storage/storageAccounts/read",
      "Microsoft.Storage/storageAccounts/blobServices/containers/read",
      "Microsoft.Resources/subscriptions/resourceGroups/read",
      "Microsoft.Resources/subscriptions/read"
    ]
    data_actions     = ["Microsoft.Compute/virtualMachines/login/action"]
    not_actions      = []
    not_data_actions = []
  }

  assignable_scopes = [
    data.azurerm_subscription.current.id
  ]
}

resource "azurerm_role_assignment" "role-assignment" {
  scope              = data.azurerm_subscription.current.id
  role_definition_id = azurerm_role_definition.custom.role_definition_resource_id
  principal_id       = azuread_user.onboarded.id
}

