#!/usr/bin/env bash

set -euxo pipefail

config_path="/vagrant/configs"

# DNS Setting
sudo mkdir -p /etc/systemd/resolved.conf.d/
cat <<EOF | sudo tee /etc/systemd/resolved.conf.d/dns_servers.conf
[Resolve]
DNS=${DNS_SERVERS}
EOF

sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl jq
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg

echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update -y
sudo apt-get install -y kubectl="$KUBERNETES_VERSION" etcd-client

kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
echo 'alias k=kubectl' | sudo tee -a /etc/bash.bashrc > /dev/null
echo 'complete -o default -F __start_kubectl k' | sudo tee -a /etc/bash.bashrc > /dev/null

sudo -i -u vagrant bash << EOF
mkdir -p /home/vagrant/.kube
sudo cp -i $config_path/config /home/vagrant/.kube/
sudo chown 1000:1000 /home/vagrant/.kube/config
sudo chmod 0600 /home/vagrant/.kube/config
EOF

curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm

helm repo add stable https://charts.helm.sh/stable
helm repo add incubator https://charts.helm.sh/incubator
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Installing dashboard service
mkdir -p /home/vagrant/dashboard
cat <<EOF | tee /home/vagrant/dashboard/dashboard.sh
#!/bin/bash
showtoken=1
cmd="kubectl proxy"
count=$(pgrep -cf "\$cmd")
DASHBOARD_VERSION=\$(curl --silent https://api.github.com/repos/kubernetes/dashboard/releases/latest | jq -r .tag_name)
DASHBOARD_YAML="https://raw.githubusercontent.com/kubernetes/dashboard/\$DASHBOARD_VERSION/aio/deploy/recommended.yaml"
msg_started="-e Kubernetes Dashboard e[92mstartede[0m"
msg_stopped="Kubernetes Dashboard stopped"

case \$1 in
start)
   kubectl apply -f \$DASHBOARD_YAML >/dev/null 2>&1
   kubectl apply -f ~/dashboard/dashboard-admin.yaml >/dev/null 2>&1
   kubectl apply -f ~/dashboard/dashboard-read-only.yaml >/dev/null 2>&1

   if [ \$count = 0 ]; then
      nohup \$cmd >/dev/null 2>&1 &
      echo \$msg_started
   else
      echo "Kubernetes Dashboard already running"
   fi
   ;;

stop)
   showtoken=0
   if [ \$count -gt 0 ]; then
      kill -9 \$(pgrep -f "\$cmd")
   fi
   kubectl delete -f \$DASHBOARD_YAML >/dev/null 2>&1
   kubectl delete -f ~/dashboard/dashboard-admin.yaml >/dev/null 2>&1
   kubectl delete -f ~/dashboard/dashboard-read-only.yaml >/dev/null 2>&1
   echo \$msg_stopped
   ;;

status)
   found=\$(kubectl get serviceaccount admin-user -n kubernetes-dashboard 2>/dev/null)
   if [[ \$count = 0 ]] || [[ \$found = "" ]]; then
      showtoken=0
      echo \$msg_stopped
   else
      found=\$(kubectl get clusterrolebinding admin-user -n kubernetes-dashboard 2>/dev/null)
      if [[ \$found = "" ]]; then
         nopermission=" but user has no permissions."
         echo "\${msg_started}\${nopermission}"
         echo 'Run "dashboard start" to fix it.'
      else
         echo \$msg_started
      fi
   fi
   ;;
esac

# Show full command line # ps -wfC "$\cmd"
if [ \$showtoken -gt 0 ]; then
   # Show token
   echo "Admin token:"
   kubectl get secret -n kubernetes-dashboard \$(kubectl get serviceaccount admin-user -n kubernetes-dashboard -o jsonpath="{.secrets[0].name}") -o jsonpath="{.data.token}" | base64 --decode
   echo

   echo "User read-only token:"
   kubectl get secret -n kubernetes-dashboard \$(kubectl get serviceaccount read-only-user -n kubernetes-dashboard -o jsonpath="{.secrets[0].name}") -o jsonpath="{.data.token}" | base64 --decode
   echo
fi
EOF

sudo chown vagrant:vagrant /home/vagrant/dashboard/dashboard.sh
chmod +x /home/vagrant/dashboard/dashboard.sh
sudo rm -f /usr/local/bin/dashboard
sudo ln -s /home/vagrant/dashboard/dashboard.sh /usr/local/bin/dashboard

# Install Traefik
#kubectl apply -f 00-role.yml \
#              -f 00-account.yml \
#              -f 01-role-binding.yml \
#              -f 02-traefik.yml \
#              -f 02-traefik-services.yml

# Install Traefik Resource Definitions:
#kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v2.9/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml

# Install RBAC for Traefik:
#kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v2.9/docs/content/reference/dynamic-configuration/kubernetes-crd-rbac.yml


