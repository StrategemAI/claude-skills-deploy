# Phase 2: Test Framework - Research

**Researched:** 2026-05-22
**Domain:** Bash E2E test modification + static YAML validation script
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01:** On successful completion, do NOT tear down — staging app and production app both remain running. The `trap EXIT` cleanup runs only when the script exits non-zero (failure path). `--keep` flag continues to suppress cleanup on failures as a debugging affordance.

**D-02:** On success, keep both staging and production apps (do not selectively delete the production app). Both are mentioned in the completion summary.

**D-03:** `E2E_SERVER` env var overrides the server alias (default: `vultr-stream`). The existing `--server ALIAS` flag also continues to work, with `--server` taking precedence over `E2E_SERVER`.

**D-04:** `E2E_BASE_DOMAIN` env var overrides the base domain (default: `cicd.streamlinity.com`). The staging/production domains are constructed as `${TEST_PROJECT}-staging.${E2E_BASE_DOMAIN}` and `${TEST_PROJECT}-production.${E2E_BASE_DOMAIN}`.

**D-05:** Script header comment must clearly document both defaults and say "change these for other domains."

**D-06:** Write report to `test/results/YYYYMMDD-HHMMSS.json` (create `test/results/` directory if missing). Report contains: `staging_url`, `project_uuid`, `staging_app_uuid`, `production_app_uuid`, `run_timestamp` (ISO 8601), `server_alias`, `steps` array (each step: `name`, `passed` boolean, `detail` string). Use Python inline to construct and write the JSON.

**D-07:** Write the report just before the final completion summary, whether the test passed or failed (so a failed run also leaves a report for diagnostics).

**D-08:** On success, print a summary block showing: staging URL, report file path, and the exact next command `bash test/cleanup-deployment.sh <report-file>`. Match the visual style of the existing step headers (`═══...═══` border).

**D-09:** Strict minimum — only two checks: (1) YAML parses without error (VALID-01), (2) every job name in every `needs:` list exists as a defined job in the same file (VALID-02). No additional structural checks.

**D-10:** On VALID-02 failure, print the offending `needs:` reference AND the job name that does not exist. Exit code 1. On success, print "OK: YAML syntax valid" and "OK: all needs references resolve" and exit 0.

**D-11:** `validate-workflow.sh` lives at `test/validate-workflow.sh` (alongside `e2e.sh`), not in `scripts/`. It is a standalone script — no library sourcing required.

### Claude's Discretion

- Exact Python inline structure for JSON report construction (flat dict or helper function — whichever is cleaner)
- Whether to accumulate all VALID-02 failures and report them all at once before exiting, or exit on first offending reference

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TEST-01 | Operator can run `bash test/e2e.sh` against a real Coolify server to provision a hello-world staging app and verify it responds to an HTTPS smoke test at `/api/health` | Existing e2e.sh already implements the full 9-step flow; this requirement is satisfied by the existing script — confirm no regression from other changes |
| TEST-02 | E2E test writes a machine-readable test report to `test/results/YYYYMMDD-HHMMSS.json` containing: staging URL, Coolify project UUID, staging app UUID, per-step pass/fail results, and run timestamp | New: requires adding report-writing logic before cleanup runs; Python inline `<<'PY'` heredoc is the established pattern for JSON construction |
| TEST-03 | E2E test does not auto-teardown the deployment on completion — staging app remains running | Requires modifying `cleanup()` to check exit code: only run teardown on non-zero exit; success path exits without deleting resources |
| TEST-04 | E2E test target is fully configurable via env vars: `E2E_SERVER` and `E2E_BASE_DOMAIN` — defaults documented as "change for other domains" | Requires adding env var defaults to Configuration section and wiring them into server alias and domain construction |
| TEST-05 | E2E test script prints a completion summary: staging URL, test report path, and next step | Requires adding a success-path block after step 9 that prints the `═══` bordered summary (only reached on success; cleanup trap prints on exit for failures) |
| VALID-01 | Running `bash test/validate-workflow.sh <path-to-deploy.yml>` reports YAML syntax validity | New standalone script; Python `yaml.safe_load` is the correct tool — same pattern used throughout the codebase |
| VALID-02 | `validate-workflow.sh` checks that every job name referenced in a `needs:` list exists as a defined job in the same workflow — exits non-zero and prints the offending reference if not | Python can extract `jobs` keys and iterate `needs:` lists; straightforward dict traversal |
</phase_requirements>

