#!/usr/bin/env bash
# =============================================================================
# scripts/deploy-helm-local.sh
#
# PURPOSE:
#   Deploy or upgrade the vprofile Helm chart manually from a local machine.
#   Useful for debugging or initial cluster bootstrapping outside of CI/CD.
#
# USAGE:
#   chmod +x scripts/deploy-helm-local.sh
#   ./scripts/deploy-helm-local.sh \
#     --region us-east-2 \
#     --cluster-name vprofile-eks \
#     --registry <ACCOUNT_ID>.dkr.ecr.us-east-2.amazonaws.com \
#     --ecr-repo vprofileapp \
#     --tag 42
# =============================================================================

set -euo pipefail

BLUE='\033[0;34m'; GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}   $*"; }
error() { echo -e "${RED}[ERR]${NC}  $*" >&2; exit 1; }

REGION=""; CLUSTER_NAME=""; REGISTRY=""; ECR_REPO=""; TAG="latest"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --region)       REGION="$2";       shift 2 ;;
    --cluster-name) CLUSTER_NAME="$2"; shift 2 ;;
    --registry)     REGISTRY="$2";     shift 2 ;;
    --ecr-repo)     ECR_REPO="$2";     shift 2 ;;
    --tag)          TAG="$2";          shift 2 ;;
    *) error "Unknown argument: $1" ;;
  esac
done

[[ -z "$REGION" ]]       && error "--region is required"
[[ -z "$CLUSTER_NAME" ]] && error "--cluster-name is required"
[[ -z "$REGISTRY" ]]     && error "--registry is required"
[[ -z "$ECR_REPO" ]]     && error "--ecr-repo is required"

# Authenticate kubectl against the EKS cluster
info "Updating kubeconfig for cluster: ${CLUSTER_NAME}"
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"

# Create/refresh the ECR image pull secret
info "Refreshing ECR pull secret in Kubernetes..."
kubectl create secret docker-registry regcred \
  --docker-server="$REGISTRY" \
  --docker-username=AWS \
  --docker-password="$(aws ecr get-login-password --region "$REGION")" \
  --namespace=default \
  --dry-run=client -o yaml | kubectl apply -f -

ok "ECR pull secret updated."

# Deploy or upgrade the Helm chart
CHART_DIR="$(dirname "$0")/../helm/vprofilecharts"
info "Deploying Helm chart from: ${CHART_DIR}"

helm upgrade --install vprofile-stack "$CHART_DIR" \
  --namespace default \
  --set appimage="${REGISTRY}/${ECR_REPO}" \
  --set apptag="${TAG}" \
  --wait \
  --timeout 5m

ok "Helm chart deployed successfully!"
echo ""
info "Run 'kubectl get pods' to verify pod status."
info "Run 'kubectl get ingress' to find the Ingress address."
