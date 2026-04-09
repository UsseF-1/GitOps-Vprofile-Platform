#!/usr/bin/env bash
# =============================================================================
# scripts/setup-aws-prereqs.sh
#
# PURPOSE:
#   Creates all AWS resources and GitHub Secrets required before the
#   GitOps workflows can run for the first time.
#
# WHAT THIS SCRIPT DOES:
#   1. Creates an IAM user (gitops) with AdministratorAccess
#   2. Creates an S3 bucket for Terraform remote state
#   3. Creates an ECR repository for the Docker image
#   4. Outputs all values that must be stored in GitHub Secrets
#
# PREREQUISITES:
#   - AWS CLI v2 installed and configured with admin credentials
#   - GitHub CLI (gh) installed and authenticated
#   - jq installed
#
# USAGE:
#   chmod +x scripts/setup-aws-prereqs.sh
#   ./scripts/setup-aws-prereqs.sh \
#     --region us-east-2 \
#     --bucket-name vprofile-tf-state-<YOUR_UNIQUE_SUFFIX> \
#     --ecr-repo vprofileapp \
#     --iac-repo <your-github-username>/iac-vprofile \
#     --app-repo <your-github-username>/vprofile-action
# =============================================================================

set -euo pipefail

# ── Colour helpers ────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No colour

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERR]${NC}  $*" >&2; exit 1; }

# ── Argument parsing ──────────────────────────────────────────────
REGION=""
BUCKET_NAME=""
ECR_REPO=""
IAC_REPO=""
APP_REPO=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --region)       REGION="$2";      shift 2 ;;
    --bucket-name)  BUCKET_NAME="$2"; shift 2 ;;
    --ecr-repo)     ECR_REPO="$2";    shift 2 ;;
    --iac-repo)     IAC_REPO="$2";    shift 2 ;;
    --app-repo)     APP_REPO="$2";    shift 2 ;;
    *) error "Unknown argument: $1" ;;
  esac
done

# Validate required arguments
[[ -z "$REGION" ]]      && error "--region is required"
[[ -z "$BUCKET_NAME" ]] && error "--bucket-name is required"
[[ -z "$ECR_REPO" ]]    && error "--ecr-repo is required"
[[ -z "$IAC_REPO" ]]    && error "--iac-repo is required"
[[ -z "$APP_REPO" ]]    && error "--app-repo is required"

# ── Prerequisite checks ───────────────────────────────────────────
command -v aws  &>/dev/null || error "AWS CLI is not installed."
command -v gh   &>/dev/null || error "GitHub CLI (gh) is not installed."
command -v jq   &>/dev/null || error "jq is not installed."

info "All prerequisites found. Starting setup..."

# ── Step 1: Create IAM user ───────────────────────────────────────
IAM_USER="gitops"
info "Creating IAM user: ${IAM_USER}"

aws iam create-user --user-name "$IAM_USER" --region "$REGION" 2>/dev/null || \
  warn "IAM user ${IAM_USER} already exists — skipping creation."

aws iam attach-user-policy \
  --user-name "$IAM_USER" \
  --policy-arn "arn:aws:iam::aws:policy/AdministratorAccess" \
  --region "$REGION"

success "IAM user ${IAM_USER} has AdministratorAccess."

# Create access keys — output is captured for GitHub Secrets
KEY_JSON=$(aws iam create-access-key --user-name "$IAM_USER" --region "$REGION")
ACCESS_KEY_ID=$(echo "$KEY_JSON"     | jq -r '.AccessKey.AccessKeyId')
SECRET_ACCESS_KEY=$(echo "$KEY_JSON" | jq -r '.AccessKey.SecretAccessKey')

success "IAM access keys created."

# ── Step 2: Create S3 bucket for Terraform state ──────────────────
info "Creating S3 bucket: ${BUCKET_NAME} in region ${REGION}"

if [[ "$REGION" == "us-east-1" ]]; then
  # us-east-1 does not accept a LocationConstraint
  aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" 2>/dev/null || warn "Bucket already exists."
else
  aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION" 2>/dev/null || \
    warn "Bucket already exists."
fi

# Enable versioning so we can recover from accidental state corruption
aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled

# Block all public access to the state bucket
aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

success "S3 bucket ${BUCKET_NAME} created with versioning and public access blocked."

# ── Step 3: Create ECR repository ────────────────────────────────
info "Creating ECR repository: ${ECR_REPO}"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGISTRY_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

aws ecr create-repository \
  --repository-name "$ECR_REPO" \
  --region "$REGION" \
  --image-scanning-configuration scanOnPush=true \
  --image-tag-mutability MUTABLE 2>/dev/null || \
  warn "ECR repository ${ECR_REPO} already exists."

success "ECR repository created. URI: ${REGISTRY_URI}"

# ── Step 4: Store GitHub Secrets ──────────────────────────────────
info "Storing secrets in GitHub repo: ${IAC_REPO} (IAC)"

gh secret set AWS_ACCESS_KEY_ID     --body "$ACCESS_KEY_ID"     --repo "$IAC_REPO"
gh secret set AWS_SECRET_ACCESS_KEY --body "$SECRET_ACCESS_KEY" --repo "$IAC_REPO"
gh secret set BUCKET_TF_STATE       --body "$BUCKET_NAME"       --repo "$IAC_REPO"

success "Secrets stored in ${IAC_REPO}."

info "Storing secrets in GitHub repo: ${APP_REPO} (Application)"

gh secret set AWS_ACCESS_KEY_ID     --body "$ACCESS_KEY_ID"     --repo "$APP_REPO"
gh secret set AWS_SECRET_ACCESS_KEY --body "$SECRET_ACCESS_KEY" --repo "$APP_REPO"
gh secret set REGISTRY              --body "$REGISTRY_URI"      --repo "$APP_REPO"

success "Secrets stored in ${APP_REPO}."

# ── Summary ───────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Setup Complete! Summary:${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "  IAM User:       ${YELLOW}${IAM_USER}${NC}"
echo -e "  S3 Bucket:      ${YELLOW}${BUCKET_NAME}${NC}"
echo -e "  ECR Registry:   ${YELLOW}${REGISTRY_URI}${NC}"
echo -e "  ECR Repository: ${YELLOW}${ECR_REPO}${NC}"
echo ""
echo -e "${YELLOW}ACTION REQUIRED:${NC}"
echo -e "  Add the SONAR_TOKEN, SONAR_ORGANIZATION, SONAR_PROJECT_KEY,"
echo -e "  and SONAR_URL secrets manually to the ${APP_REPO} repository"
echo -e "  after setting up your SonarCloud project at https://sonarcloud.io"
echo ""
echo -e "  In terraform/terraform.tf, ensure the backend 'region' matches: ${REGION}"
echo -e "  In terraform/variables.tf, set 'region' default to: ${REGION}"
echo ""
warn "SECURITY: These access keys are stored ONLY in GitHub Secrets."
warn "Do NOT save them locally or commit them to any repository."
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
