#!/usr/bin/env bash
# =============================================================================
# tests/test-terraform-plan.sh
#
# PURPOSE:
#   Runs a full Terraform init + validate + plan locally to verify the
#   Terraform configuration is correct before pushing to the GitOps pipeline.
#
# PREREQUISITES:
#   - Terraform >= 1.6.3 installed
#   - AWS credentials configured (aws configure or env vars)
#   - S3 bucket already created for state backend
#
# USAGE:
#   chmod +x tests/test-terraform-plan.sh
#   ./tests/test-terraform-plan.sh --bucket your-tf-state-bucket --region us-east-2
# =============================================================================

set -euo pipefail

BLUE='\033[0;34m'; GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}   $*"; }
error() { echo -e "${RED}[ERR]${NC}  $*" >&2; exit 1; }

BUCKET=""; REGION="us-east-2"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bucket) BUCKET="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    *) error "Unknown argument: $1" ;;
  esac
done

[[ -z "$BUCKET" ]] && error "--bucket (Terraform state S3 bucket) is required."
command -v terraform &>/dev/null || error "Terraform is not installed."

TF_DIR="$(cd "$(dirname "$0")/../terraform" && pwd)"
info "Running Terraform tests in: ${TF_DIR}"
cd "$TF_DIR"

# ── Init ──────────────────────────────────────────────────────────
info "Initializing Terraform backend (S3: ${BUCKET})..."
terraform init -backend-config="bucket=${BUCKET}" -reconfigure -input=false
ok "Terraform init complete."

# ── Format check ─────────────────────────────────────────────────
info "Checking Terraform formatting..."
terraform fmt -check || {
  echo ""
  error "Terraform files are not properly formatted. Run: terraform fmt"
}
ok "Format check passed."

# ── Validate ──────────────────────────────────────────────────────
info "Validating Terraform configuration..."
terraform validate
ok "Validation passed."

# ── Plan ──────────────────────────────────────────────────────────
info "Running Terraform plan (this queries AWS — may take 1-2 minutes)..."
terraform plan -no-color -input=false -out=/tmp/vprofile-testplan
ok "Terraform plan complete. Review the output above before merging to main."

echo ""
echo -e "${GREEN}All Terraform tests passed! ✓${NC}"
echo -e "You can now commit to the 'staging' branch and let the workflow validate it."
