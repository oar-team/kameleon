# -*- mode: ruby -*-
# vi: set ft=ruby :


# Require vagrant-libvirt plugin
ENV['VAGRANT_DEFAULT_PROVIDER'] = 'kvm'

Vagrant.configure("2") do |config|
  config.vm.box = "oar-team/kameleon-dev"
  config.vm.hostname = "kameleon-devel"

  config.vm.provision "docker", images: ["scratch"]

  config.ssh.forward_x11 = true
  config.ssh.forward_agent = true

  config.vm.provider :libvirt do |libvirt|
    libvirt.connect_via_ssh = false
    libvirt.storage_pool_name = "default"
    libvirt.memory = 2048
    libvirt.cpus = 2
    libvirt.nested = true
    libvirt.volume_cache = 'none'
  end

  config.vm.synced_folder ".", "/home/vagrant/kameleon"

  config.vm.provision "shell", privileged: false, inline: <<-EOF
    cd /home/vagrant/kameleon && bundle install
  EOF


  # Network
  config.vm.network :private_network, ip: "10.10.20.130"
  # proxy cache with polipo
  if Vagrant.has_plugin?("vagrant-proxyconf")
    config.proxy.http = "http://10.10.20.1:3128/"
    config.proxy.https = "http://10.10.20.1:3128/"
    config.proxy.ftp = "http://10.10.20.1:3128/"
    config.proxy.no_proxy = "localhost,127.0.0.1"
    config.apt_proxy.http  = "http://10.10.20.1:3128/"
    config.apt_proxy.https = "http://10.10.20.1:3128/"
    config.apt_proxy.ftp = "http://10.10.20.1:3128/"
  end

  if Vagrant.has_plugin?("vagrant-cachier")
    # Configure cached packages to be shared between instances of the same base box.
    # More info on http://fgrehm.viewdocs.io/vagrant-cachier/usage
    config.cache.scope = :box

    # If you are using VirtualBox, you might want to use that to enable NFS for
    # shared folders. This is also very useful for vagrant-libvirt if you want
    # bi-directional sync
    config.cache.synced_folder_opts = {
      type: :nfs,
      # The nolock option can be useful for an NFSv3 client that wants to avoid the
      # NLM sideband protocol. Without this option, apt-get might hang if it tries
      # to lock files needed for /var/cache/* operations. All of this can be avoided
      # by using NFSv4 everywhere. Please note that the tcp option is not the default.
      mount_options: ['rw', 'vers=3', 'tcp', 'nolock']
    }
  end

end
