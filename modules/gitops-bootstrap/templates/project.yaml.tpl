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
