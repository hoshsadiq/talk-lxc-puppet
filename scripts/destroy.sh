#!/usr/bin/env bash

set -x

WORKING_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

[ -f "$WORKING_DIR/config" ] && source $WORKING_DIR/config

remove_container() {
	container_name="$1"
	lxc-stop --name $container_name
	lxc-destroy --name $container_name
}

killall ssh # properly??
remove_container "$master_container_name"
remove_container "$agent_container_name"
