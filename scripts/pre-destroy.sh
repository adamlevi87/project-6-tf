#!/bin/bash
set -euo pipefail

NAMESPACES=("$@")

if [ ${#NAMESPACES[@]} -eq 0 ]; then
  echo "❌ No namespaces specified. Usage: ./pre-destroy.sh argocd frontend ..."
  exit 1
fi

# Function to delete ArgoCD applications
delete_argocd_apps() {
  local APP_NAME="$1"
  echo "🔍 Checking for ArgoCD application: $APP_NAME"
  
  if kubectl get application "$APP_NAME" -n argocd >/dev/null 2>&1; then
    echo "🗑 Deleting ArgoCD application: $APP_NAME"
    
    # First try graceful deletion
    kubectl delete application "$APP_NAME" -n argocd --timeout=30s || {
      echo "⚠️  Graceful deletion failed, force removing finalizers..."
      kubectl patch application "$APP_NAME" -n argocd -p '{"metadata":{"finalizers":null}}' --type=merge || true
      kubectl delete application "$APP_NAME" -n argocd --cascade=foreground --force --grace-period=0 || true
    }
    
    # Wait a bit for ArgoCD to stop managing resources
    echo "⏳ Waiting for ArgoCD to stop managing resources..."
    sleep 5
  else
    echo "ℹ️  No ArgoCD application found for: $APP_NAME"
  fi
}

for NS in "${NAMESPACES[@]}"; do
  echo "🌐 Processing namespace: $NS"

  # Handle ArgoCD applications for backend/frontend namespaces
  case "$NS" in
    "backend"|"frontend")
      delete_argocd_apps "$NS"
      ;;
    *)
      echo "ℹ️  Namespace $NS: Skipping ArgoCD application check"
      ;;
  esac

  TGBS=$(kubectl get targetgroupbindings.elbv2.k8s.aws -n "$NS" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' || true)
  if [ -z "$TGBS" ]; then
    echo "ℹ️  No TargetGroupBindings found in namespace $NS"
    continue
  fi

  for TGB_NAME in $TGBS; do
    echo "🔍 Found TGB: $TGB_NAME"

    TGB_ARN=$(kubectl get targetgroupbinding "$TGB_NAME" -n "$NS" -o jsonpath='{.spec.targetGroupARN}')
    echo "➡️  TargetGroup ARN: $TGB_ARN"

    LB_ARN=$(aws elbv2 describe-target-groups \
      --target-group-arns "$TGB_ARN" \
      --query 'TargetGroups[0].LoadBalancerArns[0]' \
      --output text)
    echo "➡️  Load Balancer ARN: $LB_ARN"

    LISTENER_ARNS=$(aws elbv2 describe-listeners \
      --load-balancer-arn "$LB_ARN" \
      --query 'Listeners[*].ListenerArn' \
      --output text)

    for LISTENER_ARN in $LISTENER_ARNS; do
      RULES=$(aws elbv2 describe-rules --listener-arn "$LISTENER_ARN" --output json)

      MATCHED_RULE_ARN=$(echo "$RULES" | jq -r \
        --arg TGB_ARN "$TGB_ARN" \
        '.Rules[] | select(.Actions[].TargetGroupArn == $TGB_ARN) | .RuleArn')

      if [[ -n "$MATCHED_RULE_ARN" && "$MATCHED_RULE_ARN" != "null" ]]; then
        echo "🗑 Deleting listener rule: $MATCHED_RULE_ARN"
        aws elbv2 delete-rule --rule-arn "$MATCHED_RULE_ARN"
      fi
    done

    echo "🗑 Deleting TargetGroupBinding: $TGB_NAME"
    kubectl delete targetgroupbinding "$TGB_NAME" -n "$NS" || true
  done

  # kubectl get ingress -A -o json \
  #   | jq -r '.items[] | select(.metadata.finalizers[]? | startswith("group.ingress.k8s.aws/") or startswith("elbv2.k8s.aws/")) | "\(.metadata.namespace) \(.metadata.name)"' \
  #   | while read ns name; do
  #     echo "🛠 Patching finalizer on $ns/$name"
  #     kubectl patch ingress "$name" -n "$ns" -p '{"metadata":{"finalizers":[]}}' --type=merge
  #   done
  for ingress in $(kubectl get ingress -n "$NS" -o name); do
    kubectl delete "$ingress" -n "$NS" --ignore-not-found
  done



  echo "✅ Finished namespace: $NS"
  echo
done

echo "🎉 All specified namespaces cleaned up. You can now safely run: terraform destroy"
