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
echo "Received build: $MANIFEST"
if [ -e $BUILDS/$MANIFEST ]; then
  echo "Error: $MANIFEST already exists." 1>&2
  exit 1
fi
for f in $(< $MANIFEST); do
  mv -v $f $BUILDS/
done
mv -v $MANIFEST $BUILDS/

# House keeping: only keep $KEEP builds for recipe
cd $BUILDS
PREFIX="${MANIFEST%_*}_"
for i in $(find $BUILDS/ -name "$PREFIX*.manifest" | sed "s@^$BUILDS/$PREFIX@@" | sort -nr | tail -n+$((KEEP+1)) ); do
  manifest=$BUILDS/$PREFIX$i
  for f in $(< $manifest); do
    rm -v $f
  done
  rm -v $manifest
done
