---
layout: post
title:  "Installing k3d on Windows"
date:   2021-03-24T04:04:32.517Z
categories: devops
externalImage: https://raw.githubusercontent.com/rancher/k3d/main/docs/static/img/k3d_logo_black_blue.svg
---
To install k3d, you will need Docker. If you don't already have Docker installed, you can follow the instructions in the next section to get Docker Desktop (check the prerequisites [here](https://docs.docker.com/docker-for-windows/install/#wsl-2-backend)).

## Installing Docker Desktop

### Prerequisite: WSL2

Start a PowerShell instance as Administrator and run the following to install WSL2:

```powershell
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
```

Reboot at this time, then come back and download and install [WSL2 Linux kernel update package for x64 machines](https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi).

Now back in an administrative PowerShell instance:

```powershell
# Set WSL2 as the default
wsl --set-default-version 2
```

Lastly, grab a Linux distro from the [Microsoft Store](https://aka.ms/wslstore). If you don't know which to choose, just go with [Ubuntu 20.04](https://www.microsoft.com/store/apps/9n6svws3rx71). You can always change it later. If you don't have access to the Microsoft Store (e.g. it's blocked on a work system), you can find manual install instructions [here](https://docs.microsoft.com/en-us/windows/wsl/install-manual#downloading-distributions).

At this point you may as well launch and set up your distro, which will likely be nothing more than creating an account name and password. If you have a common username on other systems that you will likely be connecting to, it may be desirable to use that as your username in your Linux distro, but ultimately, you can use whatever username you want.

### Docker Desktop

You can either go to the main [product page](https://www.docker.com/products/docker-desktop) to grab the latest installer (I would recommend this approach), or you can look for a specific version [here](https://docs.docker.com/docker-for-windows/release-notes/). Whichever way you install it, make sure you select the option to install the WSL2 components (should be selected by default).

And now one more reboot and you should be good to go.

Tip: if you don't plan on using Docker all the time, you may wish to adjust the settings to _not_ have it start when you log in.

## Installing k3d

The easiest way to get k3d running on Windows is with Chocolatey. To install Chocolatey you can run the following from an administrative PowerShell instance:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
```

Now close PowerShell and open a new administrative instance and run the following to install k3d and a couple other useful tools:

```powershell
choco install k3d -y
choco install jq -y
choco install yq -y
choco install kubernetes-helm -y
```

And now let's configure tab completion for k3d:

```powershell
# Create user profile file if it doesn't exist
if ( -not ( Test-Path $Profile ) ) { New-Item -Path $Profile -Type File -Force }
# Append the k3d completion to the end of the user profile
k3d completion powershell | Out-File -Append $Profile
```

## Using k3d

Start a new PowerShell instance (doesn't need to be administrative this time around). Now that you have the k3d binary on your path, you can create a cluster by running:

```powershell
k3d cluster create localk8s
```

You can name the cluster whatever you want by replacing `localk8s` with whatever you would like.

Windows will ask you to approve a change to the firewall configuration. Definitely do not allow access to public networks.

With my current version of k3d (v4.3.0) I get an error about .kube/config failing to be overwritten, though it appears to be a pathing issue. To fix it, just move the file it created in .kube to be .kube/config:

```powershell
Move-Item ~\.kube\config.k3d* ~\.kube\config -Force
```

You can peek at your running cluster by running some commands like the following:

```powershell
# List the Kubernetes nodes
kubectl get nodes --output wide
# List several Kubernetes objects in the cluster
kubectl get all --all-namespaces
```

And since this is all running in Docker, you can look at the "real" containers there:

```powershell
docker container ls
```

You should see two containers by default: a k3s instance and the k3d proxy. The k3d proxy is used to route traffic in to the API server, which you can see configured by looking at `~/.kube/config`, where you might see something like `server: https://0.0.0.0:52038`, which would be the same port that Docker shows as routing to port 6443 of the k3d proxy container.

However, the main reason I want to use k3d instead of minikube is that I want to have multiple nodes so that I can realistically test out taints, tolerations, affinity rules, etc. To create a multi-node system, you can delete the previous cluster and recreate it, this time passing values for `--servers` and `--agents`. While we're at it, we should also set up some port forwarding to be able to interact with we workloads:

```powershell
# Delete the existing cluster
k3d cluster delete localk8s
# Create a new multi-node cluster
k3d cluster create localk8s --servers 3 --agents 3 --port "8888:80@loadbalancer" --port "8889:443@loadbalancer"
# Rename the config if needed
if ( Test-Path ~\.kube\config.k3d* ) { Move-Item ~\.kube\config.k3d* ~\.kube\config -Force }
# List the Kubernetes nodes
kubectl get nodes --output wide
# Look at the "real" containers again (you can see or new port forwarding)
docker container ls
```

Another you could do with k3d, though I'm not going to get into it, is to mount volumes to any combination of the nodes in your cluster. If this is something that you end up needing, a quick web search should set you on your way. And if your configuration starts to get too complex, you may want to consider using a config options file instead of command line arguments.

With the cluster running and ready to forward traffic, we can create a deployment, service, and ingress (from my [example of making a multi-node cluster with Multipass](https://github.com/brendonthiede/brendon-k8s-demo)):

```powershell
echo "
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: ui
  name: ui
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ui
  template:
    metadata:
      labels:
        app: ui
    spec:
      containers:
      - image: thiedebr/crud-ui:latest
        name: crud-ui
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: ui
  name: ui
spec:
  ports:
  - name: http
    port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: ui
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: api
  name: api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
      - image: thiedebr/crud-api:latest
        name: crud-api
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: api
  name: api
spec:
  ports:
  - name: http
    port: 80
    protocol: TCP
    targetPort: 8887
  selector:
    app: api
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: localhost
  annotations:
    ingress.kubernetes.io/ssl-redirect: 'false'
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ui
            port:
              number: 80
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api
            port:
              number: 80
" | kubectl apply -f -
```

Using the `echo` alias for `Write-Output` actually allows this command to work the same in PowerShell and Bash. To test the result of what we've done, go to http://localhost:8888 in you browser and you should see "Hello Kubernetes" displayed.

When you are done using your cluster, it is probably best to stop it:

```powershell
k3d cluster stop localk8s
```

And then to start it back up later:

```powershell
k3d cluster start localk8s
```

If you happen to restart your machine without stopping the cluster, it may end up in an odd state. If this happens, you can try to stop then start the cluster. If that doesn't work you may have to delete the cluster and start again.

## Configuring Bash

As much as I actually prefer several of the features and principles in PowerShell over Bash, there are going to be a lot more examples using Bash scripts, and there will also be some apps that only run on Linux, therefore you will need to run them from WSL. Here is my recommendation for setting things up for WSL2 using Ubuntu 20.04. Just fire up an Ubuntu shell and follow along.

### Use the Windows Kubernetes tooling

You can use the Windows binaries from WSL2, and you will want to just go ahead and use those instead of installing new Ubuntu variants. This will make sure that things run nicely both from Windows and Ubuntu, and it will significantly reduce your headaches when trying to proxy things through to your web browser. The one little hiccup is that the Bash tab completion is going to be based on an expected Linux command name, for example `k3d`, not the Windows command name that will end in `.exe`, `.bat`, or something else. Using Linux aliases, this isn't a problem:

```bash
# Setup the alias for k3d in bash configuration (loaded every time you launch the a shell)
grep 'alias k3d=k3d.exe' ~/.bashrc || echo -e "# k3d setup\nalias k3d=k3d.exe" >>~/.bashrc
# Have bash completion get loaded for k3d
grep 'source <(k3d completion bash)' ~/.bashrc || echo "source <(k3d completion bash)" >>~/.bashrc
# Reload the configuration for the current shell
source ~/.bashrc
```

Now you will have an alias of `k3d` that will run `k3d.exe`, but will also provide you with the expected shell completion. Some of our commands are already set up as part of the Docker Desktop install, such that we have the "extensionless" name and tab completion. Here are the remaining things I recommend to get everything set up so far to behave as expected:

```bash
# Have bash completion get loaded for kubectl
grep 'source <(kubectl completion bash)' ~/.bashrc || echo -e "# kubectl setup\nsource <(kubectl completion bash)" >>~/.bashrc
# Setup the alias for helm
grep 'alias helm=helm.exe' ~/.bashrc || echo -e "# helm setup\nalias helm=helm.exe" >>~/.bashrc
# Have bash completion get loaded for helm
grep 'source <(helm completion bash)' ~/.bashrc || echo "source <(helm completion bash)" >>~/.bashrc
# Reload the configuration for the current shell
source ~/.bashrc
```

Lastly, since we are sharing the tooling across Windows and Ubuntu, we should share the config as well.

```bash
# Setup WINHOME environment variable for convenience
grep 'export WINHOME=' ~/.bashrc || echo -e '# Home directory in Windows\nexport WINHOME=$(cmd.exe /C "echo %USERPROFILE%" 2>/dev/null  | tr -d '\''\r\n'\'' | sed -E '\''s/([A-Z]+):\\\(.*)/\/mnt\/\L\1\/\2/; s/\\\/\//g'\'')' >>~/.bashrc
# Reload the configuration for the current shell
source ~/.bashrc

# Create a symlink so that ~/.kube pulls your Windows user config
rm -rf ~/.kube
ln -s "${WINHOME}"/.kube ~/.kube
```

And now you can verify everything with a list of what is currently in the cluster:

```bash
kubectl get all --all-namespaces
```

## Resources

* [k3d Homepage](https://k3d.io/)
* [My example of making a Kubernetes cluster with Multipass](https://github.com/brendonthiede/brendon-k8s-demo)
