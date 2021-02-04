sudo apt-get install docker-ce-cli

```bash
sudo wget -O /usr/local/bin/minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo chown root:root /usr/local/bin/minikube
sudo chmod 755 /usr/local/bin/minikube

minikube addons enable ingress
```
