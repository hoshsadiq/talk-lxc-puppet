#!/usr/bin/env bash

set -x
set -e

# Setup en-GB locale
sudo locale-gen en_GB.UTF-8

# Add the LXC PPAs to the apt
sudo add-apt-repository -y ppa:ubuntu-lxc/lxd-stable

# Update and upgrade
sudo apt-get update
sudo apt-get dist-upgrade -y


sudo apt-get install -y build-essential linux-headers-$(uname -r)
sudo apt-get install -y bsdtar

rm -rf $HOME/lxc-puppet-tech-talk
mkdir $HOME/lxc-puppet-tech-talk
curl -L https://github.com/hoshsadiq/lxc-puppet-tech-talk/archive/master.zip | bsdtar -xvf - --strip-components=1 -C $HOME/lxc-puppet-tech-talk


# Install LXC
sudo apt-get install lxc lxc-templates uidmap

# Give lxc a pool of uids and gids to use.
# This means essentially means that all ids (uids and gids) are offset by the first number, and up until the second number
# For example, uid 0 in the container is actually assigned uid 100000 in the host.
sudo usermod --add-subuids 100000-165535 $USER
sudo usermod --add-subgids 100000-165535 $USER

# Required for some reason
sudo chmod +x $HOME

# Set up unprivileged configuration
mkdir -p $HOME/.config/lxc
cp $HOME/lxc-puppet-tech-talk/setup/default.conf $HOME/.config/lxc/default.conf
echo "$USER veth lxcbr0 10" | sudo tee -a /etc/lxc/lxc-usernet
