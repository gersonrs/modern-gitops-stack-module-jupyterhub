# Changelog

## [1.9.0](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/compare/v1.7.0...v1.9.0) (2026-11-06)


### 🚀 New Features

* per-group GCP credentials in the spawn form. Setting `user_groups` makes the hub fetch the member's Compass/Luigi groups after login, offer them in the form, and start the notebook with the selected group's service account key read from Secret Manager. The hub holds the only credential able to read those keys, so a notebook only ever sees the key of the group its user selected.
* derive the Secret Manager secret name from the group slug and project (`AUTOMATION_SERVICE_ACCOUNT_JSONKEY_<GROUP_UPPER>_<PROJECT_UPPER>`), so a group cannot point at another group's secret.
* authenticate directly against SSO Corp. `oidc.client_secret` is optional for a public client such as `compass_mgc`, `oidc.basic_auth` and `oidc.enable_pkce` are exposed, and PKCE defaults to on.
* `oidc.use_group_claims`, `oidc.allow_all`, `oidc.allowed_users`, `oidc.blocked_users` and `oidc.admin_users` make the login posture a choice instead of a hardcoded `true`.
* `user_groups.email_domain` completes a bare username before the Compass lookup, because SSO Corp exposes `preferred_username` rather than an e-mail.

### 🐛 Bug Fixes

* set `allow_all = true` when `use_group_claims` is false. `check_allowed()` only admits a user through `allow_all`, `allowed_users`, admin status or a matching `allowed_group`, so with no groups claim every login returned 403.
* keep `allow_all` a boolean. Merging it in the same ternary as `claim_groups_key` gave Terraform two object shapes, which it unified into `map(string)` and coerced `true` to `"true"`; oauthenticator then raised `TraitError` at startup.
* demote a user removed from `oidc.admin_users`. `is_admin()` returns `None`, not `False`, and `auth_to_user` only writes `admin` when the value is not `None`, so a promoted user stayed admin forever.
* document the prerequisites the module does not create: the group secrets, the `roles/secretmanager.secretAccessor` bindings, and the Kubernetes Secret holding the hub key as `key.json`.

* add custom JupyterHub templates and profile_options ([97039b6](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/97039b6ba64a205f8f977a4bbfd74ab9f4b460cb))
* add GPU option to the JupyterHub spawner profile list ([4ddd3a1](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/4ddd3a1a6ffaf3226d5a191261b45f037bb20cac))
* add namespace_labels variable to all modules ([f2a57cc](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/f2a57cc3f5a9d9d467777fb13d8ecb0aa60125d0))
* add per-group GCP credentials to the spawn form ([#11](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/issues/11)) ([257eb2c](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/257eb2c5e69f134dc1664bc9300a7025f79dc7b5))
* adjust module ([170a768](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/170a768a0bdd674d1140b0ad49cbbb857acdee39))
* adjust workflow ([9b870c8](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/9b870c8bd1e4d3afa502cd175b27e274eb3ec73e))
* render the GPU option as a checkbox ([7af5ad8](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/7af5ad8395b35fcbc8b3a76c670c353df60ce63e))
* test elyra ([62461e3](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/62461e3a13cb56f6a3bbad4f7e83fb64b6702ee4))
* use numeric inputs in the JupyterHub spawner form ([01f0f78](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/01f0f78c42311614c7646edb95fcd5b34efca178))


### 🔥 Bug Fixes

* adjust oauthentication ([c6eb382](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/c6eb3829da48cb091231ac6c99e541ab68192a7f))
* adjust oauthentication ([5a3bf5d](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/5a3bf5d91dac139bcab4ac32279876a818263380))
* adjust output ([05ae117](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/05ae117b61f64eaafe88935ddbf1857b8ba4b4cb))
* adjust output ([32f83fc](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/32f83fc079a6d82d9aca7e1e7eb286056710e7c4))
* adjust output ([40ee5f1](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/40ee5f177f5e8a31cbabf8a1ea3cb358d2b1a401))


### 📚 Documentation

* **terraform-docs:** generate docs and write to README.adoc ([ee0b45e](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/ee0b45e4718e8fc67fc1e0c2996b25a0f55d60a8))
* **terraform-docs:** generate docs and write to README.adoc ([f99f194](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/f99f1941bff93f06e2fdc052d6fef9a3d953e5cd))
* **terraform-docs:** generate docs and write to README.adoc ([2c74d90](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/2c74d9040c1135eae2ba6d63151640adba856fc0))
* **terraform-docs:** gerar docs e escrever no README.adoc ([185b5d8](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/185b5d84d1acdf369ccd329684202a90076485ae))
* **terraform-docs:** gerar docs e escrever no README.adoc ([1eb42c4](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/1eb42c4a7c8ab5505c0906a664ae7af438c61b6f))


### ⚙️ Chores

* bump target revision to v1.7.0 ([5ed876a](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/5ed876ac0e2e01d4f34c0fd23e898d2826a3bd29))
* release 1.1.0 ([747d6d9](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/747d6d9ebe58a20a0988919f76a10779bdafaef2))
* release 1.1.0 ([7e1a40d](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/7e1a40d2b66e7abec11e7c47fd625e24869dcb8f))
* release 1.1.1 ([ed95947](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/ed959478d0456e5b227036993eac76c425660ba9))
* release 1.1.1 ([41243e6](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/41243e64876ea50cf6b45f47d2589f54b61c3fb6))
* release 1.1.2 ([c261422](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/c26142297f61d1a7e656aebccc7c9273b3855a1c))
* release 1.1.2 ([57b6898](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/57b689822c29a26cc5fd16f11c160661e0867031))
* release 1.2.0 ([96bcc0e](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/96bcc0e71eb6cae8b6f7a690b0dfc1e49df83173))
* release 1.2.0 ([ba1cddb](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/ba1cddb30a4d67bc7d929e17b2361b000c077b4c))
* release 1.3.0 ([c844e31](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/c844e3196f9661b0d2ab558419ecb71bf3ad5164))
* release 1.3.0 ([0866ea6](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/0866ea6c0ac27306ff72e4389279ca6f42592113))
* release 1.7.0 ([f354c5d](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/f354c5d8a2b5924c930d0577b5d17046aeb558dc))
* release 1.7.0 ([69d20ba](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/69d20ba0b9beaea6d934a9a67af94cc33420787c))
* release 1.8.0 ([ac43947](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/ac439477dbe8a46df8db7006fccaf83f3e60449e))


### ⌨️ Code Refactoring

* adjust workflows ([1d996de](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/1d996de1484f7023d6302bf83217d0333528beb7))
* adjust workflows ([6695fa0](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/6695fa0e310b3523f38979f19f98aa30f8bf804e))
* load spawner form from jupyterhub-templates repo ([2ddd42c](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/2ddd42cf137a1b011a8c4f9addf03cb6f182dabd))
* try adjust code 5 ([d2480d6](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/d2480d62bd7bd177bd8339c22d67f65109ad8dd3))
* update pre-commit-hooks config file ([c3140f4](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/c3140f43dc09406ecb5ae0ac1f8922ef59d91e97))
* update pre-commit-hooks config file ([45ee48f](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/45ee48fd4621ae76ee8f1a911dd328a9f67d57fe))

## [1.9.0](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/compare/v1.7.0...v1.9.0) (2026-11-03)


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
