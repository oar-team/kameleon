# -*- mode: ruby -*-
# vi: set ft=ruby :


Vagrant.configure("2") do |config|
  config.vm.box = "hashicorp/precise64"
  config.vm.hostname = "kameleon-devel"

  # Config provider
  config.vm.provider :virtualbox do |vm|
    vm.memory = 2024
    vm.cpus = 2
  end

  # shared folders
  config.vm.synced_folder ".", "/vagrant", type: "nfs"

  # Provision
  config.vm.provision "shell", privileged: true, inline: <<-EOF
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get -y --force-yes install git python-pip debootstrap \
      rsync sed qemu-utils parted

    apt-get -y --force-yes install ruby1.9.1 ruby1.9.1-dev \
      rubygems1.9.1 build-essential libopenssl-ruby1.9.1 libssl-dev zlib1g-dev

    update-alternatives --install /usr/bin/ruby ruby /usr/bin/ruby1.9.1 400 \
             --slave   /usr/share/man/man1/ruby.1.gz ruby.1.gz \
                            /usr/share/man/man1/ruby1.9.1.1.gz \
            --slave   /usr/bin/ri ri /usr/bin/ri1.9.1 \
            --slave   /usr/bin/irb irb /usr/bin/irb1.9.1 \
            --slave   /usr/bin/rdoc rdoc /usr/bin/rdoc1.9.1

    # choose your interpreter
    # changes symlinks for /usr/bin/ruby , /usr/bin/gem
    # /usr/bin/irb, /usr/bin/ri and man (1) ruby
    update-alternatives --set ruby /usr/bin/ruby1.9.1

    gem install bundle

    # Helpful tools
    pip install pyped
  EOF

  config.vm.provision "shell", privileged: false, inline: <<-EOF
    cat > ~/.bash_profile <<< "
    export FORCE_AUTOENV=1
    source ~/.profile
    source /vagrant/.env
    cd /vagrant
    "
    cd /vagrant && git stash && bundle install && git stash pop
  EOF

  config.ssh.forward_agent = true

  # Network
  config.vm.network :private_network, ip: "10.10.20.130"
  # proxy cache with polipo
  if Vagrant.has_plugin?("vagrant-proxyconf")
    config.proxy.http = "http://10.10.10.1:8123/"
    config.proxy.https = "http://10.10.10.1:8123/"
    config.proxy.ftp = "http://10.10.10.1:8123/"
    config.proxy.no_proxy = "localhost,127.0.0.1"
    config.apt_proxy.http  = "http://10.10.10.1:8123/"
    config.apt_proxy.https = "http://10.10.10.1:8123/"
    config.apt_proxy.ftp = "http://10.10.10.1:8123/"
  end
end
