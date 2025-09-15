# reference_only/${environment}/apps/app_of_apps.yaml
# ⚠️  WARNING: THIS IS A REFERENCE COPY ONLY! ⚠️  
#
# The REAL App of Apps is managed by Terraform (via argocd's helm installation)
# This file exists for:
# 1. Documentation - see what the App of Apps looks like
# 2. Reference - if you need to modify it, update Terraform
# 3. GitOps completeness - everything "visible" in Git
#
# TO MODIFY: Edit modules/gitops/argocd-templates/templates/app_of_apps.yaml.tpl
# DO NOT: Apply this file directly or ArgoCD will conflict!

apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${project_tag}-app-of-apps-${environment}
  namespace: ${argocd_namespace}
  annotations:
    argocd.argoproj.io/sync-wave: "-10"
spec:
  project: ${project_tag}
  source:
    repoURL: https://github.com/${github_org}/${github_gitops_repo}.git
    path: environments/${environment}/${app_of_apps_path}
    targetRevision: ${app_of_apps_target_revision}
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  revisionHistoryLimit: 3
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    retry:
      limit: 20
      backoff:
        duration: 60s
        factor: 2
        maxDuration: 15m
    syncOptions:
      - CreateNamespace=true
      - PruneLast=true
      - PrunePropagationPolicy=background
      - ApplyOutOfSyncOnly=true