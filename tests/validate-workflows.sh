#!/usr/bin/env bash
# =============================================================================
# tests/validate-workflows.sh
#
# PURPOSE:
#   Validates the GitHub Actions workflow YAML files for syntax errors
#   using the 'actionlint' static analysis tool.
#   Also verifies that all required GitHub Secrets are documented.
#
# USAGE:
#   chmod +x tests/validate-workflows.sh
#   ./tests/validate-workflows.sh
# =============================================================================

set -euo pipefail

BLUE='\033[0;34m'; GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[PASS]${NC}  $*"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }

ERRORS=0

# ── Check for actionlint ──────────────────────────────────────────
if ! command -v actionlint &>/dev/null; then
  warn "actionlint not found. Install from: https://github.com/rhysd/actionlint"
  warn "Falling back to basic YAML syntax check with Python..."
  USE_ACTIONLINT=false
else
  USE_ACTIONLINT=true
fi

# ── Validate each workflow file ───────────────────────────────────
WORKFLOW_DIR=".github/workflows"
info "Scanning workflows in: ${WORKFLOW_DIR}"

for file in "${WORKFLOW_DIR}"/*.yml "${WORKFLOW_DIR}"/*.yaml; do
  [[ -f "$file" ]] || continue
  info "Checking: ${file}"

  if [[ "$USE_ACTIONLINT" == "true" ]]; then
    if actionlint "$file" 2>&1; then
      ok "${file} — syntax valid"
    else
      fail "${file} — syntax errors found"
      ((ERRORS++))
    fi
  else
    # Fallback: basic YAML parse with Python
    if python3 -c "import yaml; yaml.safe_load(open('${file}'))" 2>&1; then
      ok "${file} — YAML valid"
    else
      fail "${file} — YAML parse failed"
      ((ERRORS++))
    fi
  fi
done

# ── Check that required secrets are documented in README ──────────
info "Checking that required secrets are documented in README.md..."

REQUIRED_SECRETS=(
  "AWS_ACCESS_KEY_ID"
  "AWS_SECRET_ACCESS_KEY"
  "BUCKET_TF_STATE"
  "REGISTRY"
  "SONAR_TOKEN"
  "SONAR_ORGANIZATION"
  "SONAR_PROJECT_KEY"
  "SONAR_URL"
)

for secret in "${REQUIRED_SECRETS[@]}"; do
  if grep -q "$secret" README.md 2>/dev/null; then
    ok "Secret documented: ${secret}"
  else
    warn "Secret NOT found in README.md: ${secret}"
  fi
done

# ── Check Terraform file formatting ──────────────────────────────
if command -v terraform &>/dev/null; then
  info "Checking Terraform formatting..."
  if terraform fmt -check -recursive terraform/; then
    ok "Terraform files are properly formatted."
  else
    fail "Terraform formatting issues found. Run: terraform fmt -recursive terraform/"
    ((ERRORS++))
  fi
else
  warn "Terraform not found — skipping format check."
fi

# ── Check Helm chart ─────────────────────────────────────────────
if command -v helm &>/dev/null; then
  info "Linting Helm chart..."
  if helm lint helm/vprofilecharts/ 2>&1; then
    ok "Helm chart lint passed."
  else
    fail "Helm chart lint failed."
    ((ERRORS++))
  fi
else
  warn "Helm not found — skipping chart lint."
fi

# ── Summary ───────────────────────────────────────────────────────
echo ""
if [[ "$ERRORS" -eq 0 ]]; then
  echo -e "${GREEN}All checks passed! ✓${NC}"
else
  echo -e "${RED}${ERRORS} check(s) failed. See output above.${NC}"
  exit 1
fi
