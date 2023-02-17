#!/usr/bin/env bash
#
# Setup for Control Plane (Master) servers

set -euxo pipefail

NODE=${MASTER_HOSTNAME#*-}
echo "NODE: $NODE"

# For Vagrant re-runs, check if there is existing configs in the location and delete it for saving new configuration.
config_path="/vagrant/configs"
log_path="/vagrant/logs"


if [ "$MASTER_TYPE" = "single" ] || [ "$NODE" -eq 1 ]; then

    CERTIFICATE_KEY=$(kubeadm certs certificate-key)
    KUBEADM_TOKEN=$(kubeadm token generate)
    export CERTIFICATE_KEY
    export KUBEADM_TOKEN

    if [ -d $config_path ]; then
        rm -f $config_path/*
        rm -rf $log_path
    else
        mkdir -p $log_path
        mkdir -p $config_path
    fi
fi

echo "Preflight Check Passed: Downloaded All Required Images"
sudo kubeadm config images pull

if [ "$MASTER_TYPE" = "single" ]; then
    sudo kubeadm init \
        --certificate-key="$CERTIFICATE_KEY" \
        --apiserver-advertise-address="$MASTER_IP" \
        --apiserver-cert-extra-sans="$MASTER_HOSTNAME.$LAB_DOMAIN" \
        --pod-network-cidr="$POD_CIDR" \
        --service-cidr="$SERVICE_CIDR" \
        --token="$KUBEADM_TOKEN" \
        --upload-certs \
        --ignore-preflight-errors Swap | tee /vagrant/logs/kubeadm-init.log
    
    join_cmd=$(sudo kubeadm token create --print-join-command)
    echo "sudo $join_cmd" > $config_path/join-worker.sh
    chmod +x $config_path/join-worker.sh
else
    if [ "$NODE" -eq 1 ]; then
        sudo kubeadm init \
            --control-plane-endpoint "loadbalancer.$LAB_DOMAIN:6443" \
            --certificate-key="$CERTIFICATE_KEY" \
            --apiserver-advertise-address="$MASTER_IP" \
            --apiserver-cert-extra-sans="$MASTER_HOSTNAME.$LAB_DOMAIN" \
            --apiserver-cert-extra-sans="loadbalancer.$LAB_DOMAIN" \
            --pod-network-cidr="$POD_CIDR" \
            --service-cidr="$SERVICE_CIDR" \
            --token="$KUBEADM_TOKEN" \
            --upload-certs \
            --ignore-preflight-errors Swap | tee /vagrant/logs/kubeadm-init.log

        join_cmd=$(sudo kubeadm token create --print-join-command)
        echo "sudo $join_cmd --control-plane --certificate-key $CERTIFICATE_KEY --v=5" > $config_path/join-control-plane.sh
        echo "sudo $join_cmd" > $config_path/join-worker.sh
        chmod +x $config_path/join-control-plane.sh
        chmod +x $config_path/join-worker.sh

    else
        
        mkdir -p "$HOME"/.kube
        sudo cp -i $config_path/config "$HOME"/.kube/config
        sudo chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config

        eval "$(cat $config_path/join-control-plane.sh)" --apiserver-advertise-address "$MASTER_IP" | tee "/vagrant/logs/kubeadm-joint-$MASTER_HOSTNAME.log"
    fi
fi

if [ "$MASTER_TYPE" = "single" ] || [ "$NODE" -eq 1 ]; then
    # Save Configs to shared /Vagrant location
    cp -i /etc/kubernetes/admin.conf $config_path/config

    mkdir -p "$HOME"/.kube
    sudo cp -i /etc/kubernetes/admin.conf "$HOME"/.kube/config
    sudo chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config 

    # Install Calico Network Plugin
    CALICO_LATEST_VERSION=$(curl --silent https://api.github.com/repos/projectcalico/calico/releases/latest | jq -r .tag_name)
    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/"$CALICO_LATEST_VERSION"/manifests/calico.yaml

    # Install Metrics Server (https://github.com/kubernetes-sigs/metrics-server)
    if [ "$MASTER_TYPE" = "single" ]; then
        kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    else
        # TODO: cert issue
        echo "kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/high-availability-1.21+.yaml"
    fi    
fi

sudo -i -u vagrant bash << EOF
mkdir -p /home/vagrant/.kube
sudo cp -i $config_path/config /home/vagrant/.kube/
sudo chown 1000:1000 /home/vagrant/.kube/config
EOF
