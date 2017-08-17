#!/bin/bash
# This script manages the builds of kameleon recipes, pushed to the kameleon
# web server.
#
# Builds are pushed from Grid'5000, see the kameleonbuilder jenkins script
#
# This script is to be used with inoticoming, in a crontab as follows:
#
# @reboot inoticoming --logfile $HOME/logs/inoticoming.log $HOME/incoming/
# --chdir $HOME/incoming/ --stdout-to-log --stderr-to-log --suffix .manifest
# $HOME/bin/build-receiver.sh {} \;
#
# The incoming directory can be populated using ssh/scp, with restrictions in
# the the authorized_keys as follows:
#
# no-agent-forwarding,no-X11-forwarding,command="scp -t incoming/" ssh-rsa
# AAA...

set -e
sync
MANIFEST=$1
INCOMING=~/incoming
BUILDS=~/builds
KEEP=2
PREFIX="${MANIFEST%_*}_"
echo "Received build: $MANIFEST"
if [ -e $BUILDS/$MANIFEST ]; then
  echo "Error: $MANIFEST already exists." 1>&2
  exit 1
fi
for f in $(< $MANIFEST); do
  mv -v $f $BUILDS/
  if [[ ${f##*.} =~ sha[[:digit:]]+sum ]]; then
    gpg --output $BUILDS/$f.sign --detach-sign $BUILDS/$f
  fi
done
mv -v $MANIFEST $BUILDS/
cd $BUILDS
gpg --output $MANIFEST.sign --detach-sign $MANIFEST
ln -sf $MANIFEST ${PREFIX}latest.manifest
ln -sf $MANIFEST.sign ${PREFIX}latest.manifest.sign

# House keeping: only keep $KEEP builds for recipe
for m in $(ls -t $PREFIX*.manifest | grep -v latest.manifest | tail -n+$((KEEP+1))); do
  for f in $(< $m); do
    rm -v $f
    if [[ ${f##*.} =~ sha[[:digit:]]+sum ]]; then
       rm -v $f.sign
    fi
  done
  rm -v $m $m.sign
done
