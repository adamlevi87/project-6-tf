# reference_only/${environment}/apps/${project_tag}.yaml
# ⚠️  WARNING: THIS IS A REFERENCE COPY ONLY! ⚠️  
#
# The REAL Project is managed by Terraform (via argocd's helm installation)
# This file exists for:
# 1. Documentation - see what the Project looks like
# 2. Reference - if you need to modify it, update Terraform
# 3. GitOps completeness - everything "visible" in Git
#
# TO MODIFY: Edit modules/gitops/argocd-templates/templates/project.yaml.tpl
# DO NOT: Apply this file directly or ArgoCD will conflict!

apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: ${project_tag}
  namespace: ${argocd_namespace}
spec:
  description: ${project_tag} apps and infra
  sourceRepos:
    - https://github.com/${github_org}/${github_gitops_repo}.git
    - https://github.com/${github_org}/${github_application_repo}.git
  destinations:
    - namespace: '*'
      server: https://kubernetes.default.svc
  namespaceResourceWhitelist:
    - group: external-secrets.io
      kind: SecretStore
    - group: external-secrets.io
      kind: ExternalSecret
    - group: ""
      kind: Secret
    - group: ""
      kind: ServiceAccount
    - group: networking.k8s.io
      kind: Ingress
    - group: ""
      kind: Service
    - group: apps
      kind: Deployment
    - group: "argoproj.io"
      kind: "Application"
    - group: "autoscaling"
      kind: "HorizontalPodAutoscaler"
  clusterResourceWhitelist: []
  orphanedResources:
    warn: true
