#!/usr/bin/env bash
# verify-s01-args.sh — Inline unit tests for the --no-cleanup / --keep argument-parsing
#                       block added to test/e2e.sh in M002/S01/T01.
#
# Runs in isolation — does not source the full e2e.sh (which would trigger
# prerequisite checks). Instead it re-evaluates the while-loop block directly
# in a subshell with controlled $@ so the four cases can be asserted cleanly.
#
# Usage:  bash test/verify-s01-args.sh
# Exit:   0 if all 4 cases PASS, 1 if any FAIL.

set -euo pipefail

PASS=0
FAIL=0

pass() { PASS=$((PASS+1)); echo "PASS: $*"; }
fail() { FAIL=$((FAIL+1)); echo "FAIL: $*" >&2; }

# ── Shared argument-parsing snippet (copy of the while-loop in e2e.sh) ────────
# This heredoc is the canonical source of truth for these tests; update it
# whenever the parsing block in e2e.sh changes.

ARG_PARSE_BLOCK='
while [[ $# -gt 0 ]]; do
  case "$1" in
    --server) SERVER_ALIAS="$2"; shift 2 ;;
    --no-cleanup) KEEP_ON_EXIT=true; shift ;;
    --keep)   KEEP_ON_EXIT=true; shift ;;
    *) echo "Unknown argument: $1" >&2
       echo "Usage: bash test/e2e.sh [--server ALIAS] [--no-cleanup] [--keep]" >&2
       exit 1 ;;
  esac
done
'

# ── Case 1: --no-cleanup sets KEEP_ON_EXIT=true ───────────────────────────────

result=$(bash -c "
KEEP_ON_EXIT=false
SERVER_ALIAS=''
set -- --no-cleanup
${ARG_PARSE_BLOCK}
echo \"\$KEEP_ON_EXIT\"
")
if [ "$result" = "true" ]; then
  pass "--no-cleanup sets KEEP_ON_EXIT=true"
else
  fail "--no-cleanup did not set KEEP_ON_EXIT=true (got: '$result')"
fi

# ── Case 2: --keep sets KEEP_ON_EXIT=true ────────────────────────────────────

result=$(bash -c "
KEEP_ON_EXIT=false
SERVER_ALIAS=''
set -- --keep
${ARG_PARSE_BLOCK}
echo \"\$KEEP_ON_EXIT\"
")
if [ "$result" = "true" ]; then
  pass "--keep sets KEEP_ON_EXIT=true"
else
  fail "--keep did not set KEEP_ON_EXIT=true (got: '$result')"
fi

# ── Case 3: no flag leaves KEEP_ON_EXIT=false ─────────────────────────────────

result=$(bash -c "
KEEP_ON_EXIT=false
SERVER_ALIAS=''
set --
${ARG_PARSE_BLOCK}
echo \"\$KEEP_ON_EXIT\"
")
if [ "$result" = "false" ]; then
  pass "no flag leaves KEEP_ON_EXIT=false"
else
  fail "no flag changed KEEP_ON_EXIT (got: '$result', expected 'false')"
fi

# ── Case 4: unknown flag exits non-zero ───────────────────────────────────────

set +e
bash -c "
KEEP_ON_EXIT=false
SERVER_ALIAS=''
set -- --bad-flag
${ARG_PARSE_BLOCK}
" 2>/dev/null
bad_exit=$?
set -e

if [ "$bad_exit" -ne 0 ]; then
  pass "--bad-flag triggers non-zero exit (exit code: $bad_exit)"
else
  fail "--bad-flag did not exit non-zero (exit code: $bad_exit)"
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "Results: $PASS passed, $FAIL failed"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
