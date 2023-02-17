#!/usr/bin/env bash

# DNS Setting
sudo mkdir /etc/systemd/resolved.conf.d/
cat <<EOF | sudo tee /etc/systemd/resolved.conf.d/dns_servers.conf
[Resolve]
DNS=${DNS_SERVERS}
EOF

apt-get update
apt-get install haproxy -y

systemctl stop haproxy

tee /etc/haproxy/haproxy.cfg <<EOF
global
        log /dev/log    local0
        log /dev/log    local1 notice
        chroot /var/lib/haproxy
        stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
        stats timeout 30s
        user haproxy
        group haproxy
        daemon
        ca-base /etc/ssl/certs
        crt-base /etc/ssl/private
        ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
frontend loadbalancer
        bind *:6443
        mode tcp
        log global
        option tcplog
        timeout client 3600s
        backlog 4096
        maxconn 50000
        use_backend masters
backend masters
        mode  tcp
        option log-health-checks
        option redispatch
        option tcplog
        balance roundrobin
        timeout connect 1s
        timeout queue 5s
        timeout server 3600s
EOF

IFS=',' read -ra MASTER_IP_ARRAY <<< "$MASTER_IPS"

i=0
for master_ip in "${MASTER_IP_ARRAY[@]}"; do
  echo "        server master-$i $master_ip:6443 check" >> /etc/haproxy/haproxy.cfg
  ((i++))
done

systemctl restart haproxy