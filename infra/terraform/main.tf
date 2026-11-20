module "alz_platform" {
  source  = "Azure/avm-ptn-alz/azurerm"
  version = "0.23.0"

  architecture_name  = "alz"
  location           = var.region
  parent_resource_id = var.alz_parent_resource_id
  enable_telemetry   = false

  subscription_placement                  = var.subscription_placement
  subscription_placement_destroy_behavior = "parent"
}
