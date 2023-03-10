# vagrant-kubernetes-cluster

## Prerequisites

```shell
$ vagrant plugin install yaml vagrant-reload
```

## Setup Cluster

- single control-plan node
- multiple control-plan nodes (incl. loadbalancer - haproxy)

```settings.yaml
---
cluster_name: k8s-cluster

network:
  lab_network: 10.0.0.0
  lab_domain: lab.local
  dns_servers:
    - 8.8.8.8
    - 1.1.1.1
  pod_cidr: 172.16.1.0/16
  service_cidr: 172.17.1.0/18

nodes:
  master:
    count: 1
    cpu: 2
    ram: 4096
  worker:
    count: 3
    cpu: 1
    ram: 2048
  loadbalancer:
    cpu: 1
    ram: 1024
  workstation:
    cpu: 2
    ram: 2048

application:
  os: xUbuntu_22.04
  box: ubuntu/jammy64
  kubernetes: 1.26.1-00
```

## Usage

```shell
# start the cluster
$ vagrant up

# connect to the kubectl workstation
$ vagrant ssh workstation

# delete the cluster
$ vagrant destroy --force
```

## TODO
