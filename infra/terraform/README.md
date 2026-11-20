---
title: Terraform Landing Zone
description: Terraform inputs, networking, state, and validation for the Azure AI landing zone
---

## Terraform landing zone

The root configuration pins Terraform, providers, the ALZ Terraform AVM, and the CAF ALZ library. Its partial `azurerm` backend uses Microsoft Entra ID and OIDC; the platform-owned state account is intentionally not created here.

## Required inputs

Copy `terraform.tfvars.example` to a local `terraform.tfvars` and replace every placeholder with platform-approved values. Do not commit the local file. The management-group parent, tenant, platform and workload subscription placements and names, and resource prefix must be confirmed by the platform owner before a deployment plan is considered actionable. Subscription IDs must include at least one platform and one workload placement.

## Backend configuration

The platform owner supplies the state account, container, and key. Configure OIDC federation and grant the deployment identity `Storage Blob Data Contributor` on the state container. Ensure the selected runner can reach the approved storage endpoint and that the storage account's recovery, audit, and network controls meet the platform standard.

Initialize with backend values supplied outside source control:

```powershell
terraform init -input=false `
  -backend-config="storage_account_name=<platform-storage-account>" `
  -backend-config="container_name=<state-container>" `
  -backend-config="key=<environment>/azure-ai-landing-zone.tfstate"
