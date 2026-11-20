variable "tenant_id" {
  description = "Microsoft Entra tenant ID for the deployment"
  type        = string
}

variable "subscription_id" {
  description = "Platform subscription ID used by the default AzureRM provider"
  type        = string
}

variable "workload_subscription_id" {
  description = "Workload subscription ID used by the workload AzureRM provider"
  type        = string
}

variable "alz_parent_resource_id" {
  description = "Existing parent management group name or tenant ID for the ALZ hierarchy"
  type        = string
}

variable "subscription_placement" {
  description = "Platform-approved subscription IDs and destination management-group names"
  type = map(object({
    subscription_id       = string
    management_group_name = string
  }))

  validation {
    condition     = length(var.subscription_placement) >= 2
    error_message = "Provide at least one platform and one workload subscription placement."
  }

  validation {
    condition = (
      contains(keys(var.subscription_placement), "platform") &&
      contains(keys(var.subscription_placement), "workload") &&
      contains(
        [for placement in values(var.subscription_placement) : placement.subscription_id],
        var.subscription_id
      ) &&
      contains(
        [for placement in values(var.subscription_placement) : placement.subscription_id],
        var.workload_subscription_id
      )
    )
    error_message = "The placement map must include platform and workload entries that match the provider subscription IDs."
  }
}

variable "public_access_exemptions" {
  description = "Explicitly approved, resource-scoped public network access policy exemptions"
  type = map(object({
    policy_key         = string
    resource_id        = string
    owner              = string
    approval_reference = string
    rationale          = string
    expires_on         = string
  }))
  default = {}

  validation {
    condition = alltrue([
      for exemption in values(var.public_access_exemptions) :
      contains(["azure_ai_search", "cosmos_db", "storage", "key_vault", "cognitive_services"], exemption.policy_key) &&
      length(trimspace(exemption.resource_id)) > 0 &&
      length(trimspace(exemption.owner)) > 0 &&
      length(trimspace(exemption.approval_reference)) > 0 &&
      length(trimspace(exemption.rationale)) > 0
    ])
    error_message = "Every public access exemption must name a supported policy and resource, owner, approval reference, and rationale."
  }

  validation {
    condition = alltrue([
      for exemption in values(var.public_access_exemptions) :
      can(formatdate("YYYY-MM-DD'T'hh:mm:ssZZZ", exemption.expires_on))
    ])
    error_message = "Every public access exemption must have an RFC 3339 expiry timestamp."
  }
}

variable "platform_operations_resource_group_name" {
  description = "Platform-owned resource group for centralized operations services"
  type        = string
}

variable "log_analytics_workspace_name" {
  description = "Name of the platform-owned central Log Analytics workspace"
  type        = string
}

variable "diagnostic_retention_in_days" {
  description = "Owner-approved retention period for central diagnostic data"
  type        = number

  validation {
    condition     = var.diagnostic_retention_in_days >= 30 && var.diagnostic_retention_in_days <= 730
    error_message = "Diagnostic retention must be between 30 and 730 days."
  }
}

variable "authorized_log_reader_principal_ids" {
  description = "Explicitly authorized principal object IDs that may read the central Log Analytics workspace"
  type        = set(string)
  default     = []
}

