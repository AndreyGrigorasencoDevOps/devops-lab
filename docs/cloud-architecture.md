# Cloud Architecture – Task API Platform (Azure)

> This document describes the cloud architecture for the **Task API Production Platform** deployed in Microsoft Azure.

---

## Table of Contents

- [1. Overview](#1-overview)
- [2. Subscription & Tenant](#2-subscription--tenant)
- [3. Environments & Deployment Strategy](#3-environments--deployment-strategy)
- [4. Naming Convention](#4-naming-convention)
- [5. High-Level Architecture](#5-high-level-architecture)
- [6. Planned Resource Layout](#6-planned-resource-layout-stage-3--stage-4)
- [7. Security Principles](#7-security-principles)
- [8. Monitoring & Observability](#8-monitoring--observability-future)
- [9. Future Evolution](#9-future-evolution)

---

## 1. Overview

The platform is designed to evolve from **manual CLI deployments** (Stage 3) to:

- **Fully automated Infrastructure-as-Code** using Terraform  
- **CI/CD** via GitHub Actions  
- **Kubernetes-based** production workloads  

| Property        | Value   |
|----------------|---------|
| **Primary region** | `uksouth` (UK South) |

---

## 2. Subscription & Tenant

| Property            | Value                                      |
|---------------------|--------------------------------------------|
| Subscription Name   | Azure subscription 1                       |
| Subscription ID     | `beccabf7-91a3-4c7a-9650-61bfb916ffa8`     |
| Tenant ID           | `0435e23c-d8f9-48f2-9c78-ec5d81c1aec7`     |
| Type                | Free Trial                                 |
| Default Region      | `uksouth`                                  |

> **Security note:** Subscription ID and Tenant ID are safe to store in Git.  
> **Never** commit secrets (client secrets, connection strings, passwords, tokens).

---

## 3. Environments & Deployment Strategy

### Environments

| Environment | Source           | Purpose                              |
|-------------|------------------|--------------------------------------|
| `dev`       | `main` branch    | Fast iteration & manual testing      |
| `prod`      | Git release tags | Stable, controlled deployments       |

### Planned behaviour

- **dev** → auto deploy on push  
- **prod** → deploy via release pipeline + Terraform  

---

## 4. Naming Convention

### Standard resource format

```
taskapi-<env>-<resource>-<regionCode>
```

**Examples:**

| Resource   | Name                    |
|-----------|--------------------------|
| RG        | `taskapi-dev-rg-uks`     |
| VNet      | `taskapi-dev-vnet-uks`   |
| NSG       | `taskapi-dev-nsg-uks`    |
| Log Analytics | `taskapi-dev-law-uks` |
| Prod RG   | `taskapi-prod-rg-uks`    |

### Resource codes

| Code | Resource                 |
|------|--------------------------|
| `rg` | Resource Group           |
| `vnet` | Virtual Network        |
| `snet` | Subnet                 |
| `nsg` | Network Security Group   |
| `acr` | Azure Container Registry |
| `aks` | Azure Kubernetes Service |
| `law` | Log Analytics Workspace  |
| `kv`  | Key Vault                |

### Special naming constraints

Some Azure resources have **global** naming constraints:

| Resource   | Constraint                          | Example           |
|------------|-------------------------------------|-------------------|
| **ACR**    | Globally unique, lowercase, no dashes | `taskapidevacruks` |
| **Key Vault** | Globally unique, strict naming rules | May require adjusted pattern |

---

## 5. High-Level Architecture

```
                    Internet
                        │
                        ▼
                Azure Load Balancer
                        │
                        ▼
                     AKS Cluster
                 (Kubernetes Pods)
                        │
            ┌───────────┴───────────┐
            ▼                       ▼
          ACR                  Azure Key Vault
   (Container Registry)       (Secrets storage)
            │
            ▼
   GitHub Actions (CI/CD)
            │
            ▼
        Terraform (IaC)
```

---

## 6. Planned Resource Layout (Stage 3 → Stage 4)

### Core infrastructure

- **Resource Group**
- **Virtual Network**
- **Subnet** (for AKS)
- **Network Security Group**
- **Azure Container Registry**
- **Azure Kubernetes Service**
- **Log Analytics Workspace**
- **Key Vault** (later stage)

---

## 7. Security Principles

- **No secrets stored in Git**
- Use:
  - **Azure Managed Identity** (later)
  - **Key Vault** for secrets
  - **GitHub Secrets** for CI
- **RBAC-based** access control
- **Principle of least privilege**
- **Separate environments** for dev and prod

---

## 8. Monitoring & Observability (Future)

- **Log Analytics Workspace**
- **Container Insights**
- **AKS metrics**
- **Application logs** (pino → stdout → Azure Monitor)

---

## 9. Future Evolution

This architecture will evolve to include:

- Terraform modules
- Remote state backend
- Environment separation via `tfvars`
- Horizontal Pod Autoscaler
- Ingress Controller
- Canary deployments
- Zero-downtime rolling updates