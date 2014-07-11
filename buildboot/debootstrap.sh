#debootstrap

SUITE=jessie
MIRROR=http://ftp.debian.org/debian
PACKAGES="apt-utils ca-certificates isc-dhcp-client isc-dhcp-common ifupdown
          iproute2 openssh-server xz-utils systemd systemd-sysv"

if [ "$(uname -m)" == "i686" ] ; then
    PACKAGES="linux-image-486 $PACKAGES"
    ARCH="i386"
else
    PACKAGES="linux-image-amd64 $PACKAGES"
    ARCH="amd64"
fi

echo "---> debootstrapping"

if [ ! -f "$1/.kameleon_timestamp" ]; then
    sudo debootstrap --include="$PACKAGES" --arch $ARCH --variant=minbase $SUITE $1 $MIRROR
    sudo date +%s > $1/.kameleon_timestamp
fi

cat /etc/resolv.conf > $1/etc/resolv.conf
