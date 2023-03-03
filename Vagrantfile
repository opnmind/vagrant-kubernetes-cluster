# -*- mode: ruby -*-
# vi: set ft=ruby :
require "yaml"

class KubernetesLab

  def initialize
    @settings = YAML.load_file "settings.yaml"
    @NUM_MASTER_NODES = @settings["nodes"]["master"]["count"]
    @NUM_WORKER_NODES = @settings["nodes"]["worker"]["count"]
    @hosts = Array[]
    @masterIps = Array[]
    @workerIps = Array[]
    @loadbalancerIp = ""
    @workstationIp = ""

    puts "---- Provisioned with k8s #{@settings["application"]["kubernetes"]}"
    #puts "---- Container runtime is: #{CONTAINER_RUNTIME}"
    #puts "---- CNI Provider is: #{CNI_PROVIDER}"
    puts "---- #{@settings["nodes"]["master"]["count"]} Masters Nodes"
    puts "---- #{@settings["nodes"]["worker"]["count"]} Worker(s) Node(s)"

    self.getHosts()
  end

  def defineIp(type, i)
    case type
    when "master" 
      return @settings["network"]["lab_network"].split('.')[0..-2].join('.') + ".#{i + 10}"
    when "worker"
      return @settings["network"]["lab_network"].split('.')[0..-2].join('.') + ".#{i + 30}"
    when "loadbalancer"
      return @settings["network"]["lab_network"].split('.')[0..-2].join('.') + ".#{i + 200}"
    when "workstation"
      return @settings["network"]["lab_network"].split('.')[0..-2].join('.') + ".#{i + 220}"
    end
  end

  def getHosts()
    if @NUM_MASTER_NODES > 1
      @loadbalancerIp = self.defineIp("loadbalancer", 0)
      @hosts.push("#{@loadbalancerIp} loadbalancer.#{@settings["network"]["lab_domain"]} loadbalancer.local loadbalancer")
    end

    (0..@NUM_MASTER_NODES-1).each do |m|
      masterIp = self.defineIp("master", m)
      @masterIps.push(masterIp)
      @hosts.push("#{masterIp} master-#{m+1}.#{@settings["network"]["lab_domain"]} master-#{m+1}.local master-#{m+1}")
    end

    (0..@NUM_WORKER_NODES-1).each do |w|
      workerIp = self.defineIp("worker", w)
      @workerIps.push(workerIp)
      @hosts.push("#{workerIp} worker-#{w+1}.#{@settings["network"]["lab_domain"]} worker-#{w+1}.local worker-#{w+1}")
    end

    @workstationIp = self.defineIp("workstation", 0)
    @hosts.push("#{@workstationIp} workstation.#{@settings["network"]["lab_domain"]} workstation.local workstation")
  end

  def createLoadbalancer(config)
    if @NUM_MASTER_NODES <= 1
      return
    end
    
    puts "The Loadbalancer IP is #{@loadbalancerIp}."

    config.vm.define "loadbalancer" do |loadbalancer|
      loadbalancer.vm.hostname = "loadbalancer"
      loadbalancer.vm.box = @settings["application"]["box"]
      loadbalancer.vm.network "private_network", ip: @loadbalancerIp
      loadbalancer.vm.network "forwarded_port", guest: 6443, host: 6443

      loadbalancer.vm.provider "virtualbox" do |vb|
        vb.cpus = @settings["nodes"]["loadbalancer"]["cpu"]
        vb.memory = @settings["nodes"]["loadbalancer"]["ram"]
        vb.customize ["modifyvm", :id, "--audio", "none"]
        vb.customize ["modifyvm", :id, "--hwvirtex", "on"]
        vb.customize ["modifyvm", :id, "--nested-hw-virt","on"]

        if @settings["cluster_name"] and @settings["cluster_name"] != ""
          vb.customize ["modifyvm", :id, "--groups", ("/" + @settings["cluster_name"])]
        end

        loadbalancer.vm.provision "ansible" do |ansible|
          ansible.verbose = "v"
          ansible.playbook = "ansible/playbook-haproxy.yaml"
          ansible.extra_vars = {
            dns_servers: @settings["network"]["dns_servers"],
            lab_domain: @settings["network"]["lab_domain"],
            local_ip: @loadbalancerIp,
            master_ips: @masterIps,
            num_master_count: @NUM_WORKER_NODES,
            hosts_entries: @hosts
          }
        end
      end
    end
  end

  def createControlPlane(config)
    (1..@NUM_MASTER_NODES).each do |i|
      masterIp = self.defineIp("master", i-1)
      masterType = "multi"

      puts "The master-#{i} IP is #{masterIp}."

      config.vm.define "master-#{i}" do |master|
        master.vm.hostname = "master-#{i}"
        master.vm.box = @settings["application"]["box"]
        master.vm.network "private_network", ip: masterIp
      
        master.vm.provider "virtualbox" do |vb|
          vb.cpus = @settings["nodes"]["master"]["cpu"]
          vb.memory = @settings["nodes"]["master"]["ram"]
          vb.customize ["modifyvm", :id, "--audio", "none"]
          vb.customize ["modifyvm", :id, "--hwvirtex", "on"]
          vb.customize ["modifyvm", :id, "--nested-hw-virt","on"]
  
          if @settings["cluster_name"] and @settings["cluster_name"] != ""
            vb.customize ["modifyvm", :id, "--groups", ("/" + @settings["cluster_name"])]
          end
        end

        if @NUM_MASTER_NODES == 1
          master.vm.network "forwarded_port", guest: 6443, host: 6443
          masterType = "single"
        end

        master.vm.provision "ansible" do |ansible|
          ansible.verbose = "v"
          ansible.playbook = "ansible/playbook-master.yaml"
          ansible.extra_vars = {
            dns_servers: @settings["network"]["dns_servers"],
            lab_domain: @settings["network"]["lab_domain"],
            kubernetes_version: @settings["application"]["kubernetes"],
            os: @settings["application"]["os"],
            pod_cidr: @settings["network"]["pod_cidr"],
            service_cidr: @settings["network"]["service_cidr"],
            local_ip: masterIp,
            master_ips: @masterIps,
            num_master_count: @NUM_WORKER_NODES,
            hosts_entries: @hosts,
            master_type: masterType,
            master_hostname: "master-#{i}",
            node: i
          }
        end
      end
    end
  end

  def createWorkerNode(config)
    (1..@NUM_WORKER_NODES).each do |i|
      workerIp = self.defineIp("worker", i-1)
      masterType = "multi"
      if @NUM_MASTER_NODES == 1
        masterType = "single"
      end

      puts "The worker-#{i} IP is #{workerIp}."

      config.vm.define "worker-#{i}" do |worker|
        worker.vm.hostname = "worker-#{i}"
        worker.vm.box = @settings["application"]["box"]
        worker.vm.network "private_network", ip: workerIp

        worker.vm.provider "virtualbox" do |vb|
          vb.cpus = @settings["nodes"]["worker"]["cpu"]
          vb.memory = @settings["nodes"]["worker"]["ram"]
          vb.customize ["modifyvm", :id, "--audio", "none"]
          vb.customize ["modifyvm", :id, "--hwvirtex", "on"]
          vb.customize ["modifyvm", :id, "--nested-hw-virt","on"]          

          if @settings["cluster_name"] and @settings["cluster_name"] != ""
            vb.customize ["modifyvm", :id, "--groups", ("/" + @settings["cluster_name"])]
          end
        end

        worker.vm.provision "ansible" do |ansible|
          ansible.verbose = "v"
          ansible.playbook = "ansible/playbook-worker.yaml"
          ansible.extra_vars = {
            dns_servers: @settings["network"]["dns_servers"],
            lab_domain: @settings["network"]["lab_domain"],
            kubernetes_version: @settings["application"]["kubernetes"],
            os: @settings["application"]["os"],
            pod_cidr: @settings["network"]["pod_cidr"],
            service_cidr: @settings["network"]["service_cidr"],
            local_ip: workerIp,
            master_ips: @masterIps,
            num_master_count: @NUM_WORKER_NODES,
            hosts_entries: @hosts
          }
        end
      end
    end
  end

  def createWorkstation(config)
    workstationIp = self.defineIp("workstation", 0)

    puts "The workstation IP is #{workstationIp}."

    config.vm.define "workstation" do |workstation|
      workstation.vm.hostname = "workstation"
      workstation.vm.box = @settings["application"]["box"]      
      workstation.vm.network "private_network", ip: workstationIp
      workstation.vm.network "forwarded_port", guest: 443, host: 8443
      workstation.vm.network "forwarded_port", guest: 80, host: 8080

      workstation.vm.provider "virtualbox" do |vb|
        vb.cpus = @settings["nodes"]["workstation"]["cpu"]
        vb.memory = @settings["nodes"]["workstation"]["ram"]
        vb.customize ["modifyvm", :id, "--audio", "none"]
        vb.customize ["modifyvm", :id, "--hwvirtex", "on"]
        vb.customize ["modifyvm", :id, "--nested-hw-virt","on"]

      if @settings["cluster_name"] and @settings["cluster_name"] != ""
        vb.customize ["modifyvm", :id, "--groups", ("/" + @settings["cluster_name"])]
      end

      workstation.vm.provision "ansible" do |ansible|
        ansible.verbose = "v"
        ansible.playbook = "ansible/playbook-workstation.yaml"
        ansible.extra_vars = {
          dns_servers: @settings["network"]["dns_servers"],
          lab_domain: @settings["network"]["lab_domain"],
          kubernetes_version: @settings["application"]["kubernetes"],
          os: @settings["application"]["os"],
          pod_cidr: @settings["network"]["pod_cidr"],
          service_cidr: @settings["network"]["service_cidr"],
          local_ip: workstationIp,
          master_ips: @masterIps,
          num_master_count: @NUM_WORKER_NODES,
          hosts_entries: @hosts
        }
      end
    end

  end
end

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|
  kubernetesLab = KubernetesLab.new()
  kubernetesLab.createLoadbalancer(config)
  kubernetesLab.createControlPlane(config)
  kubernetesLab.createWorkerNode(config)
  kubernetesLab.createWorkstation(config) 

  config.vm.box_check_update = false
  config.vm.provision :reload

  config.vm.provision "shell",
    run: "always",
    inline: "swapoff -a"
  end
end
