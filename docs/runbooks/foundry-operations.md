---
title: Foundry Landing Zone Operations Runbook
description: Owner-led pre-deployment checks and post-deployment validation for a private Foundry Agent Service landing zone
---

## Purpose and operating boundary

Use this runbook to collect owner evidence before deployment and to verify the Azure AI Landing Zone after a separately authorized deployment. Terraform and GitHub workflow checks do not prove that regional quota, private connectivity, diagnostic routing, or restore objectives work in Azure.

This runbook does not authorize remote Terraform initialization, an Azure plan, or an apply. Keep all public network access disabled. If a required service cannot use private endpoints, stop and follow the approved case-by-case exception process; do not use a public endpoint to bypass a missing regional capability.

## Pre-deployment evidence

Record each item in the platform's approved change or evidence system before configuring the corresponding GitHub repository variables.

| Check | Required evidence | Owner | Status |
|---|---|---|---|
| Workload scope | Tenant, platform/workload subscriptions, environment, resource ownership, and deployment identity | Platform owner | Pending |
| Required capabilities | Exact model and tool list, Sweden Central availability, subscription quota, and date checked | Workload owner | Pending |
| Preview API | Support of `2026-11-15-preview` and account/project capability settings for the target subscription and region | Platform owner | Pending |
| Provisioner access | `Storage Blob Data Contributor` on the Foundry Storage account and `Cosmos DB Operator` on the Foundry Cosmos DB account for the workflow identity | Platform owner | Pending |
| Recovery objectives | RPO, RTO, retention, restore expectations, Cosmos backup type/tier, Storage redundancy and retention, Key Vault retention, and zone redundancy | Workload and platform owners | Pending |
| Network | Non-overlapping hub/spoke CIDRs, subnet allocations, firewall tier, approved egress destinations, and DNS resolver/operator paths | Network owner | Pending |
| Cost and monitoring | Cost budgets, alert contacts, diagnostic categories, exclusions, reader identities, and retention | Platform owner | Pending |
| Foundry-created data scopes | Actual database and container names for project-scoped Cosmos and Blob RBAC roles | Workload owner | Pending |

Do not provide placeholder or sample values as evidence. Terraform requires evidence references but cannot verify their content; approval remains human-owned.

## Post-deployment verification

Run these checks from an authorized operator path and from the deployed workload subnet. Capture timestamps, resource IDs, expected and observed results, and the approving change reference. Do not mark the checks complete based only on a Terraform plan or apply result.

| Area | Verification | Acceptance evidence |
|---|---|---|
| Azure Policy | Confirm CAF assignments and workload public-network Deny policies are assigned at the intended management-group scope; inspect compliance for every AI/data resource | Assignment IDs, policy states, noncompliance exceptions and owners |
| Private endpoints | Confirm Foundry, Cosmos DB, Search, Blob, and Key Vault private endpoint connections are approved and in the expected subnet | Private endpoint resource IDs, connection states, subnet IDs |
| Private DNS | Resolve each service FQDN from the workload and authorized operator paths and confirm the answer targets its private endpoint | Query output, source host/VNet, FQDN, resolved address, timestamp |
| Firewall egress | Exercise only approved Foundry identity, model, and tool flows; confirm unapproved destinations remain denied | Rule collection, source/destination/protocol/port, observed result |
| Identity | Verify the Foundry project managed identity has only the documented Cosmos, Blob, Search, and Key Vault roles at the intended scopes | Principal ID, role definition IDs, scopes, access test results |
| Diagnostics | Confirm approved categories reach the central workspace, exclusions are effective, retention is correct, and only authorized readers can query | Diagnostic setting IDs, sample event metadata, retention and reader review |
| Cost | Confirm each subscription budget, owner contact, actual threshold, and forecast threshold; validate alert routing | Budget IDs, recipients, test alert record, owner |
| Security visibility | Confirm Defender/security posture and platform alert routing match the CAF baseline without collecting unapproved diagnostic data | Control state, alert route, approved data scope |

Do not include secrets, raw customer content, or personal data in this runbook. Store only sanitized evidence references and bounded test results.

## Recovery validation

Perform restore tests in an owner-approved nonproduction environment or an explicitly approved recovery exercise. Record the workload's confirmed RPO, RTO, and retention before testing.

Azure Backup policy provisioning for the Foundry Blob account is deferred until the workload owner records D2 recovery objectives, as directed by D7. The current Terraform configuration enables Blob versioning and soft-delete but does not create a backup vault, policy, or backup instance; do not describe those native controls as offsite backup.

| Service | Recovery procedure | Evidence to retain |
|---|---|---|
| Cosmos DB | Restore using the configured native periodic or continuous backup mode and validate the recovered database and application data | Backup mode/tier, restore point, start/end UTC times, recovered database, observed RPO/RTO |
| Azure Blob Storage | Restore deleted blobs or containers using the approved soft-delete/versioning and redundancy settings; include the Foundry-generated containers | Container scope, restore point, start/end UTC times, observed RPO/RTO |
| Key Vault | Validate soft-delete recovery and purge protection with an approved test vault; verify recovery of secrets and recreation of dependent RBAC/Event Grid resources | Retention, purge-protection state, recovery result, dependent resources recreated |
| Azure AI Search | Rebuild indexes from the approved source data and versioned index definitions; verify document counts and representative queries | Source/version IDs, rebuild duration, index validation, observed recovery objective |
| Foundry account/project | Recreate only through an approved replacement and data-transition plan because customer-owned capability bindings are immutable | Replacement approval, old/new resource IDs, state migration validation |

Do not claim a Search backup or a Foundry resource restore based only on successful index recreation or Terraform configuration.

## Incident and change handling

For private connectivity failures, record the affected service, feature, private endpoint state, DNS answer, route, firewall decision, and required flow. Preserve deny-by-default behavior while troubleshooting.

For a region or API capability gap, record the missing model/tool or API operation, target subscription and region, date checked, quota/support evidence, and any EU alternative evaluated. Re-plan the affected resources before changing region or immutable Foundry capability settings.

For a public endpoint exception, stop and obtain the separate resource-scoped approval required by the landing-zone policy. Record the owner, approval reference, rationale, expiry, and why private endpoint access is unavailable.
