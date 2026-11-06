# Changelog

## [1.8.0](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/compare/v1.7.0...v1.8.0) (2026-11-03)


### 🚀 New Features

* expose `oidc.allow_all`, `oidc.allowed_users` and `oidc.blocked_users`. With `use_group_claims = false` the hub has no group claim to authorize against, so `allow_all` decided every login and the module hardcoded it to `true` — meaning any identity the provider authenticates, which for SSO Corp is every Magalu employee. The default still matches the previous behaviour, but the posture is now a choice, and a validation rejects the one combination that cannot work (`allow_all = false` with no `allowed_users`), which would otherwise 403 every login.
* support authenticating directly against SSO Corp, without the in-cluster Keycloak federating it. `oidc.client_secret` is now optional so a public client such as `compass_mgc` works, and `oidc.basic_auth` / `oidc.enable_pkce` are exposed. PKCE defaults to on, which a public client needs because there is no secret to bind the code exchange to the login that started it.
* complete a bare username with `user_groups.email_domain` before the Compass lookup. SSO Corp exposes `preferred_username`, not an e-mail, and the Compass API is keyed by e-mail: without this the lookup queried a non-existent member and returned an empty group list, which the form reported as "no group with data access".
* add per-group GCP credentials to the spawn form. Setting `user_groups` makes the hub fetch the member's Compass/Luigi groups after login, offer them in the form, and start the notebook with the selected group's service account key read from Secret Manager. The hub holds the only credential able to read those keys, so a notebook only ever sees the key of the group its user selected.
* derive the Secret Manager secret name from the group slug and project (`AUTOMATION_SERVICE_ACCOUNT_JSONKEY_<GROUP_UPPER>_<PROJECT_UPPER>`), matching the convention the platform already uses. The map only carries `project`, so a group cannot silently point at another group's secret.
* add `oidc.use_group_claims` and `oidc.admin_users`. SSO Corp emits no groups claim, so `allowed_groups` never matched and every login was rejected with 403. With `use_group_claims = false` the hub admits any authenticated employee and authorization comes from the group credential; `admin_users` grants the admin panel without a group claim. The defaults reproduce the previous behaviour exactly.

### 🐛 Bug Fixes

* set `allow_all = true` when `use_group_claims` is false. `check_allowed()` in oauthenticator only admits a user through `allow_all`, `allowed_users`, admin status or a matching `allowed_group`, so with no groups claim every employee got 403 on the OAuth callback. It is merged in its own argument because combining it with the `claim_groups_key` branch gave the ternary two object shapes, which Terraform unified into `map(string)` and coerced the boolean to the string `"true"` — oauthenticator then raises `TraitError` on startup.
* demote a user removed from `oidc.admin_users`. `Authenticator.is_admin()` returns `None`, not `False`, for a user outside the list, and `auth_to_user` only writes `admin` when the value is not `None` — so once promoted, a user kept the admin menu forever. The `post_auth_hook` now returns an explicit `False` when the user is not listed, while leaving a `True` set by `admin_groups` untouched.
* document the prerequisites the module does not create: the group secrets, the `roles/secretmanager.secretAccessor` bindings, and the Kubernetes Secret holding the hub key as `key.json`.

## [1.7.0](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/compare/v1.6.0...v1.7.0) (2026-10-29)


### ⌨️ Code Refactoring

* move the custom KubeSpawner form out of `locals.tf`. The HTML was inlined as a heredoc inside `hub.extraFiles`, which duplicated content owned by the `jupyterhub-templates` repository and made the form impossible to edit without a module release. The `git-clone-templates` initContainer now copies `templates/form.html` into a dedicated `custom-spawner-templates` volume, mounted at `/usr/local/share/jupyterhub/custom_spawner_templates`, which `additional_profile_form_template_paths` already searches before the upstream templates.
* bump the default `target_revision` to `v1.7.0`.

## [1.6.0](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/compare/v1.5.0...v1.6.0) (2026-10-29)


### 🚀 New Features

* render the GPU option as a checkbox instead of a number field. The cluster nodes expose a single GPU each, so only "with" or "without" makes sense: checking it sends the `one` choice (`nvidia.com/gpu: 1`) and leaving it unchecked sends nothing, so the default `none` applies and no GPU is requested.

## [1.5.0](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/compare/v1.4.0...v1.5.0) (2026-10-29)


### 🚀 New Features

* replace the spawner dropdowns with three numeric inputs (CPU, memory in GB and GPUs), so the user types the amount instead of picking a predefined choice. Defaults are 1 vCPU, 1 GB and 0 GPUs (no GPU). A custom `form.html` is shipped through `hub.extraFiles` and registered with `additional_profile_form_template_paths`; the field is only submitted when it differs from the default, so KubeSpawner falls back to the declared default choice.

