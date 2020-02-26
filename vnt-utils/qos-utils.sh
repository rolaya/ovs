#!/bin/sh

#set -x			# activate debugging from here

# Source host and environment specific VNT configuration
source "ui-utils.sh"

# The network interface configuration file. Modify as per host.
g_net_iface_config_file="config.env.net-iface"

# The VNT configuration file. Modify VNT configuration
g_vnt_config_file="config.env.vnt"

# QoS information (from qos table)
qos_info_uuid=""
qos_info_external_ids=""
qos_info_other_config=""
qos_info_queues=""
qos_info_type=""

#==================================================================================================================
#
#==================================================================================================================
port_log_qos_info()
{
  local kvm=$1

  echo "kvm:          [$kvm]"
  echo "_uuid:        [${qos_info_uuid}]"
  echo "external_ids: [${qos_info_external_ids}]"
  echo "other_config: [${qos_info_other_config}]"
  echo "queues:       [${qos_info_queues}]"
  echo "type:         [${qos_info_type}]"
}

#==================================================================================================================
#
#==================================================================================================================
port_get_qos_info()
{
  local command=""
  local kvm=$1
  local qos_uuid=""
  local qos_defined=false
  local table=""
  local qos=""
  local port_number=0
  local pname=""
  local qos_type=""
  local other_config=""

  echo "VM:                 [$kvm]"
  echo "qos:                [$qos]"
  echo "qos type:           [$qos_type]"

  # Get port name from kvm name
  vm_name_to_port_name $kvm pname

  echo "port name:          [$pname]"

  # Find record in "port" table
  table="port"
  condition="name=$pname"
  ovs_table_find_record $table "$condition" uuid

  # QoS configured?
  if [[ "$uuid" != "" ]]; then

    # Get qos uuid associated with port
    ovs_table_get_value $table $uuid "qos" qos_uuid

    # Remove [] from value
    qos_uuid=$(echo "$qos_uuid" | sed 's/\[//g')
    qos_uuid=$(echo "$qos_uuid" | sed 's/\]//g')
  
    if [[ "$qos_uuid" != "" ]]; then
      
      qos_defined=true

      # Find qos report given uuid
      table="qos"

      # Get qos type and "other_config" (e.g. latency, etc)
      ovs_table_get_value $table $qos_uuid "type" qos_type
      ovs_table_get_value $table $qos_uuid "other_config" other_config

      # Remove {} from value (for something like "{latency="500000"} we will end up with "latency="500000").
      other_config=$(echo "$other_config" | sed 's/{//g')
      other_config=$(echo "$other_config" | sed 's/}//g')      
      
      # Save misc. information in globals
      qos_info_uuid=$qos_uuid
      qos_info_external_ids=""
      qos_info_other_config=$other_config
      qos_info_queues=""
      qos_info_type=$qos_type

      port_log_qos_info $kvm
    fi
  fi
}








