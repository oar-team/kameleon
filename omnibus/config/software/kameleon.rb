# This is an example software definition for a Ruby project.
#
# Lots of software definitions for popular open source software
# already exist in `opscode-omnibus`:
#
#  https://github.com/opscode/omnibus-software/tree/master/config/software
#
name "kameleon"
default_version "2.0.0"

dependency "ruby"
dependency "bundler"
dependency "rsync"

source :git => "git://github.com/oar-team/kameleon.git"

relative_path "kameleon"

build do
  command "git checkout #{default_version}"
  bundle "install --path=#{install_dir}/embedded/service/gem"
  command "mkdir -p #{install_dir}/embedded/service/kameleon"
  command "#{install_dir}/embedded/bin/rsync -a --delete --exclude=.git/*** --exclude=.gitignore ./ #{install_dir}/embedded/service/kameleon/"
end
