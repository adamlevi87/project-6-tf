#!/bin/bash

set -euo pipefail

# Colors
GREEN="\033[1;32m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"

# Arguments
ENV="${1:-dev}"
RUN_MODE="${2:-plan}"
SELECTION_METHOD="${3:-filter}"
NAT_MODE="${4:-single}"
DEBUG="${5:-normal}"
#GITHUB_TOKEN="${6:-}"
#AWS_PROVIDER="${7:-}"
#AWS_GITHUB_OIDC_ROLE="${8:-}"


# Handle dash as "use default"
[[ "$ENV" == "-" ]] && ENV="dev"
[[ "$RUN_MODE" == "-" ]] && RUN_MODE="plan"
[[ "$SELECTION_METHOD" == "-" ]] && SELECTION_METHOD="filter"
[[ "$NAT_MODE" == "-" ]] && NAT_MODE="single"
[[ "$DEBUG" == "-" ]] && DEBUG="normal"

VAR_FILE="../environments/${ENV}/terraform.tfvars"
VAR_FILE_2="../../../sensitive_variables.tfvars"
TF_WORK_DIR="../main"

show_help() {
  echo -e "${CYAN}Terraform Destroy PLAN Script - Help${RESET}"
  echo
  echo -e "${YELLOW}Usage:${RESET} $0 [env] [run_mode] [selection_method] [nat_mode] [debug]"
  echo -e "${YELLOW}Use '-' to hit the defaults ${RESET}"
  echo
  echo -e "${YELLOW}Arguments:${RESET}"
  echo -e "  ${GREEN}1. env        ${RESET}→ Environment to target.         Default: ${CYAN}dev${RESET}"
  echo -e "                 Options: ${CYAN}dev${RESET}, ${CYAN}staging${RESET}, ${CYAN}prod${RESET}"
  echo -e "  ${GREEN}2. run_mode   ${RESET}→ terraform plan -destroy or terraform destroy.      Default: ${CYAN}plan${RESET}"
  echo -e "                 Options: ${CYAN}plan${RESET},${CYAN}destroy${RESET}"
  echo -e "  ${GREEN}3. selection_method       ${RESET}→ selection method.                 Default: ${CYAN}filter${RESET}"
  echo -e "                 Options: ${CYAN}filter${RESET}, ${CYAN}all${RESET}"
  echo -e "  ${GREEN}4. nat_mode   ${RESET}→ NAT Gateway mode. How many NATs, a single one or per AZ.             Default: ${CYAN}single${RESET}"
  echo -e "                 Options: ${CYAN}single${RESET}, ${CYAN}real${RESET}"
  echo -e "  ${GREEN}5. debug   ${RESET}→ Debug mode, used with run_mode:plan & selection_method: filter to iterate over the filtered terraform resource list one by one       Default: ${CYAN}normal${RESET}"
  echo -e "                 Options: ${CYAN}debug${RESET} (each target), ${CYAN}normal${RESET} (all targets at once)"
  # echo -e "  ${GREEN}6. GITHUB_TOKEN: ${RESET}→ Supply Github Token       Default: ${CYAN}no Default${RESET}"
  # echo -e "  ${GREEN}7. AWS_PROVIDER: ${RESET}→ Supply AWS github provider arn       Default: ${CYAN}no Default${RESET}"
  # echo -e "  ${GREEN}8. AWS_GITHUB_OIDC_ROLE: ${RESET}→ Supply AWS_GITHUB_OIDC_ROLE arn       Default: ${CYAN}no Default${RESET}"
  echo
  echo -e "Example:"
  echo -e "  ${GREEN}$0 dev plan filter single normal ${RESET}"
  #echo -e "  ${GREEN}$0 dev plan filter single normal "token" "provider_arn""github_oidc_role_arn" ${RESET}"
  echo -e "Example 2:"
  echo -e "  ${GREEN}$0 dev destroy all real debug ${RESET}"
  #echo -e "  ${GREEN}$0 dev destroy all real debug "token" "provider_arn" "github_oidc_role_arn" ${RESET}"
  echo
}

# # Required environment variables
# if [[ -z "$GITHUB_TOKEN" || -z "$AWS_PROVIDER" || -z "$AWS_GITHUB_OIDC_ROLE" ]]; then
#   show_help
#   echo "❌ GITHUB_TOKEN and AWS_PROVIDER and AWS_GITHUB_OIDC_ROLE must be set - script moved to using them- similar to the github workflow"
#   exit 1
# fi

