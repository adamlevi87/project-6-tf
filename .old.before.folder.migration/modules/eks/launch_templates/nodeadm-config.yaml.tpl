# yaml-language-server: disable
---
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: ${cluster_name}
    apiServerEndpoint: ${cluster_endpoint}
    certificateAuthority: ${cluster_ca}
    cidr: ${cluster_cidr}
  kubelet:
    config:
      clusterDNS:
        - ${cidrhost(cluster_cidr, 10)}
      clusterDomain: cluster.local
    flags:
      # UPDATED: Dynamic node labels based on node group configuration
%{ for label_key, label_value in node_labels ~}
      - --node-labels=${label_key}=${label_value}
%{ endfor ~}
      - --node-labels=nodegroup-name=${nodegroup_name}
  containerd: {}