---

## Summary

Phase 2 modifies one existing file (`test/e2e.sh`) and creates one new file (`test/validate-workflow.sh`). The work is entirely contained within the `test/` directory. No library scripts are modified and no new external dependencies are introduced.

The primary complexity in `test/e2e.sh` is the teardown behaviour change: the current `cleanup()` function runs unconditionally and always tears down resources. The change requires `cleanup()` to inspect exit code — skip teardown on `exit_code=0`, run teardown on `exit_code!=0` (unless `--keep` is set). The JSON report must be written as a step inside the main body (not inside `cleanup()`), so that it captures the final state before the trap fires and is available for the completion summary printout.

`test/validate-workflow.sh` is a clean-room script that does exactly two things: YAML parse check (via `python3 yaml.safe_load`) and `needs:` reference resolution check (via Python dict traversal over `jobs`). The codebase's established Python inline heredoc pattern (`<<'PY'`) applies directly.

**Primary recommendation:** Write all logic in the script body before the `trap EXIT` fires; use Python inline for JSON report construction and YAML parsing; match existing `═══` visual style for the completion summary.

---

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| bash | 4+ | Script execution | Project constraint — all scripts use `#!/usr/bin/env bash` |
| python3 | 3.6+ | YAML parsing + JSON construction | Already used throughout e2e.sh and provision.sh; no new dependency |
| pyyaml | any | `import yaml` in inline python | Already required by e2e.sh prerequisites check |

### Supporting

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `date +%Y%m%d%H%M%S` | Timestamp for report filename | Report path construction |
| `date -u +"%Y-%m-%dT%H:%M:%SZ"` | ISO 8601 UTC timestamp | `run_timestamp` field in JSON report |
| `mkdir -p test/results/` | Create results directory | Before writing report file |

No new packages or installs needed. All dependencies are already listed in e2e.sh's prerequisites block.

---

## Architecture Patterns

### Recommended File Locations

```
test/
├── e2e.sh               # MODIFIED — teardown logic, env vars, report, summary
├── validate-workflow.sh # NEW — standalone YAML + needs-reference checker
├── push-hello-world.sh  # unchanged
├── results/             # NEW directory — created at runtime by e2e.sh
│   └── YYYYMMDD-HHMMSS.json   # written per run
└── hello-world/         # unchanged
```

### Pattern 1: Conditional Teardown in cleanup()

The current `cleanup()` always calls the delete APIs. After this change, the success path skips teardown entirely. The `exit_code` local variable is already captured at the top of `cleanup()` via `local exit_code=$?`.

**Current structure:**
```bash
cleanup() {
  local exit_code=$?
  # ... print results ...
  if $KEEP_ON_EXIT; then
    # ... print manual cleanup commands ...
    exit $exit_code
  fi
  # unconditional delete block
  step "Cleanup"
  # ... delete apps, volumes, doppler project, work dir ...
  exit $exit_code
}
```

**Required change — add success guard after KEEP_ON_EXIT block:**
```bash
cleanup() {
  local exit_code=$?
  # ... print results (unchanged) ...
  if $KEEP_ON_EXIT; then
    # ... unchanged ...
    exit $exit_code
  fi

  # NEW: on success, skip teardown — operator inspects live deployment
  if [ "$exit_code" -eq 0 ]; then
    echo ""
    echo "  Deployment is live. Run cleanup when ready:"
    echo "    bash test/cleanup-deployment.sh <report-file>"
    exit 0
  fi

  step "Cleanup"
  # ... existing delete block unchanged ...
}
```

Note: The completion summary (D-08) is printed in the main script body just before normal exit, NOT inside `cleanup()`. The `cleanup()` function only prints the minimal "still running, cleanup command" message on the success path.

### Pattern 2: E2E Server + Domain Env Var Wiring

Add to the Configuration section of `e2e.sh`, immediately after the existing `E2E_IMAGE` line:

```bash
# ── Configuration ──────────────────────────────────────────────────────────────
# E2E_SERVER:      Coolify server alias to test against.
#                  Default: vultr-stream — change for other servers.
# E2E_BASE_DOMAIN: Base domain for staging/production test URLs.
#                  Default: cicd.streamlinity.com — change for other domains.
E2E_SERVER="${E2E_SERVER:-vultr-stream}"
E2E_BASE_DOMAIN="${E2E_BASE_DOMAIN:-cicd.streamlinity.com}"
```