# Help option
if [[ "$ENV" == "--help" || "$ENV" == "-h" ]]; then
  show_help
  exit 0
else
  show_help
  echo -e "${YELLOW}Running:${RESET} ${GREEN}$0 $ENV $RUN_MODE $SELECTION_METHOD $NAT_MODE $DEBUG${RESET}"
  #echo -e "${YELLOW}Running:${RESET} ${GREEN}$0 $ENV $RUN_MODE $SELECTION_METHOD $NAT_MODE $DEBUG $GITHUB_TOKEN $AWS_PROVIDER${RESET}"
  echo -e "${YELLOW}Press Enter to continue or Ctrl+C to cancel...${RESET}"
  read -r
fi

# Validate ENV
if [[ "$ENV" != "dev" && "$ENV" != "staging" && "$ENV" != "prod" ]]; then
  echo -e "${RED}ERROR:${RESET} Invalid ENV'${ENV}'. Use 'dev' or 'staging' or 'prod'."
  exit 1
fi

# Validate RUN_MODE
if [[ "$RUN_MODE" != "plan" && "$RUN_MODE" != "destroy" ]]; then
  echo -e "${RED}ERROR:${RESET} Invalid RUN_MODE'${RUN_MODE}'. Use 'plan' or 'destroy'."
  exit 1
fi

# Validate SELECTION_METHOD
if [[ "$SELECTION_METHOD" != "filter" && "$SELECTION_METHOD" != "all" ]]; then
  echo -e "${RED}ERROR:${RESET} Invalid SELECTION_METHOD'${SELECTION_METHOD}'. Use 'filter' or 'all'."
  exit 1
fi

# Validate NAT mode
if [[ "$NAT_MODE" != "single" && "$NAT_MODE" != "real" ]]; then
  echo -e "${RED}ERROR:${RESET} Invalid NAT mode '${NAT_MODE}'. Use 'single' or 'real'."
  exit 1
fi

# Validate Debug
if [[ "$DEBUG" != "debug" && "$DEBUG" != "normal" ]]; then
  echo -e "${RED}ERROR:${RESET} Invalid Debug '${DEBUG}'. Use 'debug' or 'normal'."
  exit 1
fi

# Validate variable file
if [[ ! -f "$VAR_FILE" ]]; then
  echo -e "${RED}ERROR:${RESET} Variable file '${VAR_FILE}' not found!"
  exit 1
fi

# Validate variable file
if [[ ! -f "$VAR_FILE_2" ]]; then
  echo -e "${RED}ERROR:${RESET} Variable file '${VAR_FILE_2}' not found!"
  exit 1
fi

# Validate RUN_MODE
if [[ "$RUN_MODE" == "plan" ]]; then
  COMMAND_RUN_MODE=(plan -destroy)
elif [[ "$RUN_MODE" == "destroy" ]]; then
  COMMAND_RUN_MODE=(destroy -auto-approve)
fi

# # Common vars
# COMMAND_RUN_MODE+=(
#   -var="github_token=${GITHUB_TOKEN}" \
#   -var="aws_iam_openid_connect_provider_github_arn=${AWS_PROVIDER}" \
#   -var="github_oidc_role_arn=${AWS_GITHUB_OIDC_ROLE}"
# )

################ Script starts here ################

if [[ "$SELECTION_METHOD" == "all" ]]; then
  terraform -chdir="$TF_WORK_DIR" "${COMMAND_RUN_MODE[@]}" -var-file="$VAR_FILE" -var-file="$VAR_FILE_2" 

