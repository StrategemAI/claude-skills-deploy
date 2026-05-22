# Codebase Structure

**Analysis Date:** 2026-05-21

## Directory Layout

```
claude-skills-deploy/           # Repo root = skill install directory
├── SKILL.md                    # Claude Code skill manifest + execution spec
├── CLAUDE.md                   # Project instructions for Claude Code sessions
├── README.md                   # User-facing install + usage guide
├── scripts/                    # Core execution scripts (provision, validate, libs)
│   ├── provision.sh            # Idempotent Coolify + Doppler provisioner
│   ├── validate.sh             # Dry-run pre-flight checker
│   ├── generate-workflow.sh    # Emits .github/workflows/deploy.yml into target repo
│   ├── lib-coolify-api.sh      # Coolify REST API wrapper functions
│   └── lib-doppler-api.sh      # Doppler CLI wrapper functions
├── init/                       # Bootstrap for new repos
│   ├── init.sh                 # Interactive bootstrapper (writes coolify.yaml + deploy.yml)
│   ├── test_init.sh            # Unit tests for init.sh
│   └── templates/
│       ├── coolify.yaml.tmpl   # Token-substituted template for coolify.yaml
│       └── Dockerfile.doppler.snippet  # Reference Doppler ENTRYPOINT pattern
├── examples/                   # Reference coolify.yaml files
│   └── skillmap/
│       └── coolify.yaml        # Live example: skillmap project on vultr-stream
├── test/                       # End-to-end integration test
│   ├── e2e.sh                  # Full provision→deploy→smoke-test with cleanup trap
│   ├── push-hello-world.sh     # Builds + pushes test container to GHCR
│   └── hello-world/            # Minimal nginx test container (port 3000, /api/health)
│       ├── Dockerfile
│       ├── index.html          # Contains "claude-skills-deploy-e2e-ok" sentinel string
│       └── nginx.conf          # Routes /api/health → 200, serves index.html on /
├── docs/                       # Human-readable documentation
│   ├── architecture.md         # Mermaid diagrams: setup flow + end-state component map
│   ├── schema.md               # Full coolify.yaml + coolify.json field reference
│   ├── setup-guide.md          # Per-domain walkthrough with concrete commands
│   └── fork-guide.md           # How to reuse this skill for a new domain
├── references/
│   └── api-reference.md        # Coolify + Doppler REST API endpoint reference
└── .planning/
    └── codebase/               # GSD codebase analysis documents (this directory)
```

## Directory Purposes

**`scripts/`:**
- Purpose: All executable logic. Source-able library files and top-level orchestrators.
- Contains: Two library files (`lib-*.sh`) that export functions; three orchestration scripts that import them
- Key files: `provision.sh` (main workflow), `validate.sh` (pre-flight), `lib-coolify-api.sh` (all Coolify HTTP calls)

**`init/`:**
- Purpose: One-time bootstrapper for a new target repo. Separate from `scripts/` because it is run by humans, not by Claude during provisioning.
- Contains: `init.sh` (interactive CLI), `test_init.sh` (unit tests), `templates/` (file templates)
- Key files: `init/init.sh`, `init/templates/coolify.yaml.tmpl`

**`init/templates/`:**
- Purpose: Source files for generated outputs. `coolify.yaml.tmpl` uses `{{TOKEN}}` placeholders replaced by `init.sh` via inline Python.
- Generated: No — these are source files
- Committed: Yes

**`examples/`:**
- Purpose: Reference `coolify.yaml` files showing real configurations. The `skillmap` example is the live production manifest (Vultr / streamlinity.com).
- Key files: `examples/skillmap/coolify.yaml`

**`test/`:**
- Purpose: End-to-end integration test that exercises the full provision→deploy→smoke-test path against real infrastructure.
- Key files: `test/e2e.sh`, `test/hello-world/Dockerfile`
- Note: `test/hello-world/` is the nginx:alpine container used as the E2E test image. It must be built and pushed to GHCR before the first E2E run (`bash test/push-hello-world.sh`).

**`docs/`:**
- Purpose: Human documentation. Not consumed by any script — reference material only.
- Key files: `docs/architecture.md` (Mermaid diagrams), `docs/schema.md` (authoritative field reference)

**`.planning/codebase/`:**
- Purpose: GSD codebase analysis documents consumed by `/gsd:plan-phase` and `/gsd:execute-phase`
- Generated: Yes (by `/gsd:map-codebase`)
- Committed: Yes

## Key File Locations

**Skill manifest (Claude Code entry point):**
- `SKILL.md`: Defines skill name, allowed tools, argument hint, and complete execution spec that Claude follows when `/setup-coolify` is invoked

