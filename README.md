---
title: Azure AI Landing Zone
description: Terraform and GitHub Actions source for a governed Azure landing zone for Microsoft Foundry AI workloads
---

# Azure AI Landing Zone

This repository is the source for a greenfield Azure landing zone for Microsoft Foundry workloads. It is intended to establish CAF enterprise-scale governance, a hub-and-spoke network with Azure Firewall, and a private Foundry workload landing zone in Sweden Central.

## Architecture and delivery

* `infra/terraform/` contains version-pinned Terraform configuration for the CAF hierarchy, policy baseline, shared operations, hub network, Foundry workload, and service-specific recovery controls.
* The Terraform root uses the user-confirmed Azure Blob `azurerm` backend with Entra ID/OIDC; the platform owner provides the account, container, key, and access configuration before remote initialization.
* `.github/workflows/` provides validation plus a reviewable-plan/manual-apply path using GitHub OIDC for short-lived Azure authentication.
* Terraform remote state is separate from the Foundry Agent Service's customer-owned Cosmos DB, Storage, Azure AI Search, and Key Vault resources.
* Public network access is denied by default. A public endpoint exception requires proof that private endpoint access is unavailable and separate case-by-case approval.

## Required platform-owner inputs

The repository root is confirmed, but no Azure environment is configured. Do not apply Terraform until the platform owner records and verifies:

1. The target tenant, management-group hierarchy, subscription and environment boundaries, and the scopes at which policy and role assignments are allowed.
2. The platform-owned Azure Blob state account, container, key, Entra/OIDC permissions, network reachability, and verified locking, recovery, audit, and platform access controls.
3. The GitHub organization, repository, protected deployment environment, OIDC federated identity, and approval rules.
4. Diagnostic categories, exclusions, authorized readers, and retention before enabling central collection.
5. Required Foundry models, tools, quotas, and regional support in Sweden Central. Consider another EU region only if a required capability is unavailable.
6. RPO, RTO, retention, and restore expectations before selecting creation-time or backup settings.
7. Non-overlapping private hub and workload CIDRs; dedicated Foundry-agent and private-endpoint subnet ranges; an approved Azure Firewall tier; and destination-specific source, destination, protocol, and port rules before routing workload traffic or planning a network deployment. Supply authorized operator VNet IDs when those networks need private DNS resolution.

The implementation must not infer these values or bypass a missing private-network capability with public access.

## Local workflow

The Terraform directory documents formatting and validation commands. GitHub Actions runs a plan-only workflow for review. Apply remains a separate manual workflow and requires the configured protected environment; no workflow run or local command in this repository grants Azure deployment approval.

## Security

Do not commit credentials, state files, generated plans, or environment-specific secret files. Configure Azure authentication with OIDC and scope federation to the approved repository and deployment environment.
