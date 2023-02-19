#!/usr/bin/env bash

set -euxo pipefail

config_path="/vagrant/configs"
$config_path/join-worker.sh

if grep -E "KUBELET_EXTRA_ARGS=" /etc/default/kubelet ; then
  sed -i "s+KUBELET_EXTRA_ARGS=\"+KUBELET_EXTRA_ARGS=\"--node-ip=$WORKER_IP +g" /etc/default/kubelet
else
  echo "KUBELET_EXTRA_ARGS=--node-ip=$WORKER_IP" >> /etc/default/kubelet
fi

systemctl restart kubelet

sudo -i -u vagrant bash << EOF
mkdir -p /home/vagrant/.kube
sudo cp -i $config_path/config /home/vagrant/.kube/
sudo chown 1000:1000 /home/vagrant/.kube/config
NODENAME=$(hostname -s)
kubectl label node $(hostname -s) node-role.kubernetes.io/worker=worker
EOF
