# =============================================================================
# Kubernetes RBAC Module
# =============================================================================
# Purpose: Create hierarchical RBAC roles and bindings for K3s cluster
# Model: 8 security levels (0-4 + 3a-e) based on ZSEL architecture
# Scope: Cluster-wide roles + namespace-scoped RoleBindings
# =============================================================================

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# =============================================================================
# Input Variables
# =============================================================================

variable "rbac_roles" {
  description = "Map of RBAC role definitions with security levels"
  type = map(object({
    level       = string  # "level-0", "level-1", etc.
    description = string
    rules = list(object({
      api_groups = list(string)
      resources  = list(string)
      verbs      = list(string)
    }))
  }))
}

variable "role_bindings" {
  description = "Map of RoleBinding configurations"
  type = map(object({
    namespace  = string
    role_name  = string
    subjects = list(object({
      kind      = string  # User, Group, ServiceAccount
      name      = string
      namespace = optional(string, "")
    }))
  }))
  default = {}
}

# =============================================================================
# ClusterRoles - Cluster-wide role definitions
# =============================================================================

resource "kubernetes_cluster_role" "roles" {
  for_each = var.rbac_roles

  metadata {
    name = each.key
    
    labels = {
      "security-level" = each.value.level
      "managed-by"     = "terraform"
    }

    annotations = {
      "description" = each.value.description
    }
  }

  dynamic "rule" {
    for_each = each.value.rules
    content {
      api_groups = rule.value.api_groups
      resources  = rule.value.resources
      verbs      = rule.value.verbs
    }
  }
}

# =============================================================================
# RoleBindings - Bind roles to users/groups in namespaces
# =============================================================================

resource "kubernetes_role_binding" "bindings" {
  for_each = var.role_bindings

  metadata {
    name      = each.key
    namespace = each.value.namespace

    labels = {
      "managed-by" = "terraform"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = each.value.role_name
  }

  dynamic "subject" {
    for_each = each.value.subjects
    content {
      kind      = subject.value.kind
      name      = subject.value.name
      namespace = subject.value.namespace != "" ? subject.value.namespace : null
    }
  }
}

# =============================================================================
# Outputs
# =============================================================================

output "cluster_roles_summary" {
  description = "Summary of created ClusterRoles"
  value = {
    total_roles = length(kubernetes_cluster_role.roles)
    roles_by_level = {
      for level in distinct([for r in var.rbac_roles : r.level]) :
      level => [
        for k, v in var.rbac_roles :
        k if v.level == level
      ]
    }
  }
}

output "role_bindings_summary" {
  description = "Summary of created RoleBindings"
  value = {
    total_bindings = length(kubernetes_role_binding.bindings)
    bindings_by_namespace = {
      for ns in distinct([for b in var.role_bindings : b.namespace]) :
      ns => [
        for k, v in var.role_bindings :
        k if v.namespace == ns
      ]
    }
  }
}

output "cluster_role_names" {
  description = "List of created ClusterRole names"
  value       = [for role in kubernetes_cluster_role.roles : role.metadata[0].name]
}

output "role_binding_names" {
  description = "List of created RoleBinding names"
  value       = [for binding in kubernetes_role_binding.bindings : binding.metadata[0].name]
}