variable "platform_diagnostic_targets" {
  description = "Platform resource diagnostic categories approved for central collection"
  type = map(object({
    resource_id       = string
    log_categories    = set(string)
    metric_categories = set(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for target in values(var.platform_diagnostic_targets) :
      length(trimspace(target.resource_id)) > 0 &&
      (length(target.log_categories) > 0 || length(target.metric_categories) > 0) &&
      !contains(
        [for exclusion in values(var.diagnostic_exclusions) : exclusion.resource_id],
        target.resource_id
      ) &&
      !contains(
        [for workload_target in values(var.workload_diagnostic_targets) : workload_target.resource_id],
        target.resource_id
      )
    ])
    error_message = "Each platform diagnostic target must have approved categories and must not also be excluded or configured as a workload target."
  }
}

variable "workload_diagnostic_targets" {
  description = "Workload resource diagnostic categories approved for central collection"
  type = map(object({
    resource_id       = string
    log_categories    = set(string)
    metric_categories = set(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for target in values(var.workload_diagnostic_targets) :
      length(trimspace(target.resource_id)) > 0 &&
      (length(target.log_categories) > 0 || length(target.metric_categories) > 0) &&
      !contains(
        [for exclusion in values(var.diagnostic_exclusions) : exclusion.resource_id],
        target.resource_id
      )
    ])
    error_message = "Each workload diagnostic target must have approved categories and must not also be excluded."
  }
}

variable "diagnostic_exclusions" {
  description = "Documented diagnostic collection exclusions with their resource scope and rationale"
  type = map(object({
    resource_id = string
    rationale   = string
  }))
  default = {}

  validation {
    condition = alltrue([
      for exclusion in values(var.diagnostic_exclusions) :
      length(trimspace(exclusion.resource_id)) > 0 &&
      length(trimspace(exclusion.rationale)) > 0
    ])
    error_message = "Each diagnostic exclusion must include a resource ID and rationale."
  }
}

variable "cost_budgets" {
  description = "Owner-approved budget and alert configuration for every subscription placement"
  type = map(object({
    amount               = number
    time_grain           = string
    start_date           = string
    contact_emails       = list(string)
    actual_threshold     = number
    forecasted_threshold = number
  }))

  validation {
    condition = (
      length(var.cost_budgets) == length(var.subscription_placement) &&
      length(setsubtract(toset(keys(var.cost_budgets)), toset(keys(var.subscription_placement)))) == 0 &&
      length(setsubtract(toset(keys(var.subscription_placement)), toset(keys(var.cost_budgets)))) == 0
    )
    error_message = "Provide an owner-approved cost budget for every subscription placement, using the same map keys."
  }

  validation {
    condition = alltrue([
      for budget in values(var.cost_budgets) :
      budget.amount > 0 &&
      contains(["BillingAnnual", "BillingMonth", "BillingQuarter", "Annually", "Monthly", "Quarterly"], budget.time_grain) &&
      length(budget.contact_emails) > 0 &&
      budget.actual_threshold > 0 &&
      budget.actual_threshold <= 1000 &&
      budget.forecasted_threshold > 0 &&
      budget.forecasted_threshold <= 1000
    ])
    error_message = "Each budget requires a positive amount, supported time grain, at least one contact email, and alert thresholds between 0 and 1000 percent."
  }
}

variable "region" {
  description = "Azure region for the landing zone"
  type        = string
  default     = "swedencentral"
}

variable "environment" {
  description = "Environment name used for resource naming and state separation"
  type        = string
}

variable "resource_prefix" {
  description = "Organization-approved short prefix used in resource names"
  type        = string
}

variable "connectivity_resource_group_name" {
  description = "Platform-owned resource group for the connectivity hub"
  type        = string
}

variable "connectivity_hub_virtual_network_name" {
  description = "Platform-approved name for the connectivity hub virtual network"
  type        = string
}

variable "connectivity_hub_address_space" {
  description = "Platform-approved, non-overlapping IPv4 address spaces for the connectivity hub"
  type        = list(string)

  validation {
    condition = (
      length(var.connectivity_hub_address_space) > 0 &&
      alltrue([for prefix in var.connectivity_hub_address_space : can(cidrnetmask(prefix))])
    )
    error_message = "Provide at least one valid IPv4 CIDR for the hub address space."
  }
}

variable "firewall_subnet_address_prefix" {
  description = "Platform-approved IPv4 CIDR for the AzureFirewallSubnet"
  type        = string

  validation {
    condition = (
      can(cidrnetmask(var.firewall_subnet_address_prefix)) &&
      try(tonumber(split("/", var.firewall_subnet_address_prefix)[1]) <= 26, false)
    )
    error_message = "Provide a valid IPv4 CIDR for AzureFirewallSubnet with at least 64 addresses, such as a /26 or shorter prefix."
  }
}

variable "firewall_sku_tier" {
  description = "Owner-approved Azure Firewall and Firewall Policy tier"
  type        = string

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.firewall_sku_tier)
    error_message = "firewall_sku_tier must be Basic, Standard, or Premium."
  }
}