The `--server` flag must take precedence over `E2E_SERVER`. In the argument-parsing block, `--server` already sets `SERVER_ALIAS`. In the prerequisites block, the fallback to `coolify.json`'s first entry currently fires when `SERVER_ALIAS` is empty. The change: use `E2E_SERVER` as the intermediate default before that fallback:

```bash
# After argument parsing, before coolify_load_server:
# --server flag takes precedence; then E2E_SERVER; then first entry in coolify.json
if [ -z "$SERVER_ALIAS" ]; then
  SERVER_ALIAS="$E2E_SERVER"
fi
```

For domain construction, replace the two hardcoded lines in Step 3:
```bash
# Before (hardcoded):
STAGING_DOMAIN="${TEST_PROJECT}-staging.cicd.streamlinity.com"
PROD_DOMAIN="${TEST_PROJECT}-production.cicd.streamlinity.com"

# After:
STAGING_DOMAIN="${TEST_PROJECT}-staging.${E2E_BASE_DOMAIN}"
PROD_DOMAIN="${TEST_PROJECT}-production.${E2E_BASE_DOMAIN}"
```

### Pattern 3: JSON Report Construction

Write immediately before the completion summary printout. Use the established `python3 - <<'PY'` heredoc pattern for the JSON construction (avoids quoting issues with variable interpolation in JSON strings):

```bash
# ── Write test report ─────────────────────────────────────────────────────────

REPORT_DIR="$SKILL_DIR/test/results"
mkdir -p "$REPORT_DIR"
REPORT_FILE="$REPORT_DIR/${TIMESTAMP}.json"

# Build steps array from RESULTS — each entry is "  ✓ name" or "  ✗ name"
# Pass all RESULTS elements as args to python
python3 - \
  "$REPORT_FILE" \
  "$STAGING_DOMAIN" \
  "${COOLIFY_PROJECT_UUID:-}" \
  "${STG_APP_UUID:-}" \
  "${PRD_APP_UUID:-}" \
  "$TIMESTAMP" \
  "$SERVER_ALIAS" \
  "${RESULTS[@]+"${RESULTS[@]}"}" \
  <<'PY'
import sys, json
from datetime import datetime, timezone

args = sys.argv[1:]
report_file = args[0]
staging_url = "https://" + args[1]
project_uuid = args[2]
staging_app_uuid = args[3]
production_app_uuid = args[4]
ts_raw = args[5]           # YYYYMMDDHHMMSS
server_alias = args[6]
result_lines = args[7:]

# Parse timestamp to ISO 8601
run_timestamp = datetime.strptime(ts_raw, "%Y%m%d%H%M%S").replace(
    tzinfo=timezone.utc).isoformat()

steps = []
for line in result_lines:
    line = line.strip()
    passed = line.startswith("✓")
    name = line[2:].strip() if len(line) > 2 else line
    steps.append({"name": name, "passed": passed, "detail": ""})

report = {
    "run_timestamp": run_timestamp,
    "server_alias": server_alias,
    "staging_url": staging_url,
    "project_uuid": project_uuid,
    "staging_app_uuid": staging_app_uuid,
    "production_app_uuid": production_app_uuid,
    "steps": steps
}

with open(report_file, "w") as f:
    json.dump(report, f, indent=2)
PY

echo "  report written: $REPORT_FILE"
```

**Note on RESULTS array passing:** Bash arrays cannot be passed directly to python3 via heredoc. The cleanest approach is to pass each element as a positional argument (`"${RESULTS[@]+"${RESULTS[@]}"}"` handles the empty-array case under `set -u`). Python receives them as `sys.argv[7:]`.

