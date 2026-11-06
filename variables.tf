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
  default     = "v1.7.0" # x-release-please-version
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
  description = "OIDC configuration for the hub login."

  type = object({
    oauth_url = string
    token_url = string
    api_url   = string
    client_id = string
    # Empty for a public OIDC client. SSO Corp registers `compass_mgc` without a
    # secret, and Keycloak accepts an empty client_secret on the token endpoint
    # for such clients, so leaving this empty is supported rather than a typo.
    client_secret = optional(string, "")

    # Send the client credentials in the Authorization header instead of the
    # request body. Only needed for providers that reject body credentials.
    basic_auth = optional(bool, false)

    # Proof Key for Code Exchange. On by default, matching oauthenticator, and
    # required for a public client because there is no secret to prove the
    # token exchange came from the same party that started the login.
    enable_pkce = optional(bool, true)

    # Accepted for compatibility with the object the keycloak oidc_bootstrap
    # module returns. GenericOAuthenticator never reads an issuer URL, so the
    # value is ignored; keeping it avoids forcing callers to reshape the object.
    issuer_url              = optional(string, "")
    oauth2_proxy_extra_args = optional(list(string), [])

    # Group-based authorization reads a claim from the userinfo response. Set
    # use_group_claims = false when the identity provider does not emit a groups
    # claim at all (SSO Corp only returns the member e-mail): the hub would
    # otherwise see an empty group list and reject every login, because
    # allowed_groups never matches. With false the hub admits any authenticated
    # employee and authorization is enforced per group by the notebook
    # credential instead. A null claim_groups_key cannot express this, because
    # an optional() default replaces null with the default value.
    use_group_claims = optional(bool, true)
    claim_groups_key = optional(string, "groups")
    allowed_groups   = optional(list(string), ["user", "modern-gitops-stack-admins"])
    admin_groups     = optional(list(string), ["modern-gitops-stack-admins"])
    manage_groups    = optional(bool, true)

    # Usernames granted hub admin rights. Needed when admin_groups cannot be
    # used because the provider emits no group claim.
    admin_users = optional(list(string), [])

    # Who may log in when use_group_claims is false. There is no group claim to
    # match, so the provider alone cannot tell an employee from anyone else:
    # allow_all = true admits every identity the provider authenticates, which
    # for SSO Corp means every Magalu employee. Set it to false and fill
    # allowed_users to restrict the hub to an explicit list; check_allowed()
    # then answers 403 instead of admitting the user.
    allow_all = optional(bool, true)

    # Explicit allow list, only consulted when allow_all is false. Usernames are
    # matched after normalization (lowercase), so list them in lowercase.
    allowed_users = optional(list(string), [])

    # Deny list, evaluated before allow_all. Use it to revoke one person without
    # switching the hub to an allow list.
    blocked_users = optional(list(string), [])
  })

  default = null

  validation {
    condition     = var.oidc == null ? true : var.oidc.use_group_claims || var.oidc.allow_all || length(var.oidc.allowed_users) > 0
    error_message = "With use_group_claims = false there is no group claim to authorize against, so the hub needs either allow_all = true (any authenticated employee) or a non-empty allowed_users list. Leaving both unset rejects every login with 403."
  }
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

variable "user_groups" {
  description = <<-EOT
    Per-group GCP credentials for the notebook servers, resolved at spawn time.

    When set, the spawn form gains a group selector listing the groups the
    authenticated member belongs to, and the notebook starts with that group's
    GCP service account key. When null the feature is disabled and the form
    shows only the CPU, memory and GPU fields.

    `api_url` is the Compass/Luigi endpoint that returns the groups of a member.
    The module appends the URL-encoded e-mail of the authenticated user, so the
    value must be the path prefix, for example
    `https://luigi-compass.luizalabs.com/groups/member`.

    `groups` maps each group slug, exactly as that API returns it, to the GCP
    project that owns the group service account. The Secret Manager secret is
    derived from both values with the naming convention already used by the
    platform:

        AUTOMATION_SERVICE_ACCOUNT_JSONKEY_<GROUP_UPPER>_<PROJECT_UPPER>

    so a `group-analytics-fraude` group in `maga-bigdata` reads
    `AUTOMATION_SERVICE_ACCOUNT_JSONKEY_GROUP-ANALYTICS-FRAUDE_MAGA-BIGDATA`.
    Deriving the name instead of accepting it keeps the map small and makes a
    typo in one group impossible to hide.

    `hub_key_secret_name` is the name of a Kubernetes Secret, in the JupyterHub
    namespace, holding the key of the service account that can read those
    Secret Manager secrets. The module mounts it into the hub only, never into a
    notebook, so a compromised notebook can reach the single group it selected
    and nothing else. The Secret must exist before the module is applied and
    must use the key `key.json`.
  EOT

  type = object({
    api_url             = string
    api_timeout_seconds = optional(number, 20)
    hub_key_secret_name = string
    groups = map(object({
      project = string
    }))
    # Appended to a bare username when the identity provider returns neither an
    # e-mail claim nor a username that already looks like an address. SSO Corp
    # exposes preferred_username, which is the part before the @, so the Compass
    # lookup would query the wrong member without this.
    email_domain = optional(string, "luizalabs.com")
  })

  default = null

  validation {
    condition     = var.user_groups == null ? true : length(var.user_groups.groups) > 0
    error_message = "user_groups.groups must declare at least one group when user_groups is set."
  }

  validation {
    # The group option lists only the intersection of the Compass response and
    # this map, so an empty map silently produces a form with no group selector
    # at all. Catching it here turns a confusing runtime symptom into a plan error.
    condition = var.user_groups == null ? true : alltrue([
      for slug in keys(var.user_groups.groups) : startswith(slug, "group-")
    ])
    error_message = "Every user_groups.groups key must start with group-, because the Compass API returns slugs in that form and the intersection is matched literally."
  }

  validation {
    condition = var.user_groups == null ? true : alltrue([
      for slug in keys(var.user_groups.groups) : can(regex("^group-[a-z0-9-]+$", slug))
    ])
    error_message = "Every user_groups.groups key must look like group-<slug>, because the group slug is submitted by the spawn form and re-validated against the Compass API response."
  }

  validation {
    condition     = var.user_groups == null ? true : can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.user_groups.hub_key_secret_name))
    error_message = "user_groups.hub_key_secret_name must be a valid Kubernetes Secret name (lowercase alphanumeric and dashes)."
  }
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
