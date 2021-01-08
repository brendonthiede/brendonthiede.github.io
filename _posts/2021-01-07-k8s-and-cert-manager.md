---
layout: post
title:  "Using cert-manager in Kubernetes"
date:   2021-01-08T00:19:29Z
categories: devops
image: security-lock.jpg
---
## TLS - What is it?

[TLS stands for Transport Layer Security](https://en.wikipedia.org/wiki/Transport_Layer_Security), and it represents one of the cornerstones of network security. Any web request that you make while specifying https as the protocol should be using TLS, in particular, [TLS 1.2 or newer](https://docs.microsoft.com/en-us/lifecycle/announcements/transport-layer-security-1x-disablement). Previously, web servers may have used SSL, Secure Socket Layer, in order to encrypt traffic, but SSL is deprecated, although you may still here people refer to SSL out of old habit.

TLS uses [PKI, Public Key Infrastructure](https://en.wikipedia.org/wiki/Public_key_infrastructure), which is a way of allowing a public key and a private key to be used separately to encrypt and decrypt information. There is a lot that goes on during the ["TLS Handshake"](https://www.cloudflare.com/learning/ssl/what-happens-in-a-tls-handshake/), but the concept to keep in mind here is that in order to use TLS, you are going to need a public key, which anyone can have access to ('server hello' in a standard TLS Handshake is one way of distributing it, or you may pre-distribute it in certain scenarios), and a private key, that you protect dearly and never share. In fact, in order to make sure that even if your certificate did get accidentally leaked that it wouldn't be valid forever, certs must have an expiration date no more than [398 days in the future](https://thehackernews.com/2020/09/ssl-tls-certificate-validity-398.html), otherwise browsers may refuse to serve the content.

One last important concept regarding TLS is that of [Certificate Authority](https://en.wikipedia.org/wiki/Certificate_authority), which is how you can not only know that your data is encrypted between you and the server, but that you have confidence that you are actually talking to the real server (see [man-in-the-middle attack](https://us.norton.com/internetsecurity-wifi-what-is-a-man-in-the-middle-attack.html) for more detail). In order for this to all work, there are certain special "Root" Certificate Authorities, or Root CAs, that will be part of every modern operating system and/or web browser, giving the building blocks of trust for every publicly valid cert in the world. It is possible, and sometimes necessary, to use certificates that are not signed by one of these CAs or their intermediates, but it will require some extra work in order to establish trust.

## Why secure your traffic?

It may be obvious that you would want to encrypt sensitive information that a user is sending, such as a form POST containing credit card information (for legal requirements, look into [PCI compliance](https://www.pcisecuritystandards.org/)), but there are other reasons to secure your traffic. For example, if you have a website that loads JavaScript via HTTP, it would be trivial for a bad actor to intercept the traffic and replace it with malicious code. If you whole site is being served over HTTP then it's just that much easier for someone to, for example, mess with DNS and take over your entire site with no one even noticing. Other reasons for using TLS are for the comfort a user has seeing the green padlock in their browser (aesthetic may vary), improving search rank, and taking advantage of HTTP/2, which requires TLS. While the focus here is going to be on securing traffic that is coming out of a Kubernetes cluster, often called "north-south" traffic, keep in mind that there are good reasons for securing the "east-west" traffic that occurs within your cluster. Also be aware that securing east-west traffic with an internal/non-standard CA will likely require installing that CA for every container in your cluster.

## TLS in Kubernetes

### Manual Cert Management

_Note: The `extensions/v1beta1` and `networking.k8s.io/v1beta1` versions of Ingress are deprecated as of Kubernetes 1.19 and are slated to have support removed at some point in Kubernetes 1.22 or later. For Kubernetes 1.19 and later you should use `networking.k8s.io/v1` instead._

Perhaps the easiest way to apply TLS to your outbound traffic is by configuring it as part of an ingress configuration. To do this, you just need the following in you ingress definition:

```yaml
spec:
  tls:
  - hosts:
      - manual.secure-example.com
    secretName: manual-tls
```

This will cause the ingress controller to use the secret (stored in teh same namespace) with the given name, "manual-tls" in the example. The secret will need to contain data for `tls.crt` and `tls.key`, and will be of type `kubernetes.io/tls`. The `tls.crt` will be the base64 encoded contents of the public key, and `tls.key` will be the base64 encoded contents of the private key. You can manually create a secret from key pair files using something like this:

```bash
# Note: piping the dry-run output of a create statement to an apply makes it easier to update the secret later, without having to delete and recreate
kubectl create secret tls manual-tls --cert=tls.crt --key=tls.key --dry-run=client -o yaml | kubectl apply --record=true -f -
```

You can see that I pipe the dry-run output of a create command to an apply command. This is to make it easier to update the secret, without having to delete and recreate the secret. Since it is in your best interest to have certs that are as short lived as is feasible, you will want to make sure these types of secrets are very easy to update.

Here is a full example of creating a self signed certificate (i.e. a certificate not signed by a trusted root CA), creating a secret from that certificate, and using it in an ingress:

```bash
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
```

Now in order to test this out, you can modify /etc/hosts (C:\Windows\System32\drivers\etc\hosts on Windows) to add an entry for something like:

```bash
172.29.97.225 manual.secure-example.com
```

Replace the IP address with whatever the IP address is for one of your worker nodes. You should be able to find this with `kubectl get nodes -o wide`, but only if the nodes are not behind a firewall and/or load balancer.

With /etc/hosts updated you can open a browser to [https://manual.secure-example.com/](https://manual.secure-example.com/), however you will notice a warning about the certificate being untrusted. This is because our CA is not a trusted root CA. If you choose the advanced options you can proceed any way. Either way, you can look at the cert information and see that it was issued by openssl-ca, the CA that we created earlier. You can see similar results with curl by ignoring cert errors

This is working, but it took a lot of work, and now we need to monitor our certs to make sure they get replaced before they expire. This is where cert-manager

### cert-manager

cert-manager gets installed into your cluster and can automatically create/replace certificates to ensure that they never expire. First things first, let's install cert-manager into the cluster:

```bash
kubectl apply --record=true -f https://github.com/jetstack/cert-manager/releases/download/v1.1.0/cert-manager.yaml
```

You will now have a `cert-manager` namespace that should have some pods coming up. Wait until they are ready before proceeding.

With cert-manager up and running you are ready to install an Issuer, which is what will actually create or pull the certificates. There are [multiple types of Issuers](https://cert-manager.io/docs/configuration/#supported-issuer-types) which can fit different scenarios. If your cluster will be able to be reached by the public, you may wish to use the [ACME Issuer](https://cert-manager.io/docs/configuration/acme/), as it can be free and gets you certs that are associated with a trusted root CA that basically any browser will trust right away. For this example, I will show a CA Issuer, which will work similarly to the prior example in that it will use the certificate authority that we generated from openssl. In a development environment, it could be feasible to have a self signed CA that is shared amongst everyone and added to each machine's trusted certs in order to make things more seamless.

First, we will need to load the CA key pair into a secret:

```bash
cat <<EOF | kubectl apply --record=true -f -
apiVersion: v1
kind: Secret
metadata:
  name: ca-key-pair
data:
  tls.crt: $(cat ca.crt | base64 -w0)
  tls.key: $(cat ca.key | base64 -w0)
EOF
```

And now we create the Issuer:

```bash
cat <<EOF | kubectl apply --record=true -f -
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: ca-issuer
spec:
  ca:
    secretName: ca-key-pair
EOF
```

We now have an Issuer that can be used in the default namespace. Alternatively we could have created a ClusterIssuer, which would be available across the whole cluster.

With our new Issuer at the ready, you can now configure an ingress to use it by adding the following annotations:

```yaml
metadata:
  annotations:
    cert-manager.io/issuer: ca-issuer
```

All the steps together:

```bash
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
```

Very quickly we should see a new secret created as `cm-tls`, which was created by cert-manager. We can see take a peek at the cert by base64 decoding it and passing it to openssl:

```bash
kubectl get secrets cm-tls -o jsonpath="{.data['tls\.crt']}" | base64 -d | openssl x509 -text -noout
```

Once again we can add an entry to /etc/hosts, this time for cm.secure-example.com, and then check out [https://cm.secure-example.com](https://cm.secure-example.com) in our web browser. As before, we will see the trust warnings about our certificate, which we can override if we feel like it. If you were going to use this type of setup for any real usage, e.g. as a persistent development environment, I would definitely suggest coming up with a strategy for trusting the CA that you are using, but keep in mind that anyone with access to the CA can use it to generate certificates that look just like your cluster's certs, which would allow for an easy man-in-the-middle attack.

## Wrap-up

Here I hopefully made the case for why you should use TLS for all of your Kubernetes clusters' north-south traffic, and showed how you can simplify TLS certificate management in Kubernetes by using cert-manager. This post is far from exhaustive, so make sure you do more follow up specific to your needs, but it should get you started on your way.