## [1.4.0](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/compare/v1.3.0...v1.4.0) (2026-10-29)


### 🚀 New Features

* add a GPU option to the KubeSpawner `profile_list`, so users pick CPU, memory and GPU count before the server starts (similar to the Kubeflow notebook form). "Sem GPU" is the default so the module still works on clusters without the NVIDIA device plugin, and the GPU request is removed again when the user switches back to it.
* add the optional `gpu_scheduling` variable (`node_selector` and `tolerations`) applied only to the GPU choices, so pods can land on tainted GPU nodes instead of staying Pending.

### 🔥 Bug Fixes

* render the KubeSpawner spawn form instead of the templates repo `spawn.html`, which posts field names KubeSpawner ignores and hid the cpu/memory profile options.
* keep the namespace out of Istio ambient mode by default; the ztunnel breaks the hub to proxy-api call on port 8001.
* expose JupyterHub through an Istio HTTPRoute with `proxy.service.type: ClusterIP`, closing the plain-HTTP LoadBalancer shortcut.

## [1.3.0](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/compare/v1.2.0...v1.3.0) (2026-07-11)


### 🚀 New Features

* add namespace_labels variable to all modules ([f2a57cc](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/f2a57cc3f5a9d9d467777fb13d8ecb0aa60125d0))
* test elyra ([62461e3](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/62461e3a13cb56f6a3bbad4f7e83fb64b6702ee4))


### 🔥 Bug Fixes

* adjust oauthentication ([c6eb382](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/c6eb3829da48cb091231ac6c99e541ab68192a7f))
* adjust oauthentication ([5a3bf5d](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/5a3bf5d91dac139bcab4ac32279876a818263380))
* adjust output ([05ae117](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/05ae117b61f64eaafe88935ddbf1857b8ba4b4cb))
* adjust output ([32f83fc](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/32f83fc079a6d82d9aca7e1e7eb286056710e7c4))
* adjust output ([40ee5f1](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/40ee5f177f5e8a31cbabf8a1ea3cb358d2b1a401))

## [1.2.0](https://github.com/GersonRS/modern-gitops-stack-module-jupyterhub/compare/v1.1.2...v1.2.0) (2026-02-12)


### 🚀 New Features

* add custom JupyterHub templates and profile_options ([97039b6](https://github.com/GersonRS/modern-gitops-stack-module-jupyterhub/commit/97039b6ba64a205f8f977a4bbfd74ab9f4b460cb))
* adjust workflow ([9b870c8](https://github.com/GersonRS/modern-gitops-stack-module-jupyterhub/commit/9b870c8bd1e4d3afa502cd175b27e274eb3ec73e))

## [1.1.2](https://github.com/GersonRS/modern-gitops-stack-module-jupyterhub/compare/v1.1.1...v1.1.2) (2025-02-08)


### ⌨️ Code Refactoring

* adjust workflows ([1d996de](https://github.com/GersonRS/modern-gitops-stack-module-jupyterhub/commit/1d996de1484f7023d6302bf83217d0333528beb7))
* try adjust code 5 ([d2480d6](https://github.com/GersonRS/modern-gitops-stack-module-jupyterhub/commit/d2480d62bd7bd177bd8339c22d67f65109ad8dd3))

## [1.1.1](https://github.com/GersonRS/modern-gitops-stack-module-jupyterhub/compare/v1.1.0...v1.1.1) (2025-02-08)


### 📚 Documentation

* **terraform-docs:** generate docs and write to README.adoc ([2c74d90](https://github.com/GersonRS/modern-gitops-stack-module-jupyterhub/commit/2c74d9040c1135eae2ba6d63151640adba856fc0))


### ⌨️ Code Refactoring

* adjust workflows ([6695fa0](https://github.com/GersonRS/modern-gitops-stack-module-jupyterhub/commit/6695fa0e310b3523f38979f19f98aa30f8bf804e))
* update pre-commit-hooks config file ([45ee48f](https://github.com/GersonRS/modern-gitops-stack-module-jupyterhub/commit/45ee48fd4621ae76ee8f1a911dd328a9f67d57fe))

## [1.1.0](https://github.com/GersonRS/modern-gitops-stack-module-jupyterhub/compare/v1.0.0...v1.1.0) (2024-05-24)


### 🚀 New Features

* adjust module ([170a768](https://github.com/GersonRS/modern-gitops-stack-module-jupyterhub/commit/170a768a0bdd674d1140b0ad49cbbb857acdee39))
