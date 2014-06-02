# -*- mode: ruby -*-
# vi: set ft=ruby :


# Require vagrant-kvm plugin
ENV['VAGRANT_DEFAULT_PROVIDER'] = 'kvm'

Vagrant.configure("2") do |config|
  config.vm.box = "oar-team/kameleon-dev"
  config.vm.hostname = "kameleon-devel"

  config.vm.provision "docker", images: ["scratch"]

  config.ssh.forward_x11 = true
  config.ssh.forward_agent = true

  config.vm.provider :kvm do |kvm|
    kvm.memory_size = "2GiB"
    kvm.core_number = 2
  end

  config.vm.synced_folder ".", "/home/vagrant/kameleon"

  config.vm.provision "shell", privileged: false, inline: <<-EOF
    cd /home/vagrant/kameleon && bundle install
  EOF

end
