#
# This file is used to configure the kameleon project. It contains
# come minimal configuration examples for working with Omnibus. For a full list
# of configurable options, please see the documentation for +omnibus/config.rb+.
#

# Build internally
# ------------------------------
# By default, Omnibus uses system folders (like +/var+ and +/opt+) to build and
# cache compontents. If you would to build everything internally, you can
# uncomment the following options. This will prevent the need for root
# permissions in most cases. You will also need to update the kameleon
# project configuration to build at +./local/omnibus/build+ instead of
# +/opt/kameleon+
#

cache_dir              '/var/cache/omnibus/cache'
install_path_cache_dir '/var/cache/omnibus/cache/install_path'
source_dir             '/var/cache/omnibus/src'
build_dir              '/var/cache/omnibus/build'
package_dir            '/var/cache/omnibus/pkg'
package_tmp            '/var/cache/omnibus/pkg-tmp'

# Customize compiler bits
# ------------------------------
# solaris_compiler 'gcc'
# build_retries 5
