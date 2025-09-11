#!/bin/bash
# scripts/migrate-to-local.sh
# Migrates Terraform state from S3 backend to local

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
TF_WORK_DIR="."

show_help() {
  echo -e "${CYAN}Migrate Terraform State to Local Backend${RESET}"
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
  exit 1
fi

echo -e "${CYAN}Migrating Terraform state from REMOTE to LOCAL (${ENV})${RESET}"
echo -e "${YELLOW}Backend config:${RESET} ${BACKEND_CONFIG_FILE}"
echo -e "${YELLOW}Working directory:${RESET} ${TF_WORK_DIR}"
echo

# Check current backend status
if [[ ! -f "${TF_WORK_DIR}/.terraform/terraform.tfstate" ]]; then
  echo -e "${YELLOW}Initializing with remote backend first...${RESET}"
  terraform -chdir="$TF_WORK_DIR" init -backend-config="$BACKEND_CONFIG_FILE"
fi

# Show current remote state info
echo -e "${CYAN}Current remote state info:${RESET}"
REMOTE_RESOURCE_COUNT=$(terraform -chdir="$TF_WORK_DIR" state list | wc -l)
terraform -chdir="$TF_WORK_DIR" state list | head -5
if [[ "$REMOTE_RESOURCE_COUNT" -gt 5 ]]; then
  echo "... and $((REMOTE_RESOURCE_COUNT - 5)) more resources"
fi
echo -e "${YELLOW}Total resources in remote state:${RESET} ${REMOTE_RESOURCE_COUNT}"
echo

# Confirm migration
echo -e "${YELLOW}This will:${RESET}"
echo "1. Download state from S3 to local"
echo "2. Reconfigure Terraform to use local backend"
echo "3. Verify state migration"
echo "4. Remove remote backend configuration"
echo
echo -e "${RED}WARNING:${RESET} After this, GitHub Actions won't be able to access your state!"
echo
read -p "Continue with migration to local? [y/N]: " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo -e "${YELLOW}Migration cancelled.${RESET}"
  exit 0
fi

# Create backup of current local state if it exists
if [[ -f "${TF_WORK_DIR}/terraform.tfstate" ]]; then
  echo -e "${CYAN}Creating backup of existing local state...${RESET}"
  cp "${TF_WORK_DIR}/terraform.tfstate" "${TF_WORK_DIR}/terraform.tfstate.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Migrate to local backend
echo -e "${CYAN}Migrating to local backend...${RESET}"
terraform -chdir="$TF_WORK_DIR" init -migrate-state -force-copy

# Verify migration
echo -e "${CYAN}Verifying migration...${RESET}"
LOCAL_RESOURCE_COUNT=$(terraform -chdir="$TF_WORK_DIR" state list | wc -l)

if [[ "$REMOTE_RESOURCE_COUNT" -eq "$LOCAL_RESOURCE_COUNT" ]]; then
  echo -e "${GREEN}✅ Migration successful!${RESET}"
  echo -e "${YELLOW}Remote resources:${RESET} ${REMOTE_RESOURCE_COUNT}"
  echo -e "${YELLOW}Local resources:${RESET} ${LOCAL_RESOURCE_COUNT}"
  
  # Show local state info
  echo -e "${CYAN}Local state now contains:${RESET}"
  terraform -chdir="$TF_WORK_DIR" state list | head -5
  if [[ "$LOCAL_RESOURCE_COUNT" -gt 5 ]]; then
    echo "... and $((LOCAL_RESOURCE_COUNT - 5)) more resources"
  fi
else
  echo -e "${RED}❌ Migration failed!${RESET}"
  echo -e "${YELLOW}Remote resources:${RESET} ${REMOTE_RESOURCE_COUNT}"
  echo -e "${YELLOW}Local resources:${RESET} ${LOCAL_RESOURCE_COUNT}"
  echo -e "${RED}Resource counts don't match. Check the migration.${RESET}"
  exit 1
fi

echo
echo -e "${GREEN}🎉 State successfully migrated to local backend!${RESET}"
echo -e "${YELLOW}Next steps:${RESET}"
echo "• Your state is now stored locally"
echo "• Remote state backup remains in S3"
echo "• GitHub Actions will NOT be able to access this state"
echo "• Use migrate-to-remote.sh before running CI/CD workflows"
echo "• Remember to commit and push any local changes before migrating back"