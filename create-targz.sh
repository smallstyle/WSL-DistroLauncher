#!/bin/bash

# Set environment
set -e
ORIGINDIR=$(pwd)
TMPDIR=$(mktemp -d -p $ORIGINDIR)
ARCH="x86_64"

# Install dependencies
yum install -y mock qemu-user-static

# Move to temprary directory
cd $TMPDIR
mkdir $TMPDIR/dist

# Make sure /dev is created before later mount
mkdir -m 0755 $TMPDIR/dist/dev

# Use mock to initialise chroot filesystem
mock --init --forcearch=$ARCH --rootdir=$TMPDIR/dist -r /etc/mock/amazonlinux-2-x86_64.cfg

# Bind mount current /dev to new chroot/dev
# (fixes '/dev/null: Permission denied' errors)
mount --bind /dev $TMPDIR/dist/dev

# Install required packages, exclude unnecessary packages to reduce image size
yum --installroot=$TMPDIR/dist -y install @core libgcc glibc-langpack-en --exclude=grub\*,sssd-kcm,sssd-common,sssd-client,linux-firmware,dracut*,plymouth,parted,e2fsprogs,iprutils,iptables,ppc64-utils,selinux-policy*,policycoreutils,sendmail,kernel*,firewalld,fedora-release,fedora-logos,fedora-release-notes

# Unmount /dev
umount $TMPDIR/dist/dev

systemd-nspawn -q -D $TMPDIR/dist << EOF
yum update -y
yum install -y sudo
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wsl-users
yum autoremove -y
yum clean all -y
EOF

# Create filesystem tar, excluding unnecessary files
cd $TMPDIR/dist
tar --exclude='boot/*' --exclude='var/cache/dnf/*' --numeric-owner -czf $ORIGINDIR/install.tar.gz *

# Cleanup
rm -rf $TMPDIR