**Alternative (simpler, Claude's discretion):** Build the JSON incrementally inside a `REPORT_JSON` bash variable using Python's `-c` single-liner for each step, then write at the end. However, the positional args approach is cleaner for an array of variable length.

### Pattern 4: Completion Summary (Success Path)

Add after step 9 (smoke test) completes, before the script's natural exit:

```bash
# ── Completion summary (success path) ─────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════════"
echo " Deployment complete"
echo "═══════════════════════════════════════════════════"
echo "  Staging URL : https://${STAGING_DOMAIN}"
echo "  Report      : $REPORT_FILE"
echo ""
echo "  To clean up:"
echo "    bash test/cleanup-deployment.sh $REPORT_FILE"
echo "═══════════════════════════════════════════════════"
```

This block runs before `exit 0`, which triggers the `cleanup()` trap. Since `cleanup()` will see `exit_code=0` and skip teardown (per D-01), the deployment stays live.

### Pattern 5: validate-workflow.sh Structure

Standalone script — no library sourcing. Uses Python for both checks.

```bash
#!/usr/bin/env bash
# validate-workflow.sh — Check deploy.yml for YAML syntax and valid needs: references.
#
# Usage: bash test/validate-workflow.sh <path-to-deploy.yml>
# Exit 0: both checks pass
# Exit 1: YAML syntax error or unresolved needs: reference
#
# Checks:
#   VALID-01  YAML parses without error
#   VALID-02  every job name in every needs: list exists in the same file

set -euo pipefail

YAML_FILE="${1:-}"
[ -n "$YAML_FILE" ] || { echo "Usage: $0 <path-to-deploy.yml>" >&2; exit 1; }
[ -f "$YAML_FILE" ]  || { echo "ERROR: file not found: $YAML_FILE" >&2; exit 1; }

# VALID-01: YAML syntax
python3 -c "
import yaml, sys
try:
    yaml.safe_load(open(sys.argv[1]))
    print('OK: YAML syntax valid')
except yaml.YAMLError as e:
    print(f'FAIL: YAML syntax error: {e}', file=sys.stderr)
    sys.exit(1)
" "$YAML_FILE"

# VALID-02: needs: references resolve
python3 - "$YAML_FILE" <<'PY'
import yaml, sys

path = sys.argv[1]
data = yaml.safe_load(open(path))
jobs = data.get("jobs", {})
defined = set(jobs.keys())
errors = []

for job_name, job_def in jobs.items():
    needs = job_def.get("needs", [])
    if isinstance(needs, str):
        needs = [needs]
    for dep in needs:
        if dep not in defined:
            errors.append((job_name, dep))

if errors:
    for job_name, dep in errors:
        print(f"FAIL: job '{job_name}' needs '{dep}' which is not defined", file=sys.stderr)
    sys.exit(1)

print("OK: all needs references resolve")
PY
```

**On Claude's discretion (accumulate vs. exit-on-first for VALID-02):** The pattern above accumulates all errors (matches `validate.sh`'s established behaviour for error accumulation). This is preferable — it reports all broken `needs:` references in one pass so the operator fixes them all at once. Consistent with the `validate.sh` pattern in CONVENTIONS.md.

### Anti-Patterns to Avoid

- **Writing the report inside cleanup():** `cleanup()` fires on both success and failure paths; state variables like `COOLIFY_PROJECT_UUID` and `STG_APP_UUID` are populated during the main body, and the trap may fire before they're set if the script exits early. Write the report at the end of the main body, just before the successful exit.
- **Using `echo > file` for JSON construction:** The codebase never uses shell text for JSON/YAML; always use Python inline.
- **Relative paths in validate-workflow.sh:** Follow CONVENTIONS.md — use `SCRIPT_DIR` and absolute paths even in standalone scripts.
- **Checking `$KEEP_ON_EXIT` first before exit_code check in cleanup():** The KEEP_ON_EXIT block must remain first (it already handles both success and failure for debugging). The new exit_code=0 guard comes after it.
- **Forgetting the `set -u` safe array expansion:** Under `set -euo pipefail`, expanding an empty array `"${RESULTS[@]}"` fails. Use `"${RESULTS[@]+"${RESULTS[@]}"}"` or initialise with `RESULTS=()` (already done in e2e.sh).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON construction | Shell string concatenation / printf | Python inline `json.dumps()` | Handles escaping, unicode, nested structures correctly |
| YAML parsing | `grep`/`awk` text parsing | Python `yaml.safe_load()` | YAML has multiline strings, anchors, and quoting rules that shell text munging breaks |
| ISO 8601 timestamp | Shell date format string gymnastics | Python `datetime.isoformat()` | Guaranteed spec-compliant format including timezone offset |
| `needs:` extraction from GitHub Actions YAML | grep/regex on raw text | Python dict traversal after `yaml.safe_load` | YAML `needs:` can be a string OR a list; regex misses both |

**Key insight:** The codebase already uses Python inline for every structured data operation — this phase continues that pattern without exception.

---

## Common Pitfalls

### Pitfall 1: Report Written After cleanup() Fires

**What goes wrong:** If the report-writing code is placed inside `cleanup()`, the trap fires before all step state is accumulated (e.g., on `exit 1` after a failed step, `STG_APP_UUID` may be empty). The report shows incomplete data.

