#!/bin/bash
# scripts/enhanced_pre_destroy

set -euo pipefail

# Colors for output
GREEN="\033[1;32m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"

NAMESPACES=("$@")

if [ ${#NAMESPACES[@]} -eq 0 ]; then
  echo "❌ No namespaces specified. Usage: ./enhanced-pre-destroy.sh argocd frontend monitoring..."
  exit 1
fi

# Function to remove finalizers from resources
remove_finalizers() {
  local resource_type="$1"
  local resource_name="$2"
  local namespace="$3"
  
  echo "🛠 Removing finalizers from $resource_type/$resource_name in namespace $namespace"
  kubectl patch "$resource_type" "$resource_name" -n "$namespace" \
    --type='merge' -p='{"metadata":{"finalizers":null}}' || true
}

# Function to force delete stuck resources
force_delete_resource() {
  local resource_type="$1"
  local resource_name="$2"
  local namespace="$3"
  
  echo "🗑 Force deleting $resource_type/$resource_name in namespace $namespace"
  kubectl delete "$resource_type" "$resource_name" -n "$namespace" \
    --grace-period=0 --force --ignore-not-found || true
}

# Function to delete ArgoCD applications
delete_argocd_apps() {
  local APP_NAME="$1"
  echo "🔍 Checking for ArgoCD application: $APP_NAME"
  
  # First suspend the App-of-Apps to stop it from managing anything
  APP_OF_APPS=$(kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep "app-of-apps" | head -1 || true)
  if [ -n "$APP_OF_APPS" ]; then
    echo "🔄 Suspending App-of-Apps: $APP_OF_APPS"
    kubectl patch application "$APP_OF_APPS" -n argocd \
      --type='merge' -p='{"spec":{"syncPolicy":{"automated":null}}}' || true
  fi
  
  # Delete the specific application
  if kubectl get application "$APP_NAME" -n argocd >/dev/null 2>&1; then
    echo "🗑 Deleting ArgoCD application: $APP_NAME"
    kubectl delete application "$APP_NAME" -n argocd --timeout=30s || {
      echo "⚠️  Graceful deletion failed, force removing finalizers..."
      remove_finalizers "application" "$APP_NAME" "argocd"
      force_delete_resource "application" "$APP_NAME" "argocd"
    }
  fi
}

# Function to clean up service accounts
cleanup_service_accounts() {
  local namespace="$1"
  echo "🧹 Cleaning up service accounts in namespace: $namespace"
  
  # Get all service accounts except default
  SA_LIST=$(kubectl get serviceaccounts -n "$namespace" -o jsonpath='{range .items[?(@.metadata.name!="default")]}{.metadata.name}{"\n"}{end}' || true)
  
  for sa in $SA_LIST; do
    if [ -n "$sa" ]; then
      echo "🗑 Deleting service account: $sa"
      kubectl delete serviceaccount "$sa" -n "$namespace" --timeout=30s || {
        echo "⚠️  Force removing finalizers from service account: $sa"
        remove_finalizers "serviceaccount" "$sa" "$namespace"
        force_delete_resource "serviceaccount" "$sa" "$namespace"
      }
    fi
  done
}

# Function to clean up helm releases
cleanup_helm_releases() {
  local namespace="$1"
  echo "🎯 Cleaning up Helm releases in namespace: $namespace"
  
  # List all helm releases in the namespace
  HELM_RELEASES=$(helm list -n "$namespace" -q || true)
  
  for release in $HELM_RELEASES; do
    if [ -n "$release" ]; then
      echo "🗑 Uninstalling Helm release: $release"
      helm uninstall "$release" -n "$namespace" --timeout=60s || {
        echo "⚠️  Helm uninstall failed for $release, attempting manual cleanup"
        
        # Try to delete the release secret
        kubectl delete secret -n "$namespace" -l "owner=helm,name=$release" --ignore-not-found || true
        
        # Remove any stuck resources
        kubectl get all -n "$namespace" -l "app.kubernetes.io/instance=$release" -o name | while read resource; do
          if [ -n "$resource" ]; then
            resource_type=$(echo "$resource" | cut -d'/' -f1)
            resource_name=$(echo "$resource" | cut -d'/' -f2)
            remove_finalizers "$resource_type" "$resource_name" "$namespace"
            force_delete_resource "$resource_type" "$resource_name" "$namespace"
          fi
        done
      }
    fi
  done
}

# Function to handle stuck namespaces
force_delete_namespace() {
  local namespace="$1"
  echo "🚨 Force deleting stuck namespace: $namespace"
  
  # Remove finalizers from the namespace itself
  kubectl patch namespace "$namespace" \
    --type='merge' -p='{"metadata":{"finalizers":null}}' || true
  
  # Delete the namespace
  kubectl delete namespace "$namespace" --grace-period=0 --force --ignore-not-found || true
}

# Main cleanup function for each namespace
cleanup_namespace() {
  local NS="$1"
  echo -e "${CYAN}🌐 Processing namespace: $NS${RESET}"

  # Check if namespace exists
  if ! kubectl get namespace "$NS" >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Namespace $NS does not exist, skipping${RESET}"
    return
  fi

  # Handle ArgoCD applications for frontend namespaces
  case "$NS" in
    "frontend")
      delete_argocd_apps "$NS"
      ;;
    *)
      echo "ℹ️  Namespace $NS: Skipping ArgoCD application check"
      ;;
  esac

  # Clean up Helm releases first
  cleanup_helm_releases "$NS"

  # Clean up TargetGroupBindings (from your existing script)
  TGBS=$(kubectl get targetgroupbindings.elbv2.k8s.aws -n "$NS" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' || true)
  if [ -n "$TGBS" ]; then
    for TGB_NAME in $TGBS; do
      echo "🔍 Found TGB: $TGB_NAME"

      TGB_ARN=$(kubectl get targetgroupbinding "$TGB_NAME" -n "$NS" -o jsonpath='{.spec.targetGroupARN}' || true)
      if [ -n "$TGB_ARN" ]; then
        echo "➡️  TargetGroup ARN: $TGB_ARN"

        LB_ARN=$(aws elbv2 describe-target-groups \
          --target-group-arns "$TGB_ARN" \
          --query 'TargetGroups[0].LoadBalancerArns[0]' \
          --output text 2>/dev/null || true)
        
        if [ -n "$LB_ARN" ] && [ "$LB_ARN" != "None" ]; then
          echo "➡️  Load Balancer ARN: $LB_ARN"

          LISTENER_ARNS=$(aws elbv2 describe-listeners \
            --load-balancer-arn "$LB_ARN" \
            --query 'Listeners[*].ListenerArn' \
            --output text 2>/dev/null || true)

          for LISTENER_ARN in $LISTENER_ARNS; do
            if [ -n "$LISTENER_ARN" ]; then
              RULES=$(aws elbv2 describe-rules --listener-arn "$LISTENER_ARN" --output json 2>/dev/null || true)

              MATCHED_RULE_ARN=$(echo "$RULES" | jq -r \
                --arg TGB_ARN "$TGB_ARN" \
                '.Rules[] | select(.Actions[].TargetGroupArn == $TGB_ARN) | .RuleArn' 2>/dev/null || true)

              if [[ -n "$MATCHED_RULE_ARN" && "$MATCHED_RULE_ARN" != "null" ]]; then
                echo "🗑 Deleting listener rule: $MATCHED_RULE_ARN"
                aws elbv2 delete-rule --rule-arn "$MATCHED_RULE_ARN" || true
              fi
            fi
          done
        fi
      fi

      echo "🗑 Deleting TargetGroupBinding: $TGB_NAME"
      kubectl delete targetgroupbinding "$TGB_NAME" -n "$NS" --timeout=30s || {
        remove_finalizers "targetgroupbinding" "$TGB_NAME" "$NS"
        force_delete_resource "targetgroupbinding" "$TGB_NAME" "$NS"
      }
    done
  fi

  # Clean up ingresses
  INGRESSES=$(kubectl get ingress -n "$NS" -o name 2>/dev/null || true)
  for ingress in $INGRESSES; do
    if [ -n "$ingress" ]; then
      ingress_name=$(echo "$ingress" | cut -d'/' -f2)
      echo "🗑 Deleting ingress: $ingress_name"
      kubectl delete "$ingress" -n "$NS" --timeout=30s || {
        remove_finalizers "ingress" "$ingress_name" "$NS"
        force_delete_resource "ingress" "$ingress_name" "$NS"
      }
    fi
  done

  # Clean up service accounts
  cleanup_service_accounts "$NS"

  # Clean up any remaining pods with finalizers
  PODS=$(kubectl get pods -n "$NS" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' || true)
  for pod in $PODS; do
    if [ -n "$pod" ]; then
      POD_FINALIZERS=$(kubectl get pod "$pod" -n "$NS" -o jsonpath='{.metadata.finalizers}' 2>/dev/null || true)
      if [ -n "$POD_FINALIZERS" ] && [ "$POD_FINALIZERS" != "null" ]; then
        echo "🗑 Removing finalizers from pod: $pod"
        remove_finalizers "pod" "$pod" "$NS"
      fi
    fi
  done

  # Wait a bit for cleanup to propagate
  echo "⏳ Waiting 10 seconds for cleanup to propagate..."
  sleep 10

  # Check if namespace is still stuck
  NS_STATUS=$(kubectl get namespace "$NS" -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
  if [ "$NS_STATUS" = "Terminating" ]; then
    echo -e "${YELLOW}⚠️  Namespace $NS is stuck in Terminating state, force deleting...${RESET}"
    force_delete_namespace "$NS"
  fi

  echo -e "${GREEN}✅ Finished namespace: $NS${RESET}"
  echo
}

# Main execution
echo -e "${CYAN}🚀 Enhanced Pre-Destroy Script Starting...${RESET}"
echo -e "${CYAN}📋 Target namespaces: ${NAMESPACES[*]}${RESET}"
echo

for NS in "${NAMESPACES[@]}"; do
  cleanup_namespace "$NS"
done

echo -e "${GREEN}🎉 All specified namespaces cleaned up!${RESET}"
echo -e "${CYAN}💡 You can now safely run: terraform destroy${RESET}"
echo -e "${YELLOW}⚠️  If resources are still stuck, try the manual cleanup commands below:${RESET}"
echo
echo -e "${CYAN}Manual cleanup commands:${RESET}"
echo "# Remove finalizers from stuck namespaces:"
for NS in "${NAMESPACES[@]}"; do
  echo "kubectl patch namespace $NS --type='merge' -p='{\"metadata\":{\"finalizers\":null}}'"
done
echo
echo "# Force delete namespaces:"
for NS in "${NAMESPACES[@]}"; do
  echo "kubectl delete namespace $NS --grace-period=0 --force"
done
