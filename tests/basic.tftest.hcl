# =============================================================================
# K8s RBAC Module - Basic Tests
# =============================================================================

# Test 1: Basic ClusterRole creation
run "basic_cluster_role" {
  command = plan
  
  variables {
    rbac_roles = {
      "readonly" = {
        level       = "level-3"
        description = "Read-only access to resources"
        rules = [{
          api_groups = [""]
          resources  = ["pods", "services"]
          verbs      = ["get", "list", "watch"]
        }]
      }
    }
  }
  
  assert {
    condition     = kubernetes_cluster_role.roles["readonly"].metadata[0].name == "readonly"
    error_message = "ClusterRole name should be readonly"
  }
  
  assert {
    condition     = kubernetes_cluster_role.roles["readonly"].metadata[0].labels["security-level"] == "level-3"
    error_message = "Should have security-level label"
  }
}

# Test 2: Multiple roles
run "multiple_roles" {
  command = plan
  
  variables {
    rbac_roles = {
      "viewer" = {
        level       = "level-3"
        description = "View pods and services"
        rules = [{
          api_groups = [""]
          resources  = ["pods", "services"]
          verbs      = ["get", "list"]
        }]
      }
      "editor" = {
        level       = "level-2"
        description = "Edit resources"
        rules = [{
          api_groups = [""]
          resources  = ["pods", "services", "deployments"]
          verbs      = ["get", "list", "create", "update", "patch"]
        }]
      }
    }
  }
  
  assert {
    condition     = length(kubernetes_cluster_role.roles) == 2
    error_message = "Should create 2 ClusterRoles"
  }
}

# Test 3: Complex role with multiple rules
run "complex_role" {
  command = plan
  
  variables {
    rbac_roles = {
      "admin" = {
        level       = "level-1"
        description = "Administrator role"
        rules = [
          {
            api_groups = [""]
            resources  = ["pods", "services", "configmaps", "secrets"]
            verbs      = ["*"]
          },
          {
            api_groups = ["apps"]
            resources  = ["deployments", "statefulsets", "daemonsets"]
            verbs      = ["*"]
          }
        ]
      }
    }
  }
  
  assert {
    condition     = length(kubernetes_cluster_role.roles["admin"].rule) == 2
    error_message = "Admin role should have 2 rules"
  }
}

# Test 4: RoleBinding with ServiceAccount
run "rolebinding_serviceaccount" {
  command = plan
  
  variables {
    rbac_roles = {
      "reader" = {
        level       = "level-3"
        description = "Read access"
        rules = [{
          api_groups = [""]
          resources  = ["pods"]
          verbs      = ["get", "list"]
        }]
      }
    }
    role_bindings = {
      "reader-binding" = {
        namespace  = "default"
        role_name  = "reader"
        subjects = [{
          kind      = "ServiceAccount"
          name      = "default"
          namespace = "default"
        }]
      }
    }
  }
  
  assert {
    condition     = length(kubernetes_role_binding.bindings) == 1
    error_message = "Should create 1 RoleBinding"
  }
}

# Test 5: Role with wildcard verbs
run "wildcard_verbs" {
  command = plan
  
  variables {
    rbac_roles = {
      "superadmin" = {
        level       = "level-0"
        description = "Full cluster access"
        rules = [{
          api_groups = ["*"]
          resources  = ["*"]
          verbs      = ["*"]
        }]
      }
    }
  }
  
  assert {
    condition     = contains(kubernetes_cluster_role.roles["superadmin"].rule[0].verbs, "*")
    error_message = "Should allow wildcard verbs"
  }
}