variable "firewall_policy_rule_collection_groups" {
  description = "Owner-approved Azure Firewall egress rules grouped by policy collection group"
  type = map(object({
    priority = number
    application_rule_collections = optional(map(object({
      priority = number
      rules = list(object({
        name              = string
        source_addresses  = set(string)
        destination_fqdns = set(string)
        protocols = list(object({
          type = string
          port = number
        }))
      }))
    })), {})
    network_rule_collections = optional(map(object({
      priority = number
      rules = list(object({
        name                  = string
        protocols             = set(string)
        source_addresses      = set(string)
        destination_addresses = set(string)
        destination_ports     = set(string)
      }))
    })), {})
  }))

  validation {
    condition = (
      length(var.firewall_policy_rule_collection_groups) > 0 &&
      alltrue([
        for group in values(var.firewall_policy_rule_collection_groups) :
        group.priority >= 100 &&
        group.priority <= 65000 &&
        (
          length(group.application_rule_collections) > 0 ||
          length(group.network_rule_collections) > 0
        ) &&
        alltrue([
          for collection in values(group.application_rule_collections) :
          collection.priority >= 100 &&
          collection.priority <= 65000 &&
          length(collection.rules) > 0 &&
          alltrue([
            for rule in collection.rules :
            length(rule.name) > 0 &&
            length(rule.source_addresses) > 0 &&
            !contains(rule.source_addresses, "*") &&
            !contains(rule.source_addresses, "0.0.0.0/0") &&
            length(rule.destination_fqdns) > 0 &&
            !contains(rule.destination_fqdns, "*") &&
            length(rule.protocols) > 0 &&
            alltrue([
              for protocol in rule.protocols :
              contains(["Http", "Https"], protocol.type) &&
              protocol.port >= 1 &&
              protocol.port <= 65535
            ])
          ])
        ]) &&
        alltrue([
          for collection in values(group.network_rule_collections) :
          collection.priority >= 100 &&
          collection.priority <= 65000 &&
          length(collection.rules) > 0 &&
          alltrue([
            for rule in collection.rules :
            length(rule.name) > 0 &&
            length(rule.protocols) > 0 &&
            alltrue([
              for protocol in rule.protocols :
              contains(["TCP", "UDP", "ICMP", "Any"], protocol)
            ]) &&
            length(rule.source_addresses) > 0 &&
            !contains(rule.source_addresses, "*") &&
            !contains(rule.source_addresses, "0.0.0.0/0") &&
            length(rule.destination_addresses) > 0 &&
            !contains(rule.destination_addresses, "*") &&
            !contains(rule.destination_addresses, "0.0.0.0/0") &&
            length(rule.destination_ports) > 0 &&
            !contains(rule.destination_ports, "*")
          ])
        ])
      ])
    )
    error_message = "Provide at least one approved egress rule with valid priorities, explicit sources, destinations, protocols, and ports. Catch-all source/destination CIDRs, wildcard-only destinations, and wildcard ports are not allowed."
  }
}

variable "workload_network_resource_group_name" {
  description = "Owner-approved resource group for workload network resources"
  type        = string
}

variable "workload_virtual_network_name" {
  description = "Owner-approved name for the workload virtual network"
  type        = string
}

variable "workload_virtual_network_address_space" {
  description = "Owner-approved private IPv4 address spaces for the workload virtual network"
  type        = list(string)

  validation {
    condition = (
      length(var.workload_virtual_network_address_space) > 0 &&
      alltrue([
        for prefix in var.workload_virtual_network_address_space :
        can(cidrnetmask(prefix)) &&
        try(
          (
            cidrcontains("10.0.0.0/8", cidrhost(prefix, 0)) &&
            cidrcontains("10.0.0.0/8", cidrhost(prefix, -1))
          ) ||
          (
            cidrcontains("172.16.0.0/12", cidrhost(prefix, 0)) &&
            cidrcontains("172.16.0.0/12", cidrhost(prefix, -1))
          ) ||
          (
            cidrcontains("192.168.0.0/16", cidrhost(prefix, 0)) &&
            cidrcontains("192.168.0.0/16", cidrhost(prefix, -1))
          ),
          false
        )
      ])
    )
    error_message = "Provide one or more valid private IPv4 workload address spaces."
  }
}

variable "foundry_agent_subnet_name" {
  description = "Name of the dedicated Foundry Agent Service delegated subnet"
  type        = string

  validation {
    condition     = length(var.foundry_agent_subnet_name) > 0 && length(var.foundry_agent_subnet_name) <= 63
    error_message = "The Foundry agent subnet name must contain 1 to 63 characters."
  }
}

variable "foundry_agent_subnet_address_prefix" {
  description = "Owner-approved RFC 1918 IPv4 CIDR for the dedicated Foundry Agent Service subnet"
  type        = string
}

variable "private_endpoint_subnet_name" {
  description = "Name of the dedicated workload private endpoint subnet"
  type        = string
}

variable "private_endpoint_subnet_address_prefix" {
  description = "Owner-approved IPv4 CIDR for the private endpoint subnet"
  type        = string
}

