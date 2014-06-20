
name 'kameleon'
maintainer 'Oar Team'
homepage 'http://kameleon.readthedocs.org'

replaces        'kameleon'
install_path    '/opt/kameleon'
build_version Omnibus::BuildVersion.new.semver
build_iteration 1

# creates required build directories
dependency 'preparation'

# kameleon dependencies/components
dependency "polipo"
dependency "kameleon"

# version manifest file
dependency "version-manifest"


exclude '\.git*'
exclude 'bundler\/git'
