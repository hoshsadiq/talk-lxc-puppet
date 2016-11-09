#!/usr/bin/env bash

sudo apt-get update
sudo apt-get dist-upgrade -y
sudo apt-get install -y build-essential linux-headers-$(uname -r)
sudo apt-get install -y bsdtar

vbox_installed="$(modinfo vboxguest &>/dev/null; echo $?)"

if [ "$vbox_installed" != "0" ]; then
	echo "Please insert the Virtualbox Guest Additions disk (Devices > Insert Guest Additions CD image...)"
	while [ ! -f /media/$USER/VBOXADDITIONS*/VBoxLinuxAdditions.run ]; do
		sleep 1;
	done

	sudo /media/$USER/VBOXADDITIONS*/VBoxLinuxAdditions.run
fi

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


sudo reboot


