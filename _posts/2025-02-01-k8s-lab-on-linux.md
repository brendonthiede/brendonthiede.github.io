---
layout: post
title:  "Kubernetes Lab Setup on Linux"
date:   2025-02-01T02:06:55.535Z
categories: devops
---
This is a simple tutorial for setting up a 3 node Kubernetes lab on a Linux machine. This setup is intended for educational purposes and may not be suitable for production environments. This tutorial will specifically use [Mutipass](https://canonical.com/multipass) to create VMs on a Linux host. The host used for this tutorial is Ubuntu 24.04.

### Conventions

- `k8s-cp`: Control Plane node
- `k8s-worker1`: Worker node 1
- `k8s-worker2`: Worker node 2

### Prerequisites

- A Linux machine (Ubuntu 20.04 or later is recommended)
- Root or sudo access

### Step 1: Install Multipass

To install Multipass and then create the VMs, run the following commands in your terminal:

```bash
sudo snap install multipass --classic
multipass version
multipass launch --name k8s-cp --cpus 2 --memory 2G --disk 20G
multipass launch --name k8s-worker1 --cpus 2 --memory 2G --disk 20G
multipass launch --name k8s-worker2 --cpus 2 --memory 2G --disk 20G
multipass list
```

Since these are all using the same default Ubuntu image, you should expect that the first launch will take a while, as it downloads the full OS, but the subsequent launches will be much faster.

### Step 2: Base VM Setup

Create a script file on the host named `setup-vm.sh` using this command:

```bash
cat <<EOF > setup-vm.sh
#!/usr/bin/env bash

# Update the apt package index and install packages needed to configure the k8s apt repo
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# Configure the apt repo for Kubernetes
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Install kubelet, kubeadm, kubectl, and containerd
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl containerd
sudo apt-mark hold kubeadm kubelet kubectl

# Configure containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd

# Disable swap (kubeadm init will fail if swap is enabled)
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Load necessary kernel modules for Kubernetes networking
sudo modprobe overlay
sudo modprobe br_netfilter
echo -e "overlay\nbr_netfilter" | sudo tee /etc/modules-load.d/k8s.conf
echo "br_netfilter" | sudo tee /etc/modules-load.d/k8s.conf

# Configure sysctl settings for Kubernetes networking
cat <<EOF2 | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF2
sudo sysctl --system

# Reboot the VM
if [ -f /var/run/reboot-required ]; then
    cat /var/run/reboot-required
    sudo reboot
fi
EOF
```

Then transfer and run the script on each VM:

```bash
for vm in k8s-cp k8s-worker1 k8s-worker2; do
    multipass transfer setup-vm.sh $vm:/home/ubuntu/setup-vm.sh
    multipass exec $vm -- bash -c "chmod +x /home/ubuntu/setup-vm.sh && /home/ubuntu/setup-vm.sh"
done
```

### Step 3: Install Kubernetes Control Plane

Create a script file on the host named `setup-k8s-cp.sh` using this command:

```bash
cat <<EOF > setup-k8s-cp.sh
#!/usr/bin/env bash

# Start kubelet and run kubeadm init
sudo systemctl enable --now kubelet
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-cert-extra-sans $(hostname -I | awk '{print $1}')

# Configure kubectl for the current user
mkdir -p \$HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config
sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config

# Install Flannel CNI
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
EOF
```

Then transfer and run the script on the control plane node:

```bash
multipass transfer setup-k8s-cp.sh k8s-cp:/home/ubuntu/setup-k8s-cp.sh
multipass exec k8s-cp -- bash -c "chmod +x /home/ubuntu/setup-k8s-cp.sh && /home/ubuntu/setup-k8s-cp.sh"
```

### Step 4: Join Kubernetes Workers to the Cluster

```bash
JOIN_COMMAND="$(multipass exec k8s-cp -- kubeadm token create --print-join-command)"
for vm in k8s-worker1 k8s-worker2; do
    multipass exec $vm -- bash -c "sudo $JOIN_COMMAND"
done
```

### Step 5: Copy Kubeconfig to Host

First off, if you don't have kubectl installed on your host, you can install it with:

```bash
sudo snap install kubectl --classic
```

You should also configure the Bash completion for kubectl:

```bash
kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl
source /etc/bash_completion.d/kubectl
```

Then, copy the kubeconfig file from the control plane node to your host machine:

```bash
multipass exec k8s-cp -- bash -c 'sudo cp /etc/kubernetes/admin.conf /home/ubuntu/lab.conf; sudo chown $(id -u):$(id -g) /home/ubuntu/lab.conf'
mkdir -p ~/.kube
multipass transfer k8s-cp:/home/ubuntu/lab.conf ./lab.conf
mv ./lab.conf ~/.kube/
```

### Step 6: Configure Host Proxy to Access the Cluster

If you want to access the cluster from a different machine, one option is that you can set up socat on your host machine to proxy the calls to the control plane VM:

```bash
K8S_CP_IP="$(multipass info k8s-cp | grep IPv4 | awk '{print $2}')"
sudo ufw allow 6443/tcp
sudo apt-get update && sudo apt-get install socat -y
multipass exec k8s-cp -- bash -c 'sudo apt-get update && sudo apt-get install socat'

mkdir -p ~/bin
cat <<EOF > ~/bin/forward-k8s-cp.sh
#!/usr/bin/env bash
multipass exec k8s-cp -- socat STDIO TCP4:127.0.0.1:6443
EOF

chmod +x ~/bin/forward-k8s-cp.sh

mkdir -p ~/.config/systemd/user
cat <<EOF > ~/.config/systemd/user/forward-k8s-cp.service
[Unit]
Description=Socat forward from host 6443 to k8s-cp VM
After=default.target

[Service]
# We run socat in user mode on port 6443
# No sudo needed, since 6443 > 1024
ExecStart=/usr/bin/socat TCP-LISTEN:6443,fork,reuseaddr SYSTEM:"${HOME}/bin/forward-k8s-cp.sh"
                   socat TCP-LISTEN:6443,fork,reuseaddr     SYSTEM:"~/forward-k8s-cp.sh"
# Keep restarting on failure
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

sudo loginctl enable-linger $(whoami)
systemctl --user daemon-reload
systemctl --user enable forward-k8s-cp
systemctl --user start forward-k8s-cp

echo "##############################################"
echo "# Use the config below to access the cluster #"
echo "##############################################"
sed "s/${K8S_CP_IP}/$(hostname -I | awk '{print $1}')/g" ~/.kube/lab.conf
```
