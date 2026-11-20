resource "null_resource" "dependencies" {
  triggers = var.dependency_ids
}

resource "argocd_project" "this" {
  count = var.argocd_project == null ? 1 : 0

  metadata {
    name      = var.destination_cluster != "in-cluster" ? "jupyterhub-${var.destination_cluster}" : "jupyterhub"
    namespace = "argocd"
  }

  spec {
    description  = "jupyterhub application project for cluster ${var.destination_cluster}"
    source_repos = ["https://github.com/GersonRS/modern-gitops-stack-module-jupyterhub.git"]

    destination {
      name      = var.destination_cluster
      namespace = "jupyterhub"
    }

    orphaned_resources {
      warn = true
    }

    cluster_resource_whitelist {
      group = "*"
      kind  = "*"
    }
  }
}

data "utils_deep_merge_yaml" "values" {
  input = [for i in concat(local.helm_values, var.helm_values) : yamlencode(i)]
}

resource "argocd_application" "this" {
  metadata {
    name      = var.destination_cluster != "in-cluster" ? "jupyterhub-${var.destination_cluster}" : "jupyterhub"
    namespace = "argocd"
    labels = merge({
      "application" = "jupyterhub"
      "cluster"     = var.destination_cluster
    }, var.argocd_labels)
  }

  timeouts {
    create = "15m"
    delete = "15m"
  }

  wait = var.app_autosync == { "allow_empty" = tobool(null), "prune" = tobool(null), "self_heal" = tobool(null) } ? false : true

  spec {
    project = var.argocd_project == null ? argocd_project.this[0].metadata.0.name : var.argocd_project

    source {
      repo_url        = "https://github.com/GersonRS/modern-gitops-stack-module-jupyterhub.git"
      path            = "charts/jupyterhub"
      target_revision = var.target_revision
      helm {
        release_name = "jupyterhub"
        values       = data.utils_deep_merge_yaml.values.output
      }
    }

    destination {
      name      = var.destination_cluster
      namespace = "jupyterhub"
    }

    sync_policy {
      dynamic "managed_namespace_metadata" {
        for_each = length(var.namespace_labels) > 0 ? [var.namespace_labels] : []
        content {
          labels = managed_namespace_metadata.value
        }
      }
      dynamic "automated" {
        for_each = toset(var.app_autosync == { "allow_empty" = tobool(null), "prune" = tobool(null), "self_heal" = tobool(null) } ? [] : [var.app_autosync])
        content {
          prune       = automated.value.prune
          self_heal   = automated.value.self_heal
          allow_empty = automated.value.allow_empty
        }
      }

      retry {
        backoff {
          duration     = "20s"
          max_duration = "2m"
          factor       = "2"
        }
        limit = "5"
      }

      sync_options = [
        "CreateNamespace=true"
      ]
    }
  }

  depends_on = [
    resource.null_resource.dependencies,
  ]
}

resource "null_resource" "this" {
  depends_on = [
    resource.argocd_application.this,
  ]
}

data "kubernetes_service_v1" "jupyterhub" {
  metadata {
    name      = "proxy-public"
    namespace = "jupyterhub"
  }
  depends_on = [
    null_resource.this
  ]
}
