# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.hostname = "boot2kameleon-lab"

  config.vm.define "vm64" do |c|
    c.vm.box = "ubuntu/trusty64"
  end

  config.vm.define "vm32" do |c|
    c.vm.box = "ubuntu/trusty32"
  end

  # share src folder with all nodes
  config.vm.synced_folder ".", "/vagrant"

  # enable ssh forward agent for all VMs
  config.ssh.forward_agent = true

  # Config provider
  config.vm.provider :virtualbox do |vm|
    vm.memory = 2048
    vm.cpus = 2
  end

  config.vm.provision "shell", :privileged => true, :inline  => <<-SCRIPT
    apt-get update
    apt-get -y install busybox-static adduser bzip2 xz-utils nano insserv \
               module-init-tools sudo cpio syslinux xorriso debootstrap rsync

    cd /vagrant/
    # Download base debian rootfs

    /vagrant/buildboot/make.sh
  SCRIPT

  if Vagrant.has_plugin?("vagrant-proxyconf")
    config.proxy.http     = "http://10.0.2.2:8123/"
    config.proxy.https     = "http://10.0.2.2:8123/"
    config.proxy.ftp     = "http://10.0.2.2:8123/"
    config.proxy.no_proxy = "localhost,127.0.0.1"
  end

end
