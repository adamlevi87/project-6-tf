#!/bin/bash

set -euo pipefail

# Colors for output
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
RESET="\033[0m"

# Help function
show_help() {
  echo -e "${CYAN}Setup EKS Access Script${RESET}"
  echo
  echo -e "${YELLOW}Usage:${RESET} $0 <role-arn> <cluster-name> <region>"
  echo
  echo -e "${YELLOW}Arguments:${RESET}"
  echo -e "  ${GREEN}role-arn     ${RESET}→ Full ARN of the IAM role to assume"
  echo -e "  ${GREEN}cluster-name ${RESET}→ Name of the EKS cluster"
  echo -e "  ${GREEN}region       ${RESET}→ AWS region (e.g., us-east-1)"
  echo
  echo -e "${YELLOW}Example:${RESET}"
  echo -e "  ${GREEN}$0 arn:aws:iam::123456789012:role/my-role my-cluster us-east-1${RESET}"
  echo
}

# Check arguments
if [ $# -ne 3 ]; then
  show_help
  echo -e "${RED}Error: Expected 3 arguments, got $#${RESET}"
  exit 1
fi

# Parse arguments
ROLE_ARN="$1"
CLUSTER_NAME="$2"
REGION="$3"

# Validate role ARN format
if [[ ! "$ROLE_ARN" =~ ^arn:aws:iam::[0-9]{12}:role/.+ ]]; then
  echo -e "${RED}Error: Invalid role ARN format${RESET}"
  echo -e "Expected: arn:aws:iam::ACCOUNT-ID:role/ROLE-NAME"
  echo -e "Got: $ROLE_ARN"
  exit 1
fi

# Help option
if [[ "$ROLE_ARN" == "--help" || "$ROLE_ARN" == "-h" ]]; then
  show_help
  exit 0
fi

echo -e "${CYAN}🔑 Setting up EKS access...${RESET}"
echo -e "${YELLOW}Role:${RESET} $ROLE_ARN"
echo -e "${YELLOW}Cluster:${RESET} $CLUSTER_NAME"
echo -e "${YELLOW}Region:${RESET} $REGION"
echo

# Step 1: Assume the role
echo -e "${CYAN}Step 1: Assuming IAM role...${RESET}"
ASSUME_ROLE_OUTPUT=$(aws sts assume-role \
  --role-arn "$ROLE_ARN" \
  --role-session-name "eks-access-$(date +%s)" \
  --output json)

if [ $? -ne 0 ]; then
  echo -e "${RED}❌ Failed to assume role${RESET}"
  exit 1
fi

echo -e "${GREEN}✅ Successfully assumed role${RESET}"

# Step 2: Extract credentials
echo -e "${CYAN}Step 2: Extracting temporary credentials...${RESET}"

ACCESS_KEY=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.AccessKeyId')
SECRET_KEY=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.SecretAccessKey')
SESSION_TOKEN=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.SessionToken')
EXPIRATION=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.Expiration')

# Validate jq extracted values
if [[ "$ACCESS_KEY" == "null" || "$SECRET_KEY" == "null" || "$SESSION_TOKEN" == "null" ]]; then
  echo -e "${RED}❌ Failed to parse credentials from assume-role output${RESET}"
  echo "Raw output:"
  echo "$ASSUME_ROLE_OUTPUT"
  exit 1
fi

echo -e "${GREEN}✅ Credentials extracted${RESET}"
echo -e "${YELLOW}Expiration:${RESET} $EXPIRATION"

# Step 3: Export credentials
echo -e "${CYAN}Step 3: Setting environment variables...${RESET}"

export AWS_ACCESS_KEY_ID="$ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$SECRET_KEY"
export AWS_SESSION_TOKEN="$SESSION_TOKEN"

echo -e "${GREEN}✅ Environment variables set${RESET}"

# Step 4: Update kubeconfig
echo -e "${CYAN}Step 4: Updating kubeconfig...${RESET}"

aws eks update-kubeconfig \
  --name "$CLUSTER_NAME" \
  --region "$REGION"

if [ $? -ne 0 ]; then
  echo -e "${RED}❌ Failed to update kubeconfig${RESET}"
  exit 1
fi

echo -e "${GREEN}✅ Kubeconfig updated${RESET}"

# Step 5: Test connection
echo -e "${CYAN}Step 5: Testing kubectl connection...${RESET}"

kubectl cluster-info --request-timeout=10s > /dev/null 2>&1

if [ $? -eq 0 ]; then
  echo -e "${GREEN}✅ kubectl connection successful${RESET}"
else
  echo -e "${YELLOW}⚠️  kubectl connection test failed (cluster might be down)${RESET}"
fi

# Step 6: Display summary
echo
echo -e "${CYAN}🎉 Setup complete!${RESET}"
echo
echo -e "${YELLOW}Your session is now configured with:${RESET}"
echo -e "  • Role: $(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.AssumedRoleUser.Arn')"
echo -e "  • Cluster: $CLUSTER_NAME"
echo -e "  • Region: $REGION"
echo -e "  • Expires: $EXPIRATION"
echo

echo -e "${YELLOW}To use these credentials in your current shell, run:${RESET}"
echo -e "${GREEN}export AWS_ACCESS_KEY_ID=\"$ACCESS_KEY\"${RESET}"
echo -e "${GREEN}export AWS_SECRET_ACCESS_KEY=\"$SECRET_KEY\"${RESET}"
echo -e "${GREEN}export AWS_SESSION_TOKEN=\"$SESSION_TOKEN\"${RESET}"
echo

echo -e "${YELLOW}Or source this script's environment:${RESET}"
echo -e "${GREEN}source <($0 $ROLE_ARN $CLUSTER_NAME $REGION)${RESET}"

echo -e "${YELLOW}Test kubectl access:${RESET}"
echo -e "${GREEN}kubectl get nodes${RESET}"