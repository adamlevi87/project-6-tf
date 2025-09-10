server:
  # Service configuration
  service:
    type: ClusterIP
  
  # Service account configuration
  serviceAccount:
    create: false
    name: "${service_account_name}"
  
  # Ingress configuration for AWS ALB
  ingress:
    enabled: true
    ingressClassName: alb
    hostname: "${domain_name}"
    path: /
    pathType: Prefix
    extraAnnotations:
      # This ensures the ALB controller finishes cleaning up before Ingress is deleted
      "kubectl.kubernetes.io/last-applied-configuration": ""  # optional workaround
    annotations:
      # ALB Controller annotations
      alb.ingress.kubernetes.io/scheme: internet-facing
      alb.ingress.kubernetes.io/target-type: ip
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
      alb.ingress.kubernetes.io/ssl-redirect: "443"
      alb.ingress.kubernetes.io/group.name: "${alb_group_name}"
      alb.ingress.kubernetes.io/load-balancer-attributes: idle_timeout.timeout_seconds=60
      alb.ingress.kubernetes.io/security-groups: "${security_group_id}"
      alb.ingress.kubernetes.io/certificate-arn: "${acm_cert_arn}"
      # External DNS annotation (optional - helps external-dns identify the record)
      external-dns.alpha.kubernetes.io/hostname: "${domain_name}"
      # restrictions and rules
      alb.ingress.kubernetes.io/conditions.${release_name}-server: |
            [
              {
                "field":  "source-ip",
                "sourceIpConfig": {
                  "values": ${allowed_cidrs}
                }
              }
            ]

  extraMetadata:
    finalizers:
      - ingress.k8s.aws/resources  
  
  # ArgoCD server configuration
  config:
    # This tells ArgoCD what its external URL is
    url: "https://${domain_name}"
    # openID connect settings
  dex.server.strict.tls: "false"

# Global configuration
global:
  # Ensure ArgoCD knows its domain
  domain: "${domain_name}"

dex:
  extraArgs:
    - --disable-tls

configs:
  params:
    # Enable insecure mode if you're terminating TLS at ALB
    server.insecure: true  
    # Sets dex server (for sso) - communication between argocd-server and argocd-dex-server internally
    server.dex.server: "http://argocd-${environment}-dex-server:5556"
    server.enable.proxy.extension: "true"

  secret:
    create: true
    extra:
        server.secretkey: "${server_secretkey}"
  # RBAC Policy Configuration
  rbac:
    create: true
    policy.default: role:readonly
    policy.csv: |
      p, role:admin, applications, *, */*, allow
      p, role:admin, clusters, *, *, allow
      p, role:admin, repositories, *, *, allow
      p, role:admin, logs, get, *, allow
      p, role:admin, exec, create, */*, allow
      p, role:readonly, applications, get, */*, allow
      p, role:readonly, clusters, get, *, allow
      p, role:readonly, repositories, get, *, allow
      
      # Team to Role Mapping      
      g, ${github_org}-org:${github_admin_team}, role:admin
      g, ${github_org}-org:${github_readonly_team}, role:readonly
  cm:
    url: "https://${domain_name}"
    users.anonymous.enabled: "false"
    dex.config: |
      connectors:
        - type: github
          id: github
          name: GitHub
          config:
            clientID: ${dollar}${argocd_github_sso_secret_name}:clientID
            clientSecret: ${dollar}${argocd_github_sso_secret_name}:clientSecret
            orgs:
              - name: ${github_org}-org

