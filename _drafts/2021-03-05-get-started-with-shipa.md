---
layout: post
title:  "Getting Started with Shipa"
date:   2021-03-05 22:43:38
categories: devops
image: network.png
---

# https://www.shipa.io/development/deploying-applications-on-kubernetes/
# 10G was not enough, blog says minikube with 20G is good
multipass launch --name k3s --cpus 4 --mem 8g --disk 50g


Had to increase storage to avoid 'The node was low on resource: ephemeral-storage.'

waiting for a volume to be created, either by external provisioner "rancher.io/local-path"

```bash
sudo apt-get update
sudo apt-get install curl jq docker.io -y
curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" sh -
mkdir -p ~/.kube && cat /etc/rancher/k3s/k3s.yaml >~/.kube/config && chmod 600 ~/.kube/config

sudo bash -c 'wget -O /usr/local/bin/yq -q https://github.com/mikefarah/yq/releases/download/3.4.1/yq_linux_amd64 && chmod +x /usr/local/bin/yq'
sudo bash -c 'cd /tmp && wget -O ./helm.tgz https://get.helm.sh/helm-v3.4.2-linux-amd64.tar.gz && tar -zxf helm.tgz && mv linux-amd64/helm /usr/local/bin/ && rm -rf linux-amd64 helm.tgz'
sudo bash -c 'kubectl completion bash >/etc/bash_completion.d/kubectl'
sudo bash -c 'helm completion bash >/etc/bash_completion.d/helm'

NAMESPACE=shipa-system
kubectl create ns ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

cat > values.override.yaml << EOF
auth:
  adminUser: brendon@localhost
  adminPassword: SuperSe(retPazzw0rd
metrics:
  image: "gcr.io/shipa-1000/metrics:30m"
shipaCore:
  serviceType: ClusterIP
  ip: 10.43.10.20
service:
  nginx:
    serviceType: ClusterIP
    clusterIP: 10.43.10.10
EOF

helm repo add shipa-charts https://shipa-charts.storage.googleapis.com --force-update
helm upgrade --install shipa shipa-charts/shipa -n $NAMESPACE  --timeout=1000s -f values.override.yaml
```