**Why it happens:** `trap EXIT` fires immediately when any `exit` call is reached, including `exit 1` in the middle of the script.

**How to avoid:** Write the report at the end of the main script body (after step 9, before the final `exit 0`). Also write it on failure paths by moving the write logic to the point where the final `RESULTS` array is populated — use D-07's guidance: write "just before the final completion summary."

**Practical approach:** Add a `write_report()` function that is called once in the main body at the end. Then inside `cleanup()`, check `$REPORT_FILE` — if it exists and is non-empty, don't try to write it again.

### Pitfall 2: Bash Array Passing to Python

**What goes wrong:** `"${RESULTS[@]}"` cannot be embedded directly inside a Python heredoc string. Attempting to expand the array inside `<<'PY'` heredoc fails because single-quoted heredoc prevents all variable expansion.

**Why it happens:** `<<'PY'` (with quotes) suppresses bash variable expansion. `<<PY` (without quotes) allows it but requires escaping all `$` signs in the Python code.

**How to avoid:** Pass array elements as positional arguments: `python3 - "${RESULTS[@]}" <<'PY'` and read them as `sys.argv[1:]` in Python. This keeps the heredoc safely single-quoted and the Python cleanly readable.

### Pitfall 3: exit_code=0 Check Ordering in cleanup()

**What goes wrong:** If the `exit_code=0` guard is placed before the `KEEP_ON_EXIT` check, `--keep` has no effect on success — the operator loses the debugging affordance.

**Why it happens:** Inverted condition order.

**How to avoid:** Preserve the KEEP_ON_EXIT block as the first conditional in `cleanup()`. Add the `exit_code=0` guard immediately after it. Per D-01: "The `--keep` flag continues to suppress cleanup on failures as a debugging affordance" — this means `--keep` only affects the failure path; on success the deployment stays live regardless.

### Pitfall 4: validate-workflow.sh Treating needs: String vs List

**What goes wrong:** In GitHub Actions YAML, `needs:` can be either a string (`needs: deploy-staging`) or a list (`needs: [deploy-staging, build]`). If the validator only handles one form, it silently misses broken references.

**Why it happens:** YAML scalar vs. sequence distinction.

**How to avoid:** After `yaml.safe_load`, normalize `needs` with `if isinstance(needs, str): needs = [needs]` before iterating.

### Pitfall 5: TIMESTAMP Used for Both Project Name and Report Filename

**What goes wrong:** The existing `TIMESTAMP=$(date +%Y%m%d%H%M%S)` is used for `TEST_PROJECT`. The report filename also uses `TIMESTAMP`. If the script is modified to regenerate `TIMESTAMP` at the end, the project name and report filename will diverge.

**Why it happens:** Accidental timestamp re-assignment.

**How to avoid:** Do not reassign `TIMESTAMP` anywhere in the script. Use the single `TIMESTAMP` set in the Configuration section for both `TEST_PROJECT` and `REPORT_FILE`.

---

## Code Examples

### Existing Step Structure Reference

```bash
# Source: test/e2e.sh (current codebase)
step() { echo ""; echo "=== $* ==="; }
pass() { PASS=$((PASS+1)); RESULTS+=("  ✓ $*"); echo "  ✓ $*"; }
fail() { FAIL=$((FAIL+1)); RESULTS+=("  ✗ $*"); echo "  ✗ $*" >&2; }
```

### Existing cleanup() Structure

```bash
# Source: test/e2e.sh lines 70-150
cleanup() {
  local exit_code=$?
  echo ""
  echo "═══════════════════════════════════"
  echo " Test Results"
  echo "═══════════════════════════════════"
  for r in "${RESULTS[@]}"; do echo "$r"; done
  echo ""
  echo " Passed: $PASS  Failed: $FAIL"
  echo "═══════════════════════════════════"

  if $KEEP_ON_EXIT; then
    # ... manual cleanup instructions ...
    exit $exit_code
  fi

  # <<< INSERT exit_code=0 guard here >>>

  step "Cleanup"
  # ... API delete calls ...
  exit $exit_code
}
trap cleanup EXIT
```

### Server Alias Resolution Precedence (after change)

