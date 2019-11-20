#!/bin/sh

ovs_override_kernel_modules()
{
	config_file="/etc/depmod.d/openvswitch.conf"

	for module in datapath/linux/*.ko; do
		modname="$(basename ${module})"
		echo "override ${modname%.ko} * extra" >> "$config_file"
		echo "override ${modname%.ko} * weak-updates" >> "$config_file"
	done
}

ovs_config_db()
{
	mkdir -p /usr/local/etc/openvswitch
	ovsdb-tool create /usr/local/etc/openvswitch/conf.db vswitchd/vswitch.ovsschema
}


ovs_start_db_server()
{
	mkdir -p /usr/local/var/run/openvswitch

	ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock \
	    --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
	    --private-key=db:Open_vSwitch,SSL,private_key \
	    --certificate=db:Open_vSwitch,SSL,certificate \
	    --bootstrap-ca-cert=db:Open_vSwitch,SSL,ca_cert \
	    --pidfile --detach --log-file
}