```

The backend configuration is cached under `.terraform/`; use only non-secret identifiers there. Do not enable access-key or SAS authentication.

The ALZ module uses the pinned `alz` architecture and policy library. Subscription placement is explicitly configured and returns subscriptions to the supplied parent management group if placements are destroyed. Review the resulting management-group and policy scopes before any apply.

The workload management group receives CAF policies plus explicit Deny assignments for public network access on Azure AI Search, Cosmos DB, Storage, Key Vault, and Cognitive Services. Storage uses a stricter custom Deny policy because the built-in policy also accepts `SecuredByPerimeter`; Cognitive Services uses a custom Deny policy because built-in definition `47ba1dd7-28d9-4b07-a8d5-9813bed64e0c` is Modify-only.

`public_access_exemptions` defaults to `{}`. Add an entry only after separate case-by-case approval; each entry is scoped to one resource and requires the owner, approval reference, rationale, and an RFC 3339 expiry:

```hcl
public_access_exemptions = {
  foundry_dependency = {
    policy_key         = "storage"
    resource_id        = "/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Storage/storageAccounts/<account>"
    owner              = "<service-owner>"
    approval_reference = "<approved-change-or-risk-record>"
    rationale          = "<why private endpoint connectivity is unavailable>"
    expires_on         = "2030-01-01T00:00:00Z"
  }
}
```

Supported `policy_key` values are `azure_ai_search`, `cosmos_db`, `storage`, `key_vault`, and `cognitive_services`. The exemption records the resource scope, owner, approval, rationale, and expiry in Azure Policy metadata.

The built-in policy IDs are from the Azure Policy definitions for [Azure AI Search](https://github.com/Azure/azure-policy/blob/f096d8de10fb25e71dd7f82b78ded110ec711d73/built-in-policies/policyDefinitions/Search/RequirePublicNetworkAccessDisabled_Deny.json), [Cosmos DB](https://github.com/Azure/azure-policy/blob/f096d8de10fb25e71dd7f82b78ded110ec711d73/built-in-policies/policyDefinitions/Cosmos%20DB/Cosmos_PrivateNetworkAccess_AuditDeny.json), [Storage](https://github.com/Azure/azure-policy/blob/f096d8de10fb25e71dd7f82b78ded110ec711d73/built-in-policies/policyDefinitions/Storage/StoragePublicNetworkAccess_AuditDeny.json), and [Key Vault](https://github.com/Azure/azure-policy/blob/f096d8de10fb25e71dd7f82b78ded110ec711d73/built-in-policies/policyDefinitions/Key%20Vault/PublicNetworkAccess_Audit.json). The storage built-in definition permits `SecuredByPerimeter`, so it is replaced by a stricter custom Deny policy that matches this plan's private-endpoint-only exception rule.

## Operations, Cost, and Recovery

The platform subscription hosts a central Log Analytics workspace. `diagnostic_retention_in_days` and `cost_budgets` are required owner decisions; the sample values are placeholders, not approved retention or spending limits. The Terraform workflow requires the resource group, workspace name, retention, and a budget for each subscription placement before planning.

Diagnostic settings are not enabled by default. Populate `platform_diagnostic_targets` or `workload_diagnostic_targets` only after the platform owner approves each resource, log and metric categories, exclusions, authorized readers, and retention. Use `diagnostic_exclusions` to document excluded resources and the rationale. The workspace disables local authentication and resource-only permissions; only listed principal IDs receive an explicit `Log Analytics Reader` assignment from this root. Keep sensitive data and high-cardinality identifiers out of collected logs unless an approved redaction strategy is in place.

The workload inherits the ALZ security-policy baseline and the private-network Deny assignments. This root tags its operations resource group and workspace with `environment` and `managed_by`; workload resources must use the same environment and owner-approved cost-allocation tags when they are added.

## Connectivity hub and egress

The platform-owned connectivity resource group and hub virtual network are created in `region`, which defaults to Sweden Central. The pinned ALZ hub-and-spoke AVM creates the hub, Azure Firewall, and shared route tables. VPN, ExpressRoute, Bastion, DDoS Protection Plan, NAT Gateway, private DNS zones, and DNS resolver are disabled; add them only after a confirmed requirement and cost review.

The platform owner must provide a non-overlapping hub CIDR, an `AzureFirewallSubnet` CIDR of `/26` or larger, and an approved `firewall_sku_tier`. Do not reuse example CIDRs or choose the tier without capacity and cost review. The Firewall's public IP is used for controlled outbound connectivity; no public AI service endpoint is created by this configuration.

`firewall_policy_rule_collection_groups` is required and has no permissive default. Configure only approved source ranges, service FQDNs or network destinations, protocols, and ports. Application rules support HTTP/HTTPS FQDN destinations; network rules support TCP, UDP, ICMP, or Any with explicit destination addresses and ports. Rules are Allow-only; unmatched traffic remains denied by Azure Firewall. Wildcard source addresses, wildcard-only destinations, and wildcard ports are rejected. An empty map intentionally fails plan-time variable validation, so the example file is not deployment-ready.

P03-T02 creates the workload VNet and network resource group in the workload subscription, peers it with the connectivity hub, and creates a workload-owned route table. The route table sends the dedicated Foundry agent subnet's default route to the Azure Firewall private IP. The hub AVM's `connectivity_user_subnet_route_table_id` remains scoped to hub subnets; the workload route table avoids relying on cross-subscription association.

The platform and workload owners must provide non-overlapping private IPv4 address spaces and distinct subnet CIDRs. The Foundry Agent Service subnet is delegated to `Microsoft.App/environments`, must be dedicated per Foundry resource, and must be `/27` or larger; Microsoft recommends `/24` or larger for production workloads. Keep a separate private-endpoint subnet and do not allocate its endpoints in `192.168.0.0/24`, which conflicts with the hosted-agent sandbox. Neither example CIDRs nor placeholder inputs are deployment-ready.

The root creates the Foundry, Azure AI Search, Cosmos DB, Storage Blob, and Key Vault private DNS zones in the connectivity resource group and links them to the hub and workload VNets. Add each approved operator VNet ID to `authorized_operator_virtual_network_ids`; linking a zone provides name resolution, not network access. On-premises or other non-VNet operator paths require an approved DNS forwarding/resolver design, which is not created by this task.

The workload route is only safe when the owner-approved Firewall rules cover required traffic. Microsoft Foundry guidance identifies `control-{region}.identity.azure.net`, `{region}.login.microsoft.com`, and `login.microsoftonline.com` as required agent-subnet egress, along with Managed Identity dependencies or the `AzureActiveDirectory` service tag. Include other workload-specific model and tool destinations as approved; do not enable TLS inspection on required Foundry flows. Private endpoints do not eliminate all outbound dependencies.

The plan/apply workflow requires `WORKLOAD_NETWORK_RESOURCE_GROUP_NAME`, `WORKLOAD_VIRTUAL_NETWORK_NAME`, `TF_VAR_WORKLOAD_VIRTUAL_NETWORK_ADDRESS_SPACE` (a JSON array), `FOUNDRY_AGENT_SUBNET_NAME`, `FOUNDRY_AGENT_SUBNET_ADDRESS_PREFIX`, `PRIVATE_ENDPOINT_SUBNET_NAME`, and `PRIVATE_ENDPOINT_SUBNET_ADDRESS_PREFIX`. Set `TF_VAR_AUTHORIZED_OPERATOR_VIRTUAL_NETWORK_IDS` to a JSON array when additional operator VNets need private DNS links; it defaults to `[]`. The deployment identity must have the required network and private DNS permissions in both subscriptions.

## Foundry Agent Service and customer-owned state

P04 creates a workload-owned Foundry resource group, Microsoft Foundry account and project, Cosmos DB for NoSQL, Storage, Azure AI Search, Key Vault, and private endpoints. The Foundry account uses `Microsoft.CognitiveServices/accounts@2026-11-15-preview` because customer-owned `capabilitySettings` are create-time API properties. It binds `documentStore` to Cosmos DB, `vectorStore` to Azure AI Search, and `blobStore` to the Foundry Storage account; project settings inherit those account defaults. The account also uses `networkInjections` for the dedicated `Microsoft.App/environments` subnet with Microsoft-managed networking disabled.

The preview API and the account/project capability bindings are immutable deployment choices. The Terraform resources have `prevent_destroy` safeguards. Changing a bound account or project requires a separately planned replacement and data-transition procedure; do not remove those safeguards to force an update. The selected API version is documented by the [official Cognitive Services REST API specification](https://github.com/Azure/azure-rest-api-specs/blob/main/specification/cognitiveservices/resource-manager/Microsoft.CognitiveServices/CognitiveServices/preview/2026-11-15-preview/cognitiveservices.json) and its [account creation example](https://github.com/Azure/azure-rest-api-specs/blob/main/specification/cognitiveservices/resource-manager/Microsoft.CognitiveServices/CognitiveServices/preview/2026-11-15-preview/examples/CreateAccount.json). AzAPI embedded schema validation is disabled for these two resources because the pinned provider's schema index may not include this preview version; the request fields were checked against this official specification.

Before any remote Terraform plan or apply, the platform owner must provide evidence references confirming:

* Every required model and tool is available with sufficient quota in the selected subscription and region; the reference must identify the tested capability list and evidence. This workspace does not infer a model list or claim to perform a live quota check.
* API `2026-11-15-preview` and its capability settings are supported for the target subscription and Sweden Central. If an EU fallback is needed, use it only after recording the missing capability and checking the supported private-network configuration. A public endpoint is not a workaround.
* The Terraform deployment identity has `Storage Blob Data Contributor` on the customer-owned Storage account and `Cosmos DB Operator` on the customer-owned Cosmos DB account before it creates capability settings. These are externally granted prerequisites; this configuration does not self-grant the deployment identity.
* D2 recovery objectives are approved. Cosmos backup type/tier, Storage replication and soft-delete retention, Key Vault retention, and zone redundancy are explicit inputs with no recovery defaults.
* The owner has verified the Foundry-created database and blob-container names used to scope the project's data-plane RBAC assignments.

The workflow requires these evidence references and all P04 configuration values before it initializes remote state, and rejects the example `replace-with...` evidence references at that gate. GitHub repository variables beginning with `FOUNDRY_` map to Terraform inputs, including `FOUNDRY_COSMOSDB_BACKUP` supplied as JSON. The values in `terraform.tfvars.example` are deliberately invalid placeholders, not approved settings.

All AI and state services disable public network access, and private endpoints use the existing private DNS zones and dedicated endpoint subnet. The Foundry project system-assigned identity receives Cosmos DB Operator plus a database-scoped Cosmos DB data role, storage management and container-scoped blob roles, Azure AI Search data/service roles, and Key Vault Secrets User. Container/database names must match the values that the Foundry setup provisions; verify them against the preview contract before deployment.

P05 applies the approved service-specific recovery settings and uses the [Foundry operations runbook](../../docs/runbooks/foundry-operations.md) for private DNS, egress, policy, diagnostics, cost, identity, and restore validation. Search is recovered by rebuilding from approved source data and index definitions; it is not represented as a separate backup.

Recovery controls remain service-specific and gated on approved RPO, RTO, and retention values:

| Service | Governance baseline |
|---------|--------------------|
| Cosmos DB | Select [periodic or continuous backup](https://learn.microsoft.com/en-us/azure/cosmos-db/online-backup-and-restore) at account creation from approved recovery objectives, then test restore. Continuous mode cannot be switched back to periodic |
| Azure Blob Storage | Select [operational backup, vaulted backup, or both](https://learn.microsoft.com/en-us/azure/backup/blob-backup-overview) from approved recovery objectives |
| Key Vault | Preserve [soft-delete and purge-protection safeguards](https://learn.microsoft.com/en-us/azure/key-vault/general/soft-delete-overview); plan recreation of associated RBAC and Event Grid resources |
| Azure AI Search | Preserve source data and index definitions; test [rebuilding and synchronizing indexes](https://learn.microsoft.com/en-us/azure/search/search-howto-reindex) rather than claiming backup coverage |

[Azure Backup](https://learn.microsoft.com/en-us/azure/backup/backup-overview) supports only its documented workloads, and its Cosmos DB support is preview in the cited research. Do not treat centralized backup policy as equivalent protection for every Foundry dependency. The user selected deferring Azure Blob Backup policy provisioning until D2 recovery objectives are recorded (D7). This root currently configures Blob versioning and soft-delete only; these controls are not vaulted/offsite backup. Do not mark the Blob backup baseline complete until the owner-approved policy is implemented and validated.

## Local checks

```powershell
terraform fmt -recursive -check
terraform init -backend=false -input=false
terraform validate -no-color
```

Do not run `terraform apply` until the deployment boundary, target subscriptions, state access, required Foundry capabilities and quota, preview API support, recovery objectives, and diagnostic-data controls are approved.
