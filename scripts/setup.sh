#!/usr/bin/env bash

set -x
set -e

sudo locale-gen en_GB.UTF-8

sudo add-apt-repository -y ppa:ubuntu-lxc/lxd-stable
sudo apt-get update
sudo apt-get dist-upgrade -y
sudo apt-get install -y build-essential linux-headers-$(uname -r)
sudo apt-get install -y bsdtar

rm -rf $HOME/lxc-puppet-tech-talk
mkdir $HOME/lxc-puppet-tech-talk
curl -L https://github.com/hoshsadiq/lxc-puppet-tech-talk/archive/master.zip | bsdtar -xvf - --strip-components=1 -C $HOME/lxc-puppet-tech-talk


# set up lxc
sudo apt-get install lxc lxc-templates uidmap

sudo usermod --add-subuids 100000-165535 $USER
sudo usermod --add-subgids 100000-165535 $USER
sudo chmod +x $HOME

mkdir -p $HOME/.config/lxc
cp $HOME/lxc-puppet-tech-talk/setup/default.conf $HOME/.config/lxc/default.conf
echo "$USER veth lxcbr0 10" | sudo tee -a /etc/lxc/lxc-usernet
