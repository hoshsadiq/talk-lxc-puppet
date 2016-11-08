#!/usr/bin/env bash

set -x

[ -f ./config ] && source ./config

WORKING_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

create_container() {
	container_name="$1"
	lxc-create --template download --name "$container_name" -- --dist ubuntu --release trusty --arch amd64
	lxc-start --name "$container_name" --daemon
	sleep 5 # todo better way of determining the container has an ip

	lxc-attach --name $container_name -- mkdir /root/.ssh
	cat ~/.ssh/id_rsa.pub | lxc-attach --name "$container_name" -- tee -a /root/.ssh/authorized_keys
	lxc-attach --name $container_name -- chmod 600 /root/.ssh
	lxc-attach --name $container_name -- apt-get update
	lxc-attach --name $container_name -- apt-get install -y openssh-server

	ip_address="$(lxc-info --name "$container_name" --ips --no-humanize)"

	lxc-attach --name $container_name -- wget https://apt.puppetlabs.com/puppetlabs-release-trusty.deb
	lxc-attach --name $container_name -- dpkg -i puppetlabs-release-trusty.deb
	lxc-attach --name $container_name -- apt-get update
}

get_container_ip() {
	container_name="$1"

	lxc-info --name "$container_name" --ips --no-humanize
}

write_ssh_config() {
	ip_master="$1"
	ip_node="$2"

	echo "Host *
    KeepAlive yes
    ServerAliveInterval 60
    PubkeyAuthentication yes
    IdentitiesOnly yes
    ForwardAgent no
    ForwardX11 no
    ForwardX11Trusted no
    Protocol 2

    Host master
	    user root
	    HostName $ip_master

    Host node
	    user root
	    HostName $ip_node
	" | tee "$WORKING_DIR/ssh_config"
}

setup_master() {
	container_name="$1"

	lxc-attach --name $container_name -- apt-get install -y puppetmaster-passenger
	lxc-attach --name $container_name -- puppet resource package puppetmaster ensure=latest
	lxc-attach --name $container_name -- sed -i "/template/s/templatedir=.*\$/dns_alt_names=puppet,$container_name/" /etc/puppet/puppet.conf

	echo '---
	:logger: puppet
	:backends:
	  - yaml
	:yaml:
	  :datadir: /etc/puppet/hieradata
	:hierarchy:
	  - "node/%{::fqdn}"
	  - common
	' | lxc-attach --name $container_name -- tee /etc/puppet/hiera.yaml
	lxc-attach --name $container_name -- mkdir -p /etc/puppet/hieradata/node

	# hiera cli is useful but cli looks for /etc/hiera.yaml rather that /etc/puppet/hiera.yaml
	# so we make /etc/hiera.yaml link to our proper config so it's consistent
	lxc-attach --name $container_name -- ln -nfs /etc/puppet/hiera.yaml /etc/hiera.yaml
}

setup_agent() {
	container_name="$1"

	lxc-attach --name $container_name -- apt-get install -y puppet
	lxc-attach --name $container_name -- sed -i "/template/s/templatedir=.*\$/server=$master_container_name\nruninterval=1/" /etc/puppet/puppet.conf
	lxc-attach --name $container_name -- sed -i '/^START=/s/no/yes/' /etc/default/puppet
	lxc-attach --name $container_name -- sed -i '/\(^\[master\]\)/,$d' /etc/puppet/puppet.conf
	echo "[agent]
server = $master_container_name" | lxc-attach --name $container_name -- tee -a /etc/puppet/puppet.conf

	lxc-attach --name $container_name -- service puppet restart
}

setup_hosts() {
	ip_master="$1"
	master_hostname="$2"
	ip_node="$3"
	agent_hostname="$4"
	sudo sed -i '/tesco.com$/d' /etc/hosts

	echo "$ip_master $master_hostname" | sudo tee -a /etc/hosts
	echo "$ip_node $agent_hostname" | sudo tee -a /etc/hosts
	echo "$ip_master $master_hostname" | lxc-attach --name $agent_hostname -- tee -a /etc/hosts
	echo "$ip_node $agent_hostname" | lxc-attach --name $master_hostname -- tee -a /etc/hosts
}

register_node_on_master() {
	agent_container_name="$1"
	master_container_name="$2"

	lxc-attach --name $agent_container_name -- puppet agent -t
	lxc-attach --name $master_container_name -- puppet cert list
	lxc-attach --name $master_container_name -- puppet cert sign $agent_container_name
	lxc-attach --name $agent_container_name -- puppet agent -t
	lxc-attach --name $agent_container_name -- puppet agent --enable
}

echo "Checking for sudo for certain actions!"
sudo test

create_container "$master_container_name"
create_container "$agent_container_name"

ip_master="$(get_container_ip $master_container_name)"
ip_node="$(get_container_ip $agent_container_name)"

setup_master "$master_container_name"
setup_agent "$agent_container_name"

write_ssh_config "$ip_master" "$ip_node"
setup_hosts "$ip_master" "$master_container_name" "$ip_node" "$agent_container_name"
register_node_on_master "$agent_container_name" "$master_container_name"

