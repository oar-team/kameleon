# This is an example software definition for a C project.
#
# Lots of software definitions for popular open source software
# already exist in `opscode-omnibus`:
#
#  https://github.com/opscode/omnibus-software/tree/master/config/software
#
name "polipo"
default_version "1.0.3"


source :url => "http://freehaven.net/~chrisd/polipo/polipo-1.0.3.tar.gz",
       :md5 => "a0b00ca01541cf77ff3d725c27cf68bb"

relative_path 'polipo-1.0.3'

prefix="#{install_dir}/embedded"
libdir="#{prefix}/lib"

env = {
  "LDFLAGS" => "-L#{libdir} -I#{prefix}/include",
  "CFLAGS" => "-L#{libdir} -I#{prefix}/include -fPIC",
  "LD_RUN_PATH" => libdir
}

build do
  command "sed -i 's/^LOCAL_ROOT = \/usr\/share\/polipo\/www/LOCAL_ROOT = \$\(PREFIX\)\/usr\/share\/polipo\/www/g' Makefile"
  command "make -j #{max_build_jobs} PREFIX=#{prefix} all", :env => env
  command "make -j #{max_build_jobs} PREFIX=#{prefix} install", :env => env
end