**Credentials registry (machine-local, never committed):**
- `~/.claude/coolify.json`: Maps server aliases to `{url, api_key, doppler_account, ssh_host}`. Read by `lib-coolify-api.sh` and `lib-doppler-api.sh`.

**Per-repo deploy manifest (committed to target repo, no secrets):**
- `./coolify.yaml` (in each target repo): Declares `project`, `server` alias, `doppler_project`, `registry.image`, `environments.*`, `env_vars`, and cached `coolify_app_ids`

**Core execution:**
- `scripts/provision.sh`: Main provisioner — sources both libs, orchestrates the full upsert sequence
- `scripts/validate.sh`: Pre-flight validator — runs without side effects, always called first by `provision.sh`
- `scripts/lib-coolify-api.sh`: Defines `coolify_load_server`, `coolify_curl`, `coolify_upsert_project`, `coolify_find_app_by_name`, `coolify_set_app_envs`, `coolify_deploy_app`
- `scripts/lib-doppler-api.sh`: Defines `doppler_load_account`, `doppler_check_key`, `doppler_create_service_token`

**Generated outputs (written into target repos, not this repo):**
- `<target-repo>/coolify.yaml`: Written by `init/init.sh`
- `<target-repo>/.github/workflows/deploy.yml`: Written by `scripts/generate-workflow.sh`

**Reference template:**
- `init/templates/coolify.yaml.tmpl`: Token template for `coolify.yaml`. Tokens: `{{PROJECT}}`, `{{SERVER}}`, `{{DOPPLER_PROJECT}}`, `{{REGISTRY_IMAGE}}`, `{{STAGING_DOMAIN}}`, `{{PROD_DOMAIN}}`, `{{BUILD_CONTEXT}}`, `{{BUILD_DOCKERFILE}}`, `{{ENV_VARS_LIST}}`
- `init/templates/Dockerfile.doppler.snippet`: Reference Dockerfile stanza showing Doppler CLI install + `ENTRYPOINT` pattern. Paste into target app Dockerfiles.

**E2E test:**
- `test/e2e.sh`: Full integration test with `trap EXIT` for unconditional cleanup
- `test/hello-world/nginx.conf`: Serves `/api/health` → HTTP 200, root page contains sentinel `claude-skills-deploy-e2e-ok`

## Naming Conventions

**Files:**
- Shell scripts: `kebab-case.sh`
- Library files prefixed: `lib-<service>-api.sh`
- Templates suffixed: `.tmpl`

**Generated app names in Coolify:**
- Pattern: `${project}-${environment}` (e.g. `skillmap-staging`, `skillmap-production`)

**Generated Doppler service token names:**
- Pattern: `coolify-${project}-${environment}` (e.g. `coolify-skillmap-staging`)

**Docker volume names:**
- Pattern: `${APP_UUID}-doppler-cache`

## Where to Add New Code

**New Coolify API operation:**
- Add function to `scripts/lib-coolify-api.sh`
- Follow pattern: `coolify_curl <METHOD> "/endpoint" "$BODY"` with Python inline for JSON parse

**New Doppler operation:**
- Add function to `scripts/lib-doppler-api.sh`
- Follow pattern: `doppler_cmd <subcommand>` (wraps `doppler "$@"` — no `--account` flag)

**New provisioning step:**
- Add to `scripts/provision.sh`, inside the `for ENV_NAME in staging production` loop if per-environment, or outside it if project-level

**New validate check:**
- Add to `scripts/validate.sh`, using `fail "INVALID:..."` pattern and incrementing `ERRORS`

**New `coolify.yaml` field:**
- Add to template `init/templates/coolify.yaml.tmpl` with a `{{TOKEN}}` placeholder
- Add token to the substitution dict in `init/init.sh`
- Add parsing to the `eval "$(python3 ...)"` block in both `provision.sh` and `validate.sh`
- Document in `docs/schema.md`

**New init prompt:**
- Add `read -rp` prompt in `init/init.sh`
- Add corresponding `{{TOKEN}}` in `init/templates/coolify.yaml.tmpl`

**New example configuration:**
- Add `examples/<project-name>/coolify.yaml`

## Special Directories

**`~/.claude/skills/setup-coolify/`:**
- Purpose: Install location for the skill on the developer's machine. The repo root IS the skill directory — no nesting.
- Generated: No — this is the repo itself, cloned here
- Committed: N/A (local clone)

**`~/.claude/`:**
- Purpose: Claude Code's personal directory. Holds `coolify.json` (credentials) and `skills/` (installed skills).
- The skill assumes this path — all scripts reference `$HOME/.claude/coolify.json` directly.

---

*Structure analysis: 2026-05-21*
