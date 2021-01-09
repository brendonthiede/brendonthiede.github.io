#!/usr/bin/env bash

mkdir -p ~/openssl-ca
cd ~/openssl-ca

##### Install cert-manager
kubectl apply --record=true -f https://github.com/jetstack/cert-manager/releases/download/v1.1.0/cert-manager.yaml

##### Creating the CA
# Generate a private key for our self signed CA,
openssl genrsa -out ca.key 2048
# Use the private key to create a cert for our self signed CA, valid for 5 years (CAs can be longer lived than our TLS certs)
openssl req -x509 -new -nodes -key ca.key -subj "/CN=openssl-ca" -days 1825 -out ca.crt

##### Store the key pair as a secret
cat <<EOF | kubectl apply --record=true -f -
apiVersion: v1
kind: Secret
metadata:
  name: ca-key-pair
data:
  tls.crt: $(cat ca.crt | base64 -w0)
  tls.key: $(cat ca.key | base64 -w0)
EOF

##### Wait for cert-manager to be ready
echo "Waiting for cert-manager pods to come up (should take just a few seconds)"
while :; do
  [[ $(kubectl get po -n cert-manager --no-headers --field-selector='status.phase!=Running' 2>/dev/null | wc -l) -eq 0 ]] && break || sleep 1
done


##### Create our CA issuer
cat <<EOF | kubectl apply --record=true -f -
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: ca-issuer
spec:
  ca:
    secretName: ca-key-pair
EOF

##### Creating and exposing Nginx pod
cat <<EOF | kubectl apply --record=true -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: cm-secure-web
  name: cm-secure-web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cm-secure-web
  template:
    metadata:
      labels:
        app: cm-secure-web
    spec:
      containers:
      - image: nginx
        name: nginx
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: cm-secure-web
  name: cm-secure-web
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: cm-secure-web
EOF

##### Creating ingress with TLS (kubernetes 1.19+)
cat <<EOF | kubectl apply --record=true -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    cert-manager.io/issuer: ca-issuer
  labels:
    app: cm-secure-web
  name: cm-secure-web
spec:
  tls:
    - hosts:
        - cm.secure-example.com
      secretName: cm-tls
  rules:
    - host: cm.secure-example.com
      http:
        paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: cm-secure-web
              port:
                number: 80
EOF
