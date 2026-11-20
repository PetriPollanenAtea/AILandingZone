provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }

  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
}

provider "azurerm" {
  alias = "workload"

  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }

  tenant_id       = var.tenant_id
  subscription_id = var.workload_subscription_id
}

provider "azapi" {}

provider "azapi" {
  alias           = "workload"
  subscription_id = var.workload_subscription_id
}

provider "alz" {
  library_references = [
    {
      path = "platform/alz"
      ref  = "2026.04.2"
    }
  ]
}