variable "authorized_operator_virtual_network_ids" {
  description = "Existing authorized operator VNet IDs to link to the workload private DNS zones"
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for virtual_network_id in var.authorized_operator_virtual_network_ids :
      can(regex(
        "^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/virtualNetworks/[^/]+$",
        virtual_network_id
      )) &&
      lower(virtual_network_id) != lower(
        "/subscriptions/${var.subscription_id}/resourceGroups/${var.connectivity_resource_group_name}/providers/Microsoft.Network/virtualNetworks/${var.connectivity_hub_virtual_network_name}"
      ) &&
      lower(virtual_network_id) != lower(
        "/subscriptions/${var.workload_subscription_id}/resourceGroups/${var.workload_network_resource_group_name}/providers/Microsoft.Network/virtualNetworks/${var.workload_virtual_network_name}"
      )
    ])
    error_message = "Each operator VNet ID must be a valid Azure VNet resource ID and must not duplicate the workload or connectivity hub VNet."
  }
}

variable "foundry_resource_group_name" {
  description = "Owner-approved workload resource group for Foundry and customer-owned state resources"
  type        = string
}

variable "foundry_account_name" {
  description = "Globally unique name for the Microsoft Foundry account"
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9-]{0,62}[A-Za-z0-9]$", var.foundry_account_name))
    error_message = "The Foundry account name must contain 2 to 64 alphanumeric characters or hyphens and cannot start or end with a hyphen."
  }
}

variable "foundry_project_name" {
  description = "Name for the Foundry project"
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9-]{0,62}[A-Za-z0-9]$", var.foundry_project_name))
    error_message = "The Foundry project name must contain 2 to 64 alphanumeric characters or hyphens and cannot start or end with a hyphen."
  }
}

variable "foundry_project_display_name" {
  description = "Owner-approved display name for the Foundry project"
  type        = string
}

variable "foundry_region_capability_evidence_reference" {
  description = "Owner evidence reference confirming every required model, tool, and quota in the selected subscription and region"
  type        = string

  validation {
    condition = (
      length(trimspace(var.foundry_region_capability_evidence_reference)) > 0 &&
      !startswith(lower(trimspace(var.foundry_region_capability_evidence_reference)), "replace-with")
    )
    error_message = "Provide the platform-owner evidence reference for required Foundry models, tools, and quotas before planning deployment."
  }
}

variable "foundry_preview_api_support_evidence_reference" {
  description = "Owner evidence reference confirming API 2026-11-15-preview support for the target subscription and region"
  type        = string

  validation {
    condition = (
      length(trimspace(var.foundry_preview_api_support_evidence_reference)) > 0 &&
      !startswith(lower(trimspace(var.foundry_preview_api_support_evidence_reference)), "replace-with")
    )
    error_message = "Provide the platform-owner evidence reference confirming the Foundry preview API is supported before planning deployment."
  }
}

variable "foundry_capability_provisioner_access_evidence_reference" {
  description = "Owner evidence reference confirming the Terraform identity has required capability-settings provisioning roles"
  type        = string

  validation {
    condition = (
      length(trimspace(var.foundry_capability_provisioner_access_evidence_reference)) > 0 &&
      !startswith(lower(trimspace(var.foundry_capability_provisioner_access_evidence_reference)), "replace-with")
    )
    error_message = "Provide owner evidence that the Terraform identity has the required Cosmos DB and Storage provisioning roles."
  }
}

variable "foundry_recovery_approval_reference" {
  description = "Owner approval reference for service-specific recovery objectives and settings"
  type        = string

  validation {
    condition = (
      length(trimspace(var.foundry_recovery_approval_reference)) > 0 &&
      !startswith(lower(trimspace(var.foundry_recovery_approval_reference)), "replace-with")
    )
    error_message = "Provide the approved recovery-objective reference before configuring Foundry state resources."
  }
}

variable "foundry_storage_account_name" {
  description = "Globally unique, lowercase name for the Foundry-owned Storage account"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.foundry_storage_account_name))
    error_message = "The Foundry Storage account name must contain 3 to 24 lowercase letters or digits."
  }
}

variable "foundry_storage_replication_type" {
  description = "D2-approved replication type for the Foundry Storage account"
  type        = string

  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "RAGRS", "GZRS", "RAGZRS"], var.foundry_storage_replication_type)
    error_message = "Choose a supported Storage replication type based on the approved recovery objectives."
  }
}

variable "foundry_blob_soft_delete_retention_days" {
  description = "D2-approved retention in days for deleted Foundry blobs"
  type        = number

  validation {
    condition     = var.foundry_blob_soft_delete_retention_days >= 1 && var.foundry_blob_soft_delete_retention_days <= 365
    error_message = "Blob soft-delete retention must be between 1 and 365 days and match the approved recovery objectives."
  }
}

