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
        extraVolumes = [
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
        ]
        extraVolumeMounts = [
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
        ]
        extraConfig = {
          templates = "c.JupyterHub.template_paths = ['/usr/local/share/jupyterhub/custom_templates/']"
          # The three numeric spawn fields are rendered by form.html, which the
          # git-clone-templates initContainer copies from the jupyterhub-templates
          # repository into the custom-spawner-templates volume. KubeSpawner
          # looks for it in additional_profile_form_template_paths before falling
          # back to its own templates/ directory, so the dropdowns are replaced
          # by plain number inputs.
          profileForm = "c.KubeSpawner.additional_profile_form_template_paths = ['/usr/local/share/jupyterhub/custom_spawner_templates']"
        }
        extraEnv = {
          OAUTH_TLS_VERIFY = "0"
        }
        config = {
          GenericOAuthenticator = {
            login_service      = "keycloak"
            client_id          = "${var.oidc.client_id}"
            client_secret      = "${var.oidc.client_secret}"
            oauth_callback_url = "https://${local.domain}/hub/oauth_callback"
            authorize_url      = "${var.oidc.oauth_url}"
            token_url          = "${var.oidc.token_url}"
            userdata_url       = "${var.oidc.api_url}"
            username_key       = "preferred_username"
            scope              = ["openid", "email", "groups"]
            userdata_params    = { state = "state" }
            claim_groups_key   = "groups"
            allowed_groups     = ["user", "modern-gitops-stack-admins"]
            admin_groups       = ["modern-gitops-stack-admins"]
            manage_groups      = true
          }
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
