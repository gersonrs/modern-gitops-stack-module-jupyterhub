locals {
  domain = format("jupyterhub.%s", trimprefix("${var.subdomain}.${var.base_domain}", "."))

  # Scheduling constraints for user pods that request a GPU. Applied only to the
  # GPU profile choices: a cluster that advertises nvidia.com/gpu almost always
  # taints those nodes, so without the toleration (and, when the node carries a
  # GPU label, the selector) the pod stays Pending forever.
  #
  # The keys are omitted entirely when gpu_scheduling is unset: `node_selector`
  # and `tolerations` are traits that reject a bare `null` with TraitError.
  gpu_overrides = var.gpu_scheduling == null ? {} : merge(
    length(var.gpu_scheduling.node_selector) > 0 ? { node_selector = var.gpu_scheduling.node_selector } : {},
    length(var.gpu_scheduling.tolerations) > 0 ? { tolerations = var.gpu_scheduling.tolerations } : {}
  )

  # `None` removes the key from the KubeSpawner trait dictionary. An empty dict
  # does NOT: _apply_overrides merges dicts with recursive_update, which only
  # deletes a key when the incoming value is None. Option overrides are applied
  # linearly (cpu -> memory -> gpu), so an empty dict would keep a GPU request
  # coming from a previously applied option.

  # Per-group GCP credentials, disabled when var.user_groups is null.
  #
  # The group list is fetched from Compass/Luigi in Authenticator.post_auth_hook
  # and cached in auth_state, because the spawn form is rendered after login but
  # before the pod exists, and the API answers in ~9s: fetching it again on every
  # form render would be unusable.
  #
  # The credential is delivered by the hub, never by the notebook. The hub holds
  # a single GCP service account key (mounted from credentials_secret_name) whose
  # only role is to read the per-group keys from Secret Manager. The notebook
  # only ever sees the key of the group the user selected, so a compromised
  # notebook cannot reach any other group's data.
  user_groups_config = var.user_groups == null ? null : {
    api_url             = trimsuffix(var.user_groups.api_url, "/")
    api_timeout_seconds = var.user_groups.api_timeout_seconds
    email_domain        = var.user_groups.email_domain
    admin_users         = var.oidc.admin_users
    groups = {
      for slug, group in var.user_groups.groups : slug => {
        project = group.project
        secret_name = format(
          "AUTOMATION_SERVICE_ACCOUNT_JSONKEY_%s_%s",
          upper(slug),
          upper(group.project),
        )
      }
    }
  }

  # extraConfig entries run in lexicographic key order, after the chart has
  # applied every hub.config value. That ordering is what makes `groupCredentials`
  # able to read c.KubeSpawner.profile_list: it was already set from
  # singleuser.profileList by the chart's own config file.
  group_credentials_config = local.user_groups_config == null ? {} : {
    groupCredentials = <<-EOT
      import asyncio
      import base64
      import copy
      import json
      import re
      import urllib.parse

      import requests
      from google.auth.transport.requests import Request as _GoogleAuthRequest
      from google.oauth2 import service_account as _google_service_account

      _GROUP_CFG = json.loads(${jsonencode(jsonencode(local.user_groups_config))})
      _HUB_KEY_FILE = "/var/secrets/hub-gcp/key.json"
      _GSM_SCOPE = "https://www.googleapis.com/auth/cloud-platform"
      _GROUP_SLUG_RE = re.compile(r"^group-[a-z0-9-]+$")
      _BASE_PROFILE_LIST = copy.deepcopy(c.KubeSpawner.profile_list)


      def _hub_access_token():
          credentials = _google_service_account.Credentials.from_service_account_file(
              _HUB_KEY_FILE, scopes=[_GSM_SCOPE]
          )
          credentials.refresh(_GoogleAuthRequest())
          return credentials.token


      def _fetch_group_key(project, secret_name):
          """Read one group key from Secret Manager using the hub credential."""
          url = (
              "https://secretmanager.googleapis.com/v1/projects/"
              + urllib.parse.quote(project, safe="")
              + "/secrets/"
              + urllib.parse.quote(secret_name, safe="")
              + "/versions/latest:access"
          )
          response = requests.get(
              url,
              headers={"Authorization": "Bearer " + _hub_access_token()},
              timeout=30,
          )
          response.raise_for_status()
          return base64.b64decode(response.json()["payload"]["data"])


      def _fetch_member_groups(email):
          """Return the Compass/Luigi group slugs of one member."""
          url = _GROUP_CFG["api_url"] + "/" + urllib.parse.quote(email, safe="")
          response = requests.get(url, timeout=_GROUP_CFG["api_timeout_seconds"])
          response.raise_for_status()
          payload = response.json()
          if not isinstance(payload, list):
              raise ValueError("Compass returned %r, expected a list" % type(payload))
          return sorted({str(item) for item in payload if str(item).strip()})


      async def _load_member_groups(authenticator, handler, auth_model):
          """Cache the member's groups in auth_state right after login.

          The spawn form is rendered from auth_state, so the lookup cannot be
          deferred to the spawn hook. A failure is logged and yields no groups
          instead of blocking login: the form then explains that the user has no
          group with data access, which is actionable, while a login error is not.

          The Compass API is keyed by e-mail, but not every provider returns one:
          SSO Corp exposes preferred_username, and the e-mail only appears when
          the `email` scope was granted. A username that already looks like an
          e-mail is used as-is, and a bare username is completed with
          _GROUP_CFG["email_domain"] so the lookup does not silently query a
          non-existent member and hand back an empty group list.
          """
          auth_state = auth_model.get("auth_state") or {}
          user_info = auth_state.get("oauth_user") or {}
          email = user_info.get("email") or user_info.get("preferred_username") or auth_model.get("name")
          if email and "@" not in email and _GROUP_CFG.get("email_domain"):
              email = email + "@" + _GROUP_CFG["email_domain"]
          try:
              groups = await asyncio.to_thread(_fetch_member_groups, email)
          except Exception:
              authenticator.log.exception(
                  "Compass lookup failed for %r, listing no groups", email
              )
              groups = []
          # Without this line a missing group selector is indistinguishable from
          # "the API returned nothing", and the two have opposite fixes.
          configured = sorted(_GROUP_CFG["groups"])
          authenticator.log.info(
              "Compass groups for %s: %d returned, %d configured, %d usable (%s)",
              email, len(groups), len(configured),
              len([g for g in groups if g in _GROUP_CFG["groups"]]),
              ", ".join(configured) or "none configured",
          )
          auth_state["luigi_email"] = email
          auth_state["luigi_groups"] = groups
          auth_model["auth_state"] = auth_state
          # Authenticator.is_admin() returns None, not False, for a user outside
          # admin_users, and auth_to_user only writes `admin` when the value is
          # not None. A user promoted on one login therefore stays an admin
          # forever, even after being removed from admin_users, unless something
          # returns an explicit False. This is that something.
          if not auth_model.get("admin"):
              auth_model["admin"] = auth_model["name"] in _GROUP_CFG["admin_users"]
          return auth_model


      async def _group_profile_list(spawner):
          """Add the group option to the resource profile, filtered per user."""
          profiles = copy.deepcopy(_BASE_PROFILE_LIST)
          auth_state = await spawner.user.get_auth_state() or {}
          allowed = [
              slug
              for slug in auth_state.get("luigi_groups", [])
              if _GROUP_SLUG_RE.match(slug) and slug in _GROUP_CFG["groups"]
          ]
          if allowed:
              choices = {
                  slug: {"display_name": slug, "default": index == 0}
                  for index, slug in enumerate(allowed)
              }
              description = "Escolha o grupo cujos dados voce precisa acessar."
          else:
              choices = {
                  "none": {
                      "display_name": "Nenhum grupo disponivel",
                      "default": True,
                  }
              }
              description = "Sua conta nao pertence a nenhum grupo com acesso a dados."
          profiles[0]["profile_options"] = dict(
              {
                  "group": {
                      "display_name": "Grupo",
                      "description": description,
                      "choices": choices,
                  }
              },
              **profiles[0].get("profile_options", {})
          )
          return profiles


      def _group_options_from_form(formdata, spawner=None):
          """Parse the profile form, then validate the submitted group.

          KubeSpawner only checks a predefined choice against validation_regex
          when it arrives as unlisted_choice; a choice key is used as a dict key
          with no check at all. Anything outside the configured map would raise
          KeyError while loading the profile, so it is rejected here.
          """
          options = {}
          profile_slug = (formdata.get("profile") or [None])[0]
          if not profile_slug:
              return options
          options["profile"] = profile_slug
          prefix = "profile-option-" + profile_slug + "--"
          for key, values in formdata.items():
              if key.startswith(prefix):
                  options[key[len(prefix):]] = values[0]
          group = options.get("group")
          if group and group != "none" and group not in _GROUP_CFG["groups"]:
              raise ValueError("group %r is not configured for this deployment" % group)
          return options


      async def _group_pre_spawn_hook(spawner):
          """Mount the selected group's key into the notebook pod.

          The key is written to a Secret owned by the hub instead of a shared
          volume so it is garbage collected with the pod and so the notebook
          mounts exactly one file, for the group it selected.
          """
          group = (spawner.user_options or {}).get("group")
          if not group or group == "none":
              return
          entry = _GROUP_CFG["groups"].get(group)
          if entry is None:
              raise ValueError("group %r is not configured for this deployment" % group)
          auth_state = await spawner.user.get_auth_state() or {}
          if group not in auth_state.get("luigi_groups", []):
              raise ValueError("group %r is not available to this user" % group)

          key = await asyncio.to_thread(
              _fetch_group_key, entry["project"], entry["secret_name"]
          )

          secret_name = re.sub(r"[^a-z0-9-]", "-", spawner.pod_name.lower())[:200] + "-gsa"
          body = {
              "metadata": {
                  "name": secret_name,
                  "labels": {"jupyterhub-gsa": "true"},
              },
              "type": "Opaque",
              "data": {"key.json": base64.b64encode(key).decode("ascii")},
          }
          from kubernetes_asyncio.client import ApiException

          try:
              await spawner.api.create_namespaced_secret(spawner.namespace, body)
          except ApiException as exc:
              if exc.status != 409:
                  raise
              await spawner.api.delete_namespaced_secret(secret_name, spawner.namespace)
              await spawner.api.create_namespaced_secret(spawner.namespace, body)

          mount_path = "/var/secrets/gsa"
          spawner.volumes = [
              item for item in (spawner.volumes or []) if item.get("name") != "gcp-sa"
          ] + [{"name": "gcp-sa", "secret": {"secretName": secret_name}}]
          spawner.volume_mounts = [
              item for item in (spawner.volume_mounts or []) if item.get("name") != "gcp-sa"
          ] + [{"name": "gcp-sa", "mountPath": mount_path, "readOnly": True}]
          spawner.environment["GOOGLE_APPLICATION_CREDENTIALS"] = mount_path + "/key.json"
          spawner.environment["JUPYTERHUB_GROUP"] = group
          spawner.environment["GOOGLE_CLOUD_PROJECT"] = entry["project"]


      async def _group_post_stop_hook(spawner):
          """Delete the group key Secret once the notebook is gone.

          The key is a long-lived GCP credential; leaving it behind would keep it
          readable in the namespace long after the server that needed it stopped.
          """
          secret_name = re.sub(r"[^a-z0-9-]", "-", spawner.pod_name.lower())[:200] + "-gsa"
          from kubernetes_asyncio.client import ApiException

          try:
              await spawner.api.delete_namespaced_secret(secret_name, spawner.namespace)
          except ApiException as exc:
              if exc.status != 404:
                  raise


      c.KubeSpawner.profile_list = _group_profile_list
      c.KubeSpawner.options_from_form = _group_options_from_form
      c.KubeSpawner.pre_spawn_hook = _group_pre_spawn_hook
      c.KubeSpawner.post_stop_hook = _group_post_stop_hook
      c.Authenticator.post_auth_hook = _load_member_groups
      c.Authenticator.enable_auth_state = True
    EOT
  }

  # The hub mounts the single GCP key whose only permission is reading the
  # per-group keys from Secret Manager. Mounted read-only and never exposed to
  # user pods: a notebook holds the key of its own group, nothing more.
  hub_credentials_volume = local.user_groups_config == null ? [] : [{
    name = "hub-gcp-credentials"
    secret = {
      secretName = var.user_groups.hub_key_secret_name
    }
  }]

  hub_credentials_volume_mount = local.user_groups_config == null ? [] : [{
    name      = "hub-gcp-credentials"
    mountPath = "/var/secrets/hub-gcp"
    readOnly  = true
  }]

  helm_values = [{
    jupyterhub = {
      proxy = {
        # TLS is terminated at the Istio Gateway (listener "https" of
        # istio-gateway), so the proxy only serves plain HTTP. The chart's
        # own HTTPS support (letsencrypt/manual/secret) is not used.
        https = {
          enabled = false
        }
        service = {
          # The chart defaults to a LoadBalancer, which on kind/MetalLB hands
          # proxy-public an external IP serving plain HTTP on port 80 — a path
          # to the hub that bypasses the gateway and its TLS. The HTTPRoute
          # below reaches proxy-public inside the cluster, so ClusterIP is
          # enough and closes that shortcut.
          type = "ClusterIP"
        }
      }
      hub = {
        initContainers = [
          {
            name  = "git-clone-templates"
            image = "alpine/git"
            securityContext = {
              runAsUser    = 1000
              runAsGroup   = 1000
              runAsNonRoot = true
            }
            command = ["/bin/sh", "-c"]
            # The upstream templates repo ships a custom spawn.html whose cards
            # post the fields of the profile list this module used to declare
            # ("profile--jupyter-environment--resources" / "--image"), and it
            # hides the kubespawner form with display:none. KubeSpawner only
            # reads fields named "profile-option-{profile_slug}--{option}"
            # (kubespawner/spawner.py, _options_from_form), so that page would
            # silently drop the cpu/memory choices declared below and every
            # server would fall back to the defaults. Dropping the file here
            # lets the hub fall back to its own spawn.html, which renders the
            # kubespawner form. The other customised pages are kept.
            args = [
              "cd /tmp && git clone --branch=main https://github.com/GersonRS/jupyterhub-templates.git && cp -r jupyterhub-templates/templates/* /templates && cp -r jupyterhub-templates/extra-assets/* /extra-assets && mkdir -p /spawner-templates && cp jupyterhub-templates/templates/form.html /spawner-templates/form.html && rm -f /templates/spawn.html"
            ]
            volumeMounts = [
              {
                name      = "custom-templates"
                mountPath = "/templates"
              },
              {
                name      = "custom-templates-extra-assets"
                mountPath = "/extra-assets"
              },
              {
                name      = "custom-spawner-templates"
                mountPath = "/spawner-templates"
              }
            ]
          }
        ]
        extraVolumes = concat([
          {
            name     = "custom-templates"
            emptyDir = {}
          },
          {
            name     = "custom-templates-extra-assets"
            emptyDir = {}
          },
          {
            name     = "custom-spawner-templates"
            emptyDir = {}
          }
        ], local.hub_credentials_volume)

        extraVolumeMounts = concat([
          {
            name      = "custom-templates"
            mountPath = "/usr/local/share/jupyterhub/custom_templates"
          },
          {
            name      = "custom-templates-extra-assets"
            mountPath = "/usr/local/share/jupyterhub/static/extra_assets"
          },
          {
            name      = "custom-spawner-templates"
            mountPath = "/usr/local/share/jupyterhub/custom_spawner_templates"
          }
        ], local.hub_credentials_volume_mount)
        extraConfig = merge({
          templates = "c.JupyterHub.template_paths = ['/usr/local/share/jupyterhub/custom_templates/']"
          # The three numeric spawn fields are rendered by form.html, which the
          # git-clone-templates initContainer copies from the jupyterhub-templates
          # repository into the custom-spawner-templates volume. KubeSpawner
          # looks for it in additional_profile_form_template_paths before falling
          # back to its own templates/ directory, so the dropdowns are replaced
          # by plain number inputs.
          profileForm = "c.KubeSpawner.additional_profile_form_template_paths = ['/usr/local/share/jupyterhub/custom_spawner_templates']"
        }, local.group_credentials_config)
        extraEnv = {
          OAUTH_TLS_VERIFY = "0"
        }
        config = {
          GenericOAuthenticator = merge(
            {
              login_service      = "keycloak"
              client_id          = "${var.oidc.client_id}"
              client_secret      = "${var.oidc.client_secret}"
              oauth_callback_url = "https://${local.domain}/hub/oauth_callback"
              authorize_url      = "${var.oidc.oauth_url}"
              token_url          = "${var.oidc.token_url}"
              userdata_url       = "${var.oidc.api_url}"
              username_key       = "preferred_username"
              userdata_params    = { state = "state" }
              basic_auth         = var.oidc.basic_auth
              enable_pkce        = var.oidc.enable_pkce
            },
            # A groups claim only exists on providers that emit one. Skipping
            # claim_groups_key makes OAuthenticator ignore group parsing instead of
            # reading a missing key and treating every user as group-less, which
            # combined with allowed_groups rejects all logins.
            {
              scope = var.oidc.use_group_claims ? toset(["openid", "email", "groups"]) : toset(["openid", "email"])
            },
            var.oidc.use_group_claims ? {
              claim_groups_key = var.oidc.claim_groups_key
            } : {},
            # Without a groups claim there is nothing for check_allowed() to match,
            # so the hub falls back to allow_all and admits every identity the
            # provider authenticates — for SSO Corp, every Magalu employee. Set
            # oidc.allow_all = false with oidc.allowed_users to restrict it.
            # Kept in its own merge argument: combining this with the branch
            # above would give the ternary two object shapes, which Terraform
            # unifies into map(string) and coerces the boolean to the string
            # "true". oauthenticator then raises TraitError at startup.
            var.oidc.use_group_claims ? {} : {
              allow_all = var.oidc.allow_all
            },
            length(var.oidc.allowed_groups) > 0 ? {
              allowed_groups = var.oidc.allowed_groups
            } : {},
            length(var.oidc.admin_groups) > 0 ? {
              admin_groups = var.oidc.admin_groups
            } : {},
            length(var.oidc.admin_users) > 0 ? {
              admin_users = var.oidc.admin_users
            } : {},
            length(var.oidc.allowed_users) > 0 ? {
              allowed_users = var.oidc.allowed_users
            } : {},
            length(var.oidc.blocked_users) > 0 ? {
              blocked_users = var.oidc.blocked_users
            } : {},
            var.oidc.manage_groups ? {
              manage_groups = true
            } : {}
          )
          JupyterHub = {
            admin_access        = true
            authenticator_class = "generic-oauth"
          }
        }
      }
      debug = {
        enabled = true
      }
      # The pre-puller DaemonSet replicates onto every node each image listed in
      # the profile choices. The previous profile list carried four notebook
      # images (~2.4 GB each) and was the single largest consumer of disk on the
      # kind cluster. Keeping the flag off guards against that coming back: if
      # someone re-adds an image to a choice, it is no longer pre-pulled on
      # every node. With the current single image the flag is a no-op, because
      # the image is already pulled through singleuser.image below.
      prePuller = {
        pullProfileListImages = false
      }
      singleuser = {
        # Only one image is shipped: scipy-notebook is the smallest image that
        # still carries the full scientific Python stack (NumPy, Pandas,
        # Scikit-learn, Matplotlib, SciPy). Profile choices only change CPU,
        # memory and GPU count, never the image.
        image = {
          name = "quay.io/jupyter/scipy-notebook"
          tag  = "2026-10-28"
        }
        storage = {
          homeMountPath = "/home/jovyan/work"
        }
        extraEnv = {
          DB_ENDPOINT                = "${var.database.endpoint}"
          DB_USER                    = "${var.database.user}"
          DB_PASSWORD                = "${var.database.password}"
          MLFLOW_TRACKING_URI        = var.mlflow != null ? "http://${var.mlflow.endpoint}:5000" : null
          MLFLOW_S3_ENDPOINT_URL     = "http://${var.storage.endpoint}"
          AWS_ENDPOINT               = "http://${var.storage.endpoint}"
          AWS_ACCESS_KEY_ID          = "${var.storage.access_key}"
          AWS_SECRET_ACCESS_KEY      = "${var.storage.secret_access_key}"
          AWS_REGION                 = "eu-west-1"
          AWS_ALLOW_HTTP             = "true"
          AWS_S3_ALLOW_UNSAFE_RENAME = "true"
          RAY_ADDRESS                = var.ray != null ? "ray://${var.ray.endpoint}:10001" : null
        }
        profileList = [
          {
            display_name = "Configure seu Ambiente"
            slug         = "jupyter-environment"
            description  = "Informe a quantidade de vCPU, memória (GB) e GPUs do seu servidor Jupyter"
            default      = true
            profile_options = {
              # One number input per resource, rendered by the custom
              # form.html cloned from the jupyterhub-templates repository. Each field posts
              # profile-option-{slug}--{option}--unlisted-choice, so the value
              # the user types is checked against validation_regex and
              # substituted into {value}.
              #
              # Every option keeps one `choices` entry as the default. Without
              # it KubeSpawner raises "Unable to determine a default choice"
              # when a request carries no value for the option (for example a
              # spawn triggered through the REST API), and the custom form
              # omits the field whenever the user leaves the default in place.
              cpu = {
                display_name = "CPU (vCPU)"
                choices = {
                  "1" = {
                    default = true
                    kubespawner_override = {
                      extra_resource_limits     = { cpu = "1" }
                      extra_resource_guarantees = { cpu = "1" }
                    }
                  }
                }
                unlisted_choice = {
                  enabled            = true
                  display_name       = "vCPU"
                  validation_regex   = "^([0-9]+([.][0-9]+)?|[.][0-9]+)$"
                  validation_message = "Informe um número positivo de vCPU, por exemplo 0.5, 1 ou 2.5"
                  kubespawner_override = {
                    extra_resource_limits     = { cpu = "{value}" }
                    extra_resource_guarantees = { cpu = "{value}" }
                  }
                }
              }
              memory = {
                display_name = "Memória (GB)"
                choices = {
                  "1" = {
                    default = true
                    kubespawner_override = {
                      extra_resource_limits     = { memory = "1G" }
                      extra_resource_guarantees = { memory = "1G" }
                    }
                  }
                }
                unlisted_choice = {
                  enabled            = true
                  display_name       = "GB"
                  validation_regex   = "^[1-9][0-9]*$"
                  validation_message = "Informe um número inteiro de GB maior que zero, por exemplo 2, 4 ou 8"
                  kubespawner_override = {
                    extra_resource_limits     = { memory = "{value}G" }
                    extra_resource_guarantees = { memory = "{value}G" }
                  }
                }
              }
              gpu = {
                display_name = "GPU"
                # Rendered as a checkbox: checked sends the "one" choice,
                # unchecked sends nothing and the default "none" applies.
                # There is no unlisted_choice because the cluster nodes expose
                # a single GPU each, so only "0" or "1" makes sense here.
                choices = {
                  # "none" is the default so the module works on clusters
                  # without the NVIDIA device plugin (e.g. kind). It removes
                  # the nvidia.com/gpu request instead of sending 0, which
                  # Kubernetes rejects for extended resources.
                  none = {
                    default = true
                    kubespawner_override = {
                      extra_resource_limits     = { "nvidia.com/gpu" = null }
                      extra_resource_guarantees = { "nvidia.com/gpu" = null }
                      node_selector             = { "nvidia.com/gpu.present" = null }
                      tolerations               = []
                    }
                  }
                  one = {
                    kubespawner_override = merge(
                      {
                        extra_resource_limits     = { "nvidia.com/gpu" = "1" }
                        extra_resource_guarantees = { "nvidia.com/gpu" = "1" }
                      },
                      local.gpu_overrides
                    )
                  }
                }
              }
            }
          }
        ]
      }
      # Exposed through the Istio Gateway like every other component of the stack.
      # The chart ships a native HTTPRoute template; TLS is terminated at the
      # gateway, so no cert-manager annotation is needed here.
      httpRoute = {
        enabled   = true
        hostnames = [local.domain]
        gateway = {
          name      = var.gateway_name
          namespace = var.gateway_namespace
          # sectionName = "https" would pin the route to the TLS listener only,
          # closing the plain-HTTP path that the gateway's own redirect route
          # leaves open (it declares no hostnames, so this more specific route
          # wins on the http:80 listener). It is not set because the chart
          # vendored here only gained that key in 4.4.0, while Argo CD fetches
          # the chart from GitHub at target_revision (v1.7.0 -> chart 4.3.2,
          # whose values schema has additionalProperties: false on
          # httpRoute.gateway). Enabling it here without publishing the bump
          # first makes the Application fail to render.
        }
      }
      cull = {
        every   = 300
        timeout = 1800
        maxAge  = 43200
      }
    }
  }]
}
