#######################
## Standard variables
#######################

variable "cluster_name" {
  description = "Name given to the cluster. Value used for naming some the resources created by the module."
  type        = string
}

variable "base_domain" {
  description = "Base domain of the cluster. Value used for the ingress' URL of the application."
  type        = string
}

variable "subdomain" {
  description = "Subdomain of the cluster. Value used for the ingress' URL of the application."
  type        = string
  default     = "apps"
  nullable    = false
}

variable "argocd_project" {
  description = "Name of the Argo CD AppProject where the Application should be created. If not set, the Application will be created in a new AppProject only for this Application."
  type        = string
  default     = null
}

variable "argocd_labels" {
  description = "Labels to attach to the Argo CD Application resource."
  type        = map(string)
  default     = {}
}

variable "destination_cluster" {
  description = "Destination cluster where the application should be deployed."
  type        = string
  default     = "in-cluster"
}

variable "target_revision" {
  description = "Override of target revision of the application chart."
  type        = string
  default     = "v1.6.0" # x-release-please-version
}

variable "cluster_issuer" {
  description = "SSL certificate issuer to use. Usually you would configure this value as `letsencrypt-staging` or `letsencrypt-prod` on your root `*.tf` files."
  type        = string
  default     = "selfsigned-issuer"
}

variable "enable_service_monitor" {
  description = "Enable Prometheus ServiceMonitor in the Helm chart."
  type        = bool
  default     = true
}

variable "helm_values" {
  description = "Helm chart value overrides. They should be passed as a list of HCL structures."
  type        = any
  default     = []
}

variable "app_autosync" {
  description = "Automated sync options for the Argo CD Application resource."
  type = object({
    allow_empty = optional(bool)
    prune       = optional(bool)
    self_heal   = optional(bool)
  })
  default = {
    allow_empty = false
    prune       = true
    self_heal   = true
  }
}

variable "dependency_ids" {
  description = "IDs of the other modules on which this module depends on."
  type        = map(string)
  default     = {}
}

variable "namespace_labels" {
  description = "Labels to apply to the destination namespace managed by Argo CD (requires CreateNamespace=true)."
  type        = map(string)
  # The namespace is deliberately NOT enrolled in Istio ambient mode. With
  # istio.io/dataplane-mode=ambient the ztunnel captures the hub -> proxy-api
  # call on port 8001: TCP completes the handshake but the HTTP request never
  # gets a response, so the hub times out in get_all_routes() and crashloops
  # ("Repeated api_request to proxy path \"\" failed"). The chart already ships
  # NetworkPolicies for hub/proxy/singleuser, so the internal traffic does not
  # need ambient mTLS. Ingress from the gateway still works: the HTTPRoute
  # targets proxy-public and the gateway's own namespace is in ambient mode.
  default = {}
}

#######################
## Module variables
#######################

variable "gateway_name" {
  description = "Name of the Istio Gateway resource to attach the JupyterHub HTTPRoute to."
  type        = string
  default     = "istio-gateway"
}

variable "gateway_namespace" {
  description = "Namespace where the Istio Gateway resource is deployed."
  type        = string
  default     = "istio-ingress"
}

variable "oidc" {
  description = "OIDC configuration to access the MinIO web interface."

  type = object({
    issuer_url              = string
    oauth_url               = string
    token_url               = string
    api_url                 = string
    client_id               = string
    client_secret           = string
    oauth2_proxy_extra_args = optional(list(string), [])
  })

  default = null
}

variable "storage" {
  description = "MinIO S3 bucket configuration values for the bucket where the archived metrics will be stored."
  type = object({
    bucket_name       = string
    endpoint          = string
    access_key        = string
    secret_access_key = string
  })
}

variable "database" {
  description = "database configuration"
  type = object({
    user     = string
    password = string
    database = string
    endpoint = string
  })
}

variable "mlflow" {
  description = "mlflow configuration"
  type = object({
    endpoint = string
  })
  default = null
}

variable "ray" {
  description = "kuberay configuration"
  type = object({
    endpoint = string
  })
  default = null
}

variable "gpu_scheduling" {
  description = "Scheduling constraints applied to user pods when a GPU is requested. Clusters that expose `nvidia.com/gpu` usually taint the GPU nodes, so a pod requesting the extended resource stays Pending until it tolerates the taint and, when a node advertises a GPU label, selects those nodes. Both values are only applied to the GPU profile choices, never to the CPU-only ones."

  type = object({
    node_selector = optional(map(string), {})
    tolerations = optional(list(object({
      key      = optional(string)
      operator = optional(string)
      value    = optional(string)
      effect   = optional(string)
    })), [])
  })

  default = null
}
