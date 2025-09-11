#!/bin/bash
# scripts/migrate-to-remote.sh
# Migrates Terraform state from local to S3 backend

set -euo pipefail

# Colors for output
GREEN="\033[1;32m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"

# Arguments
ENV="${1:-dev}"
BACKEND_CONFIG_FILE="../environments/${ENV}/backend.config"
TF_WORK_DIR="../main"

show_help() {
  echo -e "${CYAN}Migrate Terraform State to Remote Backend${RESET}"
  echo
  echo -e "${YELLOW}Usage:${RESET} $0 [env]"
  echo -e "${YELLOW}Arguments:${RESET}"
  echo -e "  ${GREEN}env${RESET} → Environment (dev/staging/prod). Default: ${CYAN}dev${RESET}"
  echo
  echo -e "${YELLOW}Example:${RESET}"
  echo -e "  ${GREEN}$0 dev${RESET}"
  echo
}

# Help option
if [[ "$ENV" == "--help" || "$ENV" == "-h" ]]; then
  show_help
  exit 0
fi

# Validate environment
if [[ "$ENV" != "dev" && "$ENV" != "staging" && "$ENV" != "prod" ]]; then
  echo -e "${RED}ERROR:${RESET} Invalid environment '${ENV}'. Use 'dev', 'staging', or 'prod'."
  exit 1
fi

# Check if backend config exists
if [[ ! -f "$BACKEND_CONFIG_FILE" ]]; then
  echo -e "${RED}ERROR:${RESET} Backend config file '${BACKEND_CONFIG_FILE}' not found!"
  echo -e "${YELLOW}Create the file with:${RESET}"
  echo "bucket         = \"your-tf-state-bucket\""
  echo "key            = \"project-6-tf/${ENV}/terraform.tfstate\""
  echo "region         = \"us-east-1\""
  echo "dynamodb_table = \"your-terraform-locks\""
  echo "encrypt        = true"
  exit 1
fi

# Check if local state exists
if [[ ! -f "${TF_WORK_DIR}/terraform.tfstate" ]]; then
  echo -e "${RED}ERROR:${RESET} No local terraform.tfstate found in ${TF_WORK_DIR}!"
  echo "Either run 'terraform init' and create some resources, or migrate from remote first."
  exit 1
fi

echo -e "${CYAN}Migrating Terraform state from LOCAL to REMOTE (${ENV})${RESET}"
echo -e "${YELLOW}Backend config:${RESET} ${BACKEND_CONFIG_FILE}"
echo -e "${YELLOW}Working directory:${RESET} ${TF_WORK_DIR}"
echo

# Show current state info
echo -e "${CYAN}Current local state info:${RESET}"
terraform -chdir="$TF_WORK_DIR" state list | head -5
RESOURCE_COUNT=$(terraform -chdir="$TF_WORK_DIR" state list | wc -l)
echo -e "${YELLOW}Total resources in local state:${RESET} ${RESOURCE_COUNT}"
echo

# Confirm migration
echo -e "${YELLOW}This will:${RESET}"
echo "1. Initialize Terraform with remote backend"
echo "2. Copy local state to S3"
echo "3. Verify state migration"
echo "4. Create local state backup"
echo
read -p "Continue with migration? [y/N]: " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo -e "${YELLOW}Migration cancelled.${RESET}"
  exit 0
fi

# Create backup of local state
echo -e "${CYAN}Creating backup of local state...${RESET}"
cp "${TF_WORK_DIR}/terraform.tfstate" "${TF_WORK_DIR}/terraform.tfstate.backup.$(date +%Y%m%d_%H%M%S)"

# Initialize with backend config
echo -e "${CYAN}Initializing Terraform with remote backend...${RESET}"
terraform -chdir="$TF_WORK_DIR" init -backend-config="$BACKEND_CONFIG_FILE" -migrate-state -force-copy

# Verify migration
echo -e "${CYAN}Verifying migration...${RESET}"
REMOTE_RESOURCE_COUNT=$(terraform -chdir="$TF_WORK_DIR" state list | wc -l)

if [[ "$RESOURCE_COUNT" -eq "$REMOTE_RESOURCE_COUNT" ]]; then
  echo -e "${GREEN}✅ Migration successful!${RESET}"
  echo -e "${YELLOW}Local resources:${RESET} ${RESOURCE_COUNT}"
  echo -e "${YELLOW}Remote resources:${RESET} ${REMOTE_RESOURCE_COUNT}"
  
  # Show remote state info
  echo -e "${CYAN}Remote state now contains:${RESET}"
  terraform -chdir="$TF_WORK_DIR" state list | head -5
  if [[ "$REMOTE_RESOURCE_COUNT" -gt 5 ]]; then
    echo "... and $((REMOTE_RESOURCE_COUNT - 5)) more resources"
  fi
else
  echo -e "${RED}❌ Migration failed!${RESET}"
  echo -e "${YELLOW}Local resources:${RESET} ${RESOURCE_COUNT}"
  echo -e "${YELLOW}Remote resources:${RESET} ${REMOTE_RESOURCE_COUNT}"
  echo -e "${RED}Resource counts don't match. Check your backend configuration.${RESET}"
  exit 1
fi

echo
echo -e "${GREEN}🎉 State successfully migrated to remote backend!${RESET}"
echo -e "${YELLOW}Next steps:${RESET}"
echo "• Your state is now stored in S3"
echo "• Local state backup saved as terraform.tfstate.backup.*"
echo "• You can now share state with GitHub Actions"
echo "• Use migrate-to-local.sh to switch back when needed"