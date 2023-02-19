# -*- mode: ruby -*-
# vi: set ft=ruby :
require "yaml"

class KubernetesLab

  def initialize
    @settings = YAML.load_file "settings.yaml"
    @NUM_MASTER_NODES = @settings["nodes"]["master"]["count"]
    @NUM_WORKER_NODES = @settings["nodes"]["worker"]["count"]
    @hosts = Array[]

    puts "---- Provisioned with k8s #{@settings["application"]["kubernetes"]}"
    #puts "---- Container runtime is: #{CONTAINER_RUNTIME}"
    #puts "---- CNI Provider is: #{CNI_PROVIDER}"
    puts "---- #{@settings["nodes"]["master"]["count"]} Masters Nodes"
    puts "---- #{@settings["nodes"]["worker"]["count"]} Worker(s) Node(s)"
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

  def createLoadbalancer(config)
    controlPlanIps = Array[]
    loadbalancerIp = self.defineIp("loadbalancer", 0)
    @hosts.push("#{loadbalancerIp} loadbalancer.#{@settings["network"]["lab_domain"]} loadbalancer.local loadbalancer")

    (0..@NUM_MASTER_NODES-1).each do |m|
      controlPlanIp = self.defineIp("master", m)
      controlPlanIps.push(controlPlanIp)
      @hosts.push("#{controlPlanIp} master-#{m+1}.#{@settings["network"]["lab_domain"]} master-#{m+1}.local master-#{m+1}")
    end

    (0..@NUM_WORKER_NODES-1).each do |w|
      worker_Ip = self.defineIp("worker", w)
      @hosts.push("#{worker_Ip} worker-#{w+1}.#{@settings["network"]["lab_domain"]} worker-#{w+1}.local worker-#{w+1}")
    end

    workstation_Ip = self.defineIp("workstation", 0)
    @hosts.push("#{workstation_Ip} workstation.#{@settings["network"]["lab_domain"]} workstation.local workstation")

    if @NUM_MASTER_NODES <= 1
      return
    end
    
    puts "The Loadbalancer IP is #{loadbalancerIp}."

    config.vm.define "loadbalancer" do |loadbalancer|
      loadbalancer.vm.hostname = "loadbalancer"
      loadbalancer.vm.box = @settings["application"]["box"]      
      loadbalancer.vm.network "private_network", ip: loadbalancerIp
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
      end

      loadbalancer.vm.provision "shell",
        env: {
        "MASTER_IPS" =>  controlPlanIps.join(","),
        "LOADBALANCER_IP" => loadbalancerIp,
        "LAB_DOMAIN" => @settings["network"]["lab_domain"],
        "DNS_SERVERS" => @settings["network"]["dns_servers"].join(" ")
        }, 
        path: "scripts/haproxy.sh"

      $script = <<-SCRIPT
        echo "#{@hosts.join("\n")}" >> /etc/hosts
      SCRIPT
      loadbalancer.vm.provision "shell", inline: $script
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

        $script = <<-SCRIPT
          echo "#{@hosts.join("\n")}" >> /etc/hosts
        SCRIPT
        master.vm.provision "shell", inline: $script

        master.vm.provision "shell", 
          env: {
            "DNS_SERVERS" => @settings["network"]["dns_servers"].join(" "),
            "KUBERNETES_VERSION" => @settings["application"]["kubernetes"],
            "OS" => @settings["application"]["os"]
          },
          path: "scripts/common.sh"

        master.vm.provision "shell", 
          env: {
            "MASTER_IP" => masterIp,
            "MASTER_HOSTNAME" => "master-#{i}",
            "MASTER_TYPE" => masterType,
            "LAB_DOMAIN" => @settings["network"]["lab_domain"],
            "POD_CIDR" => @settings["network"]["pod_cidr"],
            "SERVICE_CIDR" => @settings["network"]["service_cidr"],
            "KUBERNETES_VERSION" => @settings["application"]["kubernetes"]
          },
          path: "scripts/master.sh"
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

        $script = <<-SCRIPT
          echo "#{@hosts.join("\n")}" >> /etc/hosts
        SCRIPT
        worker.vm.provision "shell", inline: $script

        worker.vm.provision "shell",
          env: {
            "DNS_SERVERS" => @settings["network"]["dns_servers"].join(" "),
            "KUBERNETES_VERSION" => @settings["application"]["kubernetes"],
            "OS" => @settings["application"]["os"]
          },
          path: "scripts/common.sh"
        
        worker.vm.provision "shell", 
          env: {
            "WORKER_IP" => workerIp,
            "WORKER_HOSTNAME" => "worker-#{i}",
            "MASTER_TYPE" => masterType,
            "LAB_DOMAIN" => @settings["network"]["lab_domain"],
            "POD_CIDR" => @settings["network"]["pod_cidr"],
            "SERVICE_CIDR" => @settings["network"]["service_cidr"],
            "KUBERNETES_VERSION" => @settings["application"]["kubernetes"]
          },
          path: "scripts/worker.sh"
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

      $script = <<-SCRIPT
        echo "#{@hosts.join("\n")}" >> /etc/hosts
      SCRIPT
      workstation.vm.provision "shell", inline: $script

      workstation.vm.provision "shell", 
        env: {
          "LAB_DOMAIN" => @settings["network"]["lab_domain"],
          "POD_CIDR" => @settings["network"]["pod_cidr"],
          "SERVICE_CIDR" => @settings["network"]["service_cidr"],
          "DNS_SERVERS" => @settings["network"]["dns_servers"].join(" "),
          "KUBERNETES_VERSION" => @settings["application"]["kubernetes"]
        },
        path: "scripts/workstation.sh"
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

  $script = <<-SCRIPT
    apt-get update -y
    apt-get dist-upgrade -y
    apt-get install jq vim bash-completion -y
  SCRIPT

  config.vm.box_check_update = true
  config.vm.provision "shell", inline: $script
  config.vm.provision :reload    

  kubernetesLab.createLoadbalancer(config)
  kubernetesLab.createControlPlane(config)
  kubernetesLab.createWorkerNode(config)
  kubernetesLab.createWorkstation(config)  

  config.vm.provision "shell",
    run: "always",
    inline: "swapoff -a"

end
