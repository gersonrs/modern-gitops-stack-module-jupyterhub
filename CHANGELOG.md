# Changelog

## [1.7.1](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/compare/v1.7.0...v1.7.1) (2026-10-30)


### ⚙️ Chores

* bump target revision to v1.7.0 ([5ed876a](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/5ed876ac0e2e01d4f34c0fd23e898d2826a3bd29))
* release 1.7.0 ([f354c5d](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/f354c5d8a2b5924c930d0577b5d17046aeb558dc))
* release 1.7.0 ([69d20ba](https://github.com/gersonrs/modern-gitops-stack-module-jupyterhub/commit/69d20ba0b9beaea6d934a9a67af94cc33420787c))

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