variable "foundry_container_soft_delete_retention_days" {
  description = "D2-approved retention in days for deleted Foundry blob containers"
  type        = number

  validation {
    condition     = var.foundry_container_soft_delete_retention_days >= 1 && var.foundry_container_soft_delete_retention_days <= 365
    error_message = "Container soft-delete retention must be between 1 and 365 days and match the approved recovery objectives."
  }
}

variable "foundry_cosmosdb_account_name" {
  description = "Globally unique, lowercase name for the Foundry Cosmos DB for NoSQL account"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,44}$", var.foundry_cosmosdb_account_name))
    error_message = "The Cosmos DB account name must contain 3 to 44 lowercase letters, digits, or hyphens."
  }
}

variable "foundry_cosmosdb_total_throughput_limit" {
  description = "Owner-approved Cosmos DB account throughput limit in RU/s; standard setup requires at least 3000"
  type        = number

  validation {
    condition     = var.foundry_cosmosdb_total_throughput_limit >= 3000
    error_message = "The Cosmos DB account throughput limit must be at least 3000 RU/s for standard Agent setup."
  }
}

variable "foundry_cosmosdb_backup" {
  description = "D2-approved native Cosmos DB backup configuration"
  type = object({
    type                = string
    tier                = optional(string)
    interval_in_minutes = optional(number)
    retention_in_hours  = optional(number)
    storage_redundancy  = optional(string)
  })

  validation {
    condition = (
      (
        var.foundry_cosmosdb_backup.type == "Periodic" &&
        var.foundry_cosmosdb_backup.tier == null &&
        var.foundry_cosmosdb_backup.interval_in_minutes >= 60 &&
        var.foundry_cosmosdb_backup.interval_in_minutes <= 1440 &&
        var.foundry_cosmosdb_backup.retention_in_hours >= 8 &&
        var.foundry_cosmosdb_backup.retention_in_hours <= 720 &&
        contains(["Geo", "Local", "Zone"], var.foundry_cosmosdb_backup.storage_redundancy)
      ) ||
      (
        var.foundry_cosmosdb_backup.type == "Continuous" &&
        contains(["Continuous7Days", "Continuous30Days"], var.foundry_cosmosdb_backup.tier) &&
        var.foundry_cosmosdb_backup.interval_in_minutes == null &&
        var.foundry_cosmosdb_backup.retention_in_hours == null &&
        var.foundry_cosmosdb_backup.storage_redundancy == null
      )
    )
    error_message = "Choose either a D2-approved Periodic Cosmos DB backup configuration or a supported Continuous tier; do not combine their settings."
  }
}

variable "foundry_cosmosdb_zone_redundant" {
  description = "D2-approved zone redundancy setting for the Cosmos DB primary region"
  type        = bool
}

variable "foundry_cosmosdb_runtime_database_name" {
  description = "Owner-verified database name used to scope the Foundry project data-plane role"
  type        = string
}

variable "foundry_search_service_name" {
  description = "Globally unique name for the Foundry IQ Azure AI Search service"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,58}[a-z0-9]$", var.foundry_search_service_name)) && !strcontains(var.foundry_search_service_name, "--")
    error_message = "The Search service name must contain 3 to 60 lowercase letters, digits, or single hyphens."
  }
}

variable "foundry_search_sku" {
  description = "Owner-approved Azure AI Search SKU that supports the required Foundry features and private endpoint"
  type        = string

  validation {
    condition     = contains(["basic", "standard", "standard2", "standard3", "storage_optimized_l1", "storage_optimized_l2"], var.foundry_search_sku)
    error_message = "Select a supported non-Free Search SKU after verifying required features, regional availability, and quota."
  }
}

variable "foundry_key_vault_name" {
  description = "Globally unique name for the Foundry Key Vault"
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9-]{3,24}$", var.foundry_key_vault_name)) && !strcontains(var.foundry_key_vault_name, "--")
    error_message = "The Key Vault name must contain 3 to 24 letters, digits, or hyphens and cannot contain consecutive hyphens."
  }
}

variable "foundry_key_vault_soft_delete_retention_days" {
  description = "D2-approved Key Vault soft-delete retention in days"
  type        = number

  validation {
    condition     = var.foundry_key_vault_soft_delete_retention_days >= 7 && var.foundry_key_vault_soft_delete_retention_days <= 90
    error_message = "Key Vault soft-delete retention must be between 7 and 90 days and match the approved recovery objectives."
  }
}

variable "foundry_agent_blob_container_name" {
  description = "Owner-verified Agent Service Blob container name for the project-scoped Storage Blob Data Owner role"
  type        = string
}

variable "foundry_file_blob_container_name" {
  description = "Owner-verified Agent Service Blob container name for the project-scoped Storage Blob Data Contributor role"
  type        = string
}
