#!/usr/bin/env bash

mkdir -p ~/openssl-ca
cd ~/openssl-ca

##### Creating the CA
# Generate a private key for our self signed CA,
openssl genrsa -out ca.key 2048
# Use the private key to create a cert for our self signed CA, valid for 5 years (CAs can be longer lived than our TLS certs)
openssl req -x509 -new -nodes -key ca.key -subj "/CN=openssl-ca" -days 1825 -out ca.crt

##### Creating our TLS key pair
# Generate the private key for our TLS certificate
openssl genrsa -out tls.key 2048
# Create a CSR (certificate signing request) configuration
cat >csr.conf <<EOF
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[ dn ]
CN = manual.secure-example.com

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = secure-example
DNS.2 = manual.secure-example.com
EOF
# Create the CSR
openssl req -new -key tls.key -out tls.csr -config csr.conf
# Use the CSR and our CA to generate the public key for our TLS certificate, valid for 6 months
openssl x509 -req -in tls.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out tls.crt -days 180 -extfile csr.conf

##### Store the key pair as a secret
# Note: piping the dry-run output of a create statement to an apply makes it easier to update the secret later, without having to delete and recreate
kubectl create secret tls manual-tls --cert=tls.crt --key=tls.key --dry-run=client -o yaml | kubectl apply --record=true -f -

##### Creating and exposing Nginx pod
cat <<EOF | kubectl apply --record=true -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: manual-secure-web
  name: manual-secure-web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: manual-secure-web
  template:
    metadata:
      labels:
        app: manual-secure-web
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
    app: manual-secure-web
  name: manual-secure-web
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: manual-secure-web
EOF

##### Creating ingress with TLS (kubernetes 1.19+)
cat <<EOF | kubectl apply --record=true -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  labels:
    app: manual-secure-web
  name: manual-secure-web
spec:
  tls:
    - hosts:
        - manual.secure-example.com
      secretName: manual-tls
  rules:
    - host: manual.secure-example.com
      http:
        paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: manual-secure-web
              port:
                number: 80
EOF