elif [[ "$SELECTION_METHOD" == "filter" ]]; then

  echo -e "${CYAN}Building target list based on NAT mode '${NAT_MODE}'...${RESET}"
  # Base exclude patterns (common to both single and real modes)
  BASE_EXCLUDE_PATTERNS=(
    # The Basics
    # 'data.aws_availability_zones.available'
    # 'module.vpc_network.aws_internet_gateway.igw'
    # 'module.vpc_network.aws_subnet.public_primary\[[^]]+\]'
    # 'module.vpc_network.aws_route_table.public_primary\[[^]]+\]'
    # 'module.vpc_network.aws_route_table_association.public_primary\[[^]]+\]'
    # 'module.vpc_network.aws_eip.nat_primary\[0\]'
    # 'module.vpc_network.aws_nat_gateway.nat_primary\[0\]'
    # 'module.vpc_network.aws_vpc.main'
    # # RDS patterns (slow to create)
    # 'module.vpc_network.aws_subnet.aws_subnet.private\[[^]]+\]'
    # 'module.rds.aws_db_instance.main'
    # 'module.rds.aws_db_subnet_group.main'
    # 'module.rds.data.aws_secretsmanager_secret_version.db_password'
    # 'module.rds.aws_security_group.rds'
    # 'module.secrets.aws_secretsmanager_secret.secrets\[\"rds-password\"\]'
    # 'module.secrets.aws_secretsmanager_secret_version.secrets\[\"rds-password\"\]'
    # 'module.secrets.random_password.generated_passwords\[\"rds-password\"\]'
    # Route53
    'module.route53.aws_route53_zone.this'
    # ACM
    'module.acm.aws_acm_certificate.this'
    'module.acm.aws_route53_record.cert_validation\[[^]]+\]'
    'module.ecr.aws_ecr_lifecycle_policy.this\[[^]]+\]'
    'module.ecr.aws_ecr_repository.this\[[^]]+\]'
    'module.github_oidc.aws_iam_role.github_actions'
    'module.github_oidc.aws_iam_role_policy_attachment.attach_admin_policy'
    'module.github_repo_secrets.github_actions_secret.secrets\[[^]]+\]'
    'module.github_repo_secrets.github_actions_variable.variables\[[^]]+\]'
  )
  #echo -e "${CYAN}after building base...${RESET}"
  # Additional patterns for real mode only
  REAL_MODE_ADDITIONAL_PATTERNS=(
    'module.vpc_network.aws_subnet.public_additional\[[^]]+\]'
    'module.vpc_network.aws_route_table.public_additional\[[^]]+\]'
    'module.vpc_network.aws_route_table_association.public_additional\[[^]]+\]'
    'module.vpc_network.aws_eip.nat_additional\[[^]]+\]'
    'module.vpc_network.aws_nat_gateway.nat_additional\[[^]]+\]'
  )
  #echo -e "${CYAN}after building additional...${RESET}"
  # Check if VPC NAT gateways exist before applying mode-specific logic
  # NAT_GATEWAYS=$(terraform -chdir="$TF_WORK_DIR" state list 2>/dev/null | grep 'module.vpc_network.aws_nat_gateway' || true)
  # if [[ -z "$NAT_GATEWAYS" ]]; then
  #   echo -e "${RED}ERROR:${RESET} No NAT Gateway found in state."
  #   exit 1
  # fi
  #echo -e "${CYAN}echo 1${RESET}"
  if [[ "$NAT_MODE" == "real" ]]; then
    # Exclude ALL NATs + ALL public subnets + their route table associations
    EXCLUDE_PATTERNS=("${BASE_EXCLUDE_PATTERNS[@]}" "${REAL_MODE_ADDITIONAL_PATTERNS[@]}")

  elif [[ "$NAT_MODE" == "single" ]]; then
    echo -e "${YELLOW}Single NAT detected ${RESET}"

    EXCLUDE_PATTERNS=("${BASE_EXCLUDE_PATTERNS[@]}")
  fi
  echo -e "${CYAN}Exclude Patterns: ${EXCLUDE_PATTERNS}...${RESET}"
  # Build grep pattern
  GREP_EXCLUDE=$(IFS="|"; echo "${EXCLUDE_PATTERNS[*]}")

  echo -e "${YELLOW}Exclude regex:${RESET} $GREP_EXCLUDE"
  echo -e "${YELLOW}Remaining state entries after exclusion:${RESET}"
  terraform -chdir="$TF_WORK_DIR" state list | grep -Ev "$GREP_EXCLUDE"

  TARGETS=$(terraform -chdir="$TF_WORK_DIR" state list | \
    grep -Ev "$GREP_EXCLUDE" | \
    sed 's/^/-target=/')

  if [[ -z "$TARGETS" ]]; then
    echo -e "${YELLOW}No targets found to destroy.${RESET}"
    exit 0
  fi

  echo -e "${CYAN}working with targets:${RESET}"
  echo "$TARGETS"

  if [[ "$DEBUG" == "normal" ]]; then
    echo -e "\n${GREEN}======== ${COMMAND_RUN_MODE[*]} (all targets together) ========${RESET}"
    # shellcheck disable=SC2086
    terraform -chdir="$TF_WORK_DIR" "${COMMAND_RUN_MODE[@]}" -var-file="$VAR_FILE" -var-file="$VAR_FILE_2"  $TARGETS
  elif [[ "$DEBUG" == "debug" && "$RUN_MODE" == "plan" ]]; then
    LOG_FILE="dependency_warnings_${ENV}_$(date +%Y%m%d_%H%M%S).log"
    echo -e "${CYAN}Running dependency analysis mode...${RESET}"
    echo -e "${YELLOW}Full terraform output will be logged to: ${LOG_FILE}${RESET}"
    
    DEPENDENCY_VIOLATIONS=0
    # Build single grep pattern with OR conditions - do this ONCE outside the target loop
    COMBINED_EXCLUDE_PATTERN=$(IFS="|"; echo "${EXCLUDE_PATTERNS[*]}")

    for TARGET in $TARGETS; do
        echo -e "\n${GREEN}======== Analyzing: ${TARGET} ========${RESET}"
        
        # Capture terraform plan output
        PLAN_OUTPUT=$(terraform -chdir="$TF_WORK_DIR" "${COMMAND_RUN_MODE[@]}" -var-file="$VAR_FILE" -var-file="$VAR_FILE_2" "$TARGET" 2>&1)
        
        # Log full output
        echo "=== Analysis for $TARGET ===" >> "$LOG_FILE"
        echo "$PLAN_OUTPUT" >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
        
        # Check for dependency violations
        VIOLATION_FOUND=false
        # for EXCLUDE_PATTERN in "${EXCLUDE_PATTERNS[@]}"; do
        #     # Handle regex patterns properly
        #     if echo "$PLAN_OUTPUT" | grep -qE "${EXCLUDE_PATTERN}.*will be destroyed"; then
        #         echo -e "${RED}⚠️  WARNING: ${TARGET} will destroy excluded resource matching: ${EXCLUDE_PATTERN}${RESET}"
        #         echo "VIOLATION: $TARGET -> $EXCLUDE_PATTERN" >> "$LOG_FILE"
        #         VIOLATION_FOUND=true
        #         ((DEPENDENCY_VIOLATIONS++))
        #         break
        #     fi
        # done
        
        # Single grep call per target instead of multiple
        if echo "$PLAN_OUTPUT" | grep -qE "(${COMBINED_EXCLUDE_PATTERN}).*will be destroyed"; then
            echo -e "${RED}⚠️  WARNING: ${TARGET} will destroy one of the excluded resource ${RESET}"
            echo "VIOLATION: $TARGET " >> "$LOG_FILE"
            VIOLATION_FOUND=true
            ((DEPENDENCY_VIOLATIONS++))
        fi

        if [[ "$VIOLATION_FOUND" == "false" ]]; then
            echo -e "${GREEN}✓ Safe to destroy${RESET}"
        fi
    done
    
    echo -e "\n${CYAN}=== DEPENDENCY ANALYSIS SUMMARY ===${RESET}"
    echo -e "Total targets analyzed: $(echo "$TARGETS" | wc -l)"
    echo -e "Dependency violations found: ${DEPENDENCY_VIOLATIONS}"
    echo -e "Detailed log saved to: ${LOG_FILE}"
    
    if [[ $DEPENDENCY_VIOLATIONS -gt 0 ]]; then
        echo -e "${RED}WARNING: Found dependency violations! Review the log before proceeding.${RESET}"
    else
        echo -e "${GREEN}All targets are safe to destroy without affecting excluded resources.${RESET}"
    fi
    # for TARGET in $TARGETS; do
    #   echo -e "\n${GREEN}======== PLAN DESTROY FOR: ${TARGET} ========${RESET}"
    #   terraform -chdir="$TF_WORK_DIR" plan -destroy -var-file="$VAR_FILE" "$TARGET" | GREP_COLOR='1;36' grep --color=always -E "rds|database|$"

      
    #   echo
    #   read -rp "Continue to next target? [Y/n]: " answer
    #   case "$answer" in
    #     [yY][eE][sS]|[yY])
    #       ;;
    #     *) # Anything else, including empty input
    #       echo -e "${YELLOW}Aborting per user request.${RESET}"
    #       exit 0
    #       ;;
    #   esac
    # done
  elif [[ "$DEBUG" == "debug" && "$RUN_MODE" == "destroy" ]]; then
    echo -e "\n${GREEN}========  debug and destroy - doing nothing ========${RESET}"
  fi

else
  echo "Usage: $0 [env=dev|prod|staging] [run_mode=plan|destroy] [selection_method=filter|all] [nat_mode=single|real] [debug=debug|normal]"
  exit 1
fi
