#!/usr/bin/env bash
# =============================================================================
# scripts/cleanup.sh
#
# PURPOSE:
#   Cleanly destroys all AWS resources created by this GitOps project,
#   in the correct order to avoid dependency errors.
#
# DESTRUCTION ORDER:
#   1. Uninstall Helm release (removes pods, services, ingress)
#   2. Delete NGINX Ingress Controller (removes the AWS NLB)
#   3. Terraform destroy (removes EKS cluster and VPC)
#   4. (Optional) Delete S3 state bucket and ECR repository
#
# USAGE:
#   chmod +x scripts/cleanup.sh
#   ./scripts/cleanup.sh \
#     --region us-east-2 \
#     --cluster-name vprofile-eks \
#     --bucket-name vprofile-tf-state-<YOUR_SUFFIX> \
#     --tf-dir ./terraform
# =============================================================================

set -euo pipefail

# ── Colour helpers ────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERR]${NC}  $*" >&2; exit 1; }

# ── Argument parsing ──────────────────────────────────────────────
REGION=""
CLUSTER_NAME=""
BUCKET_NAME=""
TF_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --region)       REGION="$2";       shift 2 ;;
    --cluster-name) CLUSTER_NAME="$2"; shift 2 ;;
    --bucket-name)  BUCKET_NAME="$2";  shift 2 ;;
    --tf-dir)       TF_DIR="$2";       shift 2 ;;
    *) error "Unknown argument: $1" ;;
  esac
done

[[ -z "$REGION" ]]       && error "--region is required"
[[ -z "$CLUSTER_NAME" ]] && error "--cluster-name is required"
[[ -z "$BUCKET_NAME" ]]  && error "--bucket-name is required"
[[ -z "$TF_DIR" ]]       && error "--tf-dir is required (path to terraform folder)"

# ── Safety confirmation ───────────────────────────────────────────
echo ""
warn "⚠️  This script will PERMANENTLY DESTROY all infrastructure."
warn "    Cluster: ${CLUSTER_NAME} | Region: ${REGION}"
echo ""
read -rp "Type 'yes-destroy' to confirm: " CONFIRM
[[ "$CONFIRM" != "yes-destroy" ]] && { info "Aborted."; exit 0; }

# ── Step 1: Refresh kubeconfig ────────────────────────────────────
info "Updating kubeconfig for cluster: ${CLUSTER_NAME}"
aws eks update-kubeconfig \
  --region "$REGION" \
  --name "$CLUSTER_NAME" || warn "Could not update kubeconfig — cluster may already be gone."

# ── Step 2: Uninstall Helm release ────────────────────────────────
info "Uninstalling Helm release: vprofile-stack"
helm uninstall vprofile-stack --namespace default 2>/dev/null || \
  warn "Helm release not found — skipping."

success "Helm release removed."

# ── Step 3: Remove NGINX Ingress Controller (deletes the NLB) ─────
info "Deleting NGINX Ingress Controller (this removes the AWS NLB)..."
kubectl delete -f \
  https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/aws/deploy.yaml \
  2>/dev/null || warn "NGINX Ingress Controller not found — skipping."

# Wait for the NLB to be deregistered before Terraform destroy
info "Waiting 60 seconds for NLB de-registration..."
sleep 60
success "Ingress controller removed."

# ── Step 4: Terraform destroy ─────────────────────────────────────
info "Running Terraform destroy in ${TF_DIR}..."

cd "$TF_DIR"

terraform init \
  -backend-config="bucket=${BUCKET_NAME}" \
  -reconfigure

terraform destroy \
  -auto-approve \
  -input=false \
  -parallelism=1

success "Terraform destroy complete. VPC and EKS cluster removed."

# ── Step 5: Optional — delete S3 state bucket ─────────────────────
echo ""
read -rp "Delete S3 state bucket '${BUCKET_NAME}'? [y/N]: " DEL_BUCKET
if [[ "$DEL_BUCKET" =~ ^[Yy]$ ]]; then
  info "Emptying and deleting S3 bucket: ${BUCKET_NAME}"
  aws s3 rm "s3://${BUCKET_NAME}" --recursive
  aws s3api delete-bucket --bucket "$BUCKET_NAME" --region "$REGION"
  success "S3 bucket deleted."
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Cleanup complete! All resources have been removed.${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
warn "Remember to delete the IAM user 'gitops' from the AWS console"
warn "and revoke its access keys if you are done with this project."