```bash
# Source: test/e2e.sh Configuration section (to be added)
E2E_SERVER="${E2E_SERVER:-vultr-stream}"
E2E_BASE_DOMAIN="${E2E_BASE_DOMAIN:-cicd.streamlinity.com}"

# ... argument parsing sets SERVER_ALIAS from --server flag ...

# Then in Prerequisites section, replace:
#   if [ -z "$SERVER_ALIAS" ]; then
#     SERVER_ALIAS=$(python3 ... first entry from coolify.json ...)
# With:
if [ -z "$SERVER_ALIAS" ]; then
  SERVER_ALIAS="$E2E_SERVER"
fi
# The original fallback to coolify.json first-entry is no longer needed
# because E2E_SERVER already has a default value.
```

### Python validate-workflow.sh needs: check

```python
# Handles both string and list forms of needs:
needs = job_def.get("needs", [])
if isinstance(needs, str):
    needs = [needs]
for dep in needs:
    if dep not in defined:
        errors.append((job_name, dep))
```

---

## Environment Availability

Step 2.6: All dependencies are already checked by `test/e2e.sh`'s prerequisites block. No new external dependencies are introduced in Phase 2.

| Dependency | Required By | Available | Notes |
|------------|-------------|-----------|-------|
| bash 4+ | e2e.sh, validate-workflow.sh | Assumed present | Already required by all scripts |
| python3 + pyyaml | e2e.sh (report), validate-workflow.sh | Checked at e2e.sh start | `python3 -c "import yaml"` |
| `test/results/` directory | TEST-02 | Created at runtime | `mkdir -p` in e2e.sh |

No blocking missing dependencies. No new installs required.

---

## Open Questions

1. **Report path: relative vs absolute**
   - What we know: D-06 says `test/results/YYYYMMDD-HHMMSS.json` — implies relative to repo root.
   - What's unclear: `SKILL_DIR` in e2e.sh resolves to the repo root (`$(dirname "${BASH_SOURCE[0]}")/..`). Using `$SKILL_DIR/test/results/` gives an absolute path, which is safer.
   - Recommendation: Use `$SKILL_DIR/test/results/$TIMESTAMP.json` for the report file. The displayed path in the completion summary can be shown as-is (absolute paths are unambiguous).

2. **Completion summary placement: before or after writing results in cleanup()**
   - What we know: The completion summary (D-08) should print staging URL, report path, and cleanup command. The cleanup() function prints the test results table.
   - What's unclear: Does the completion summary print in the main body before exit, or in cleanup() after the results table?
   - Recommendation: Main body prints the completion summary; cleanup() prints the results table (unchanged) then the "deployment is live" message. Both are visible in the terminal on success — results table from cleanup(), then the "Deployment complete" summary from the main body (printed first, before `exit 0` fires the trap). Actually the trap fires AFTER the main body output, so: main body prints summary → `exit 0` → cleanup() runs → prints results table. Order may look inverted. The cleaner approach is: move the completion summary into cleanup() after the results table, on the `exit_code=0` branch. This ensures it appears after the results.

3. **RESULTS array empty-expansion safety in python3 call**
   - What we know: `set -euo pipefail` means unset variables cause errors.
   - What's unclear: `"${RESULTS[@]}"` when array is empty.
   - Recommendation: Initialise `RESULTS=()` at declaration (already done in e2e.sh) and use `"${RESULTS[@]+"${RESULTS[@]}"}"` for safe expansion in the python3 call arguments.

---

## Sources

### Primary (HIGH confidence)

- `test/e2e.sh` (local codebase) — full existing implementation; all patterns verified by reading the file
- `.planning/codebase/TESTING.md` — E2E test flow, step structure, fixture details
- `.planning/codebase/CONVENTIONS.md` — Python inline heredoc pattern, section dividers, error handling
- `.planning/codebase/STRUCTURE.md` — directory layout, `test/` directory purpose
- `.planning/phases/02-test-framework/02-CONTEXT.md` — locked decisions D-01 through D-11

### Secondary (MEDIUM confidence)

- Python `datetime.isoformat()` for ISO 8601 — standard library; no external verification needed
- GitHub Actions `needs:` can be string or list — documented behaviour; verified by BUG-01 fix context in REQUIREMENTS.md and STATE.md

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all tools already present in codebase; no new dependencies
- Architecture patterns: HIGH — directly derived from reading existing e2e.sh and CONVENTIONS.md
- Pitfalls: HIGH — derived from code reading and bash/python interaction knowledge

**Research date:** 2026-05-22
**Valid until:** 2026-06-22 (stable — pure bash/python, no external library versions to track)
