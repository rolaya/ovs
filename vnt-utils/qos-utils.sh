#!/bin/sh

#set -x			# activate debugging from here

###################################################################################################################
# Common global utils file.
g_common_utils_config_file="common-utils.sh"
###################################################################################################################

# The network interface configuration file. Modify as per host.
g_net_iface_config_file="config.env.net-iface"

# The VNT configuration file. Modify VNT configuration
g_vnt_config_file="config.env.vnt"

# QoS information (from qos table)
g_qos_info_port_number=""
g_qos_info_port_name=""
g_qos_info_kvm_name=""
g_qos_info_uuid=""
g_qos_info_external_ids=""
g_qos_info_other_config=""
g_qos_info_queues=""
g_qos_info_type=""

# Array of "other_config"
unset g_qos_info_other_config_array

# Array of "ingress_policing*"
unset g_qos_ingress_policing_config_array

#==================================================================================================================
#
#==================================================================================================================
port_log_qos_info()
{
  local port_name=$1
  local kvm_name="all"

  echo "-------------------------------------------------------------"
  echo "QoS"
  echo "-------------------------------------------------------------"
  if [[ "$port_name" != "$HOST_NETIFACE_NAME" ]]; then
    echo "kvm:          [$g_qos_info_kvm_name]"
  fi
  echo "port number:  [$g_qos_info_port_number]"
  echo "port:         [$g_qos_info_port_name]"
  echo "_uuid:        [${g_qos_info_uuid}]"
  echo "external_ids: [${g_qos_info_external_ids}]"
  echo "other_config: [${g_qos_info_other_config}]"
  echo "queues:       [${g_qos_info_queues}]"
  echo "type:         [${g_qos_info_type}]"

  qos_config_array_list_items "${g_qos_info_other_config_array[@]}"

  qos_config_array_list_items "${g_qos_ingress_policing_config_array[@]}"

  echo "-------------------------------------------------------------"
}

#==================================================================================================================
#
#==================================================================================================================
vnt_node_get_qos_info()
{
  local kvm_name=$1

  message "retrieving qos info for kvm: [$kvm_name]"

  # Get linux-netem configuration (latency, packet loss)
  vnt_node_get_qos_netem $kvm_name

  # Get linux-htb configuration (max-rate)
  #vnt_node_get_qos_htb $kvm_name

  # Get ingress policing rate configuration
  vnt_node_get_qos_ingress_policing_rate $kvm_name

  qos_config_array_list_items "${g_qos_info_other_config_array[@]}"

  qos_config_array_list_items "${g_qos_ingress_policing_config_array[@]}"
}

#==================================================================================================================
#
#==================================================================================================================
vnt_node_get_qos_netem()
{
  local kvm_name=$1
  local pname=""
  local qos_uuid=""
  local qos_defined=false
  local table=""
  local qos_type=""
  local other_config=""
  local queues=""
  local pnumber=-1

  message "retrieving netem qos info for kvm: [$kvm_name]"

  # Get port name from kvm name
  vm_name_to_port_name $kvm_name pname

  # Get port number from kvm name
  vm_name_to_port_number $kvm_name pnumber

  # Initialize all possible qos (table) related parameters, etc.
  g_qos_info_kvm_name="$kvm_name"
  g_qos_info_port_name="$pname"
  g_qos_info_port_number="$pnumber"
  g_qos_info_uuid=""
  g_qos_info_external_ids=""
  g_qos_info_other_config=""
  g_qos_info_queues=""
  g_qos_info_type=""
  unset g_qos_info_other_config_array

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
      ovs_table_get_value $table $qos_uuid "queues" queues

      # Remove {} from value (for something like "{latency="500000"} we will end up with "latency="500000").
      other_config=$(echo "$other_config" | sed 's/{//g')
      other_config=$(echo "$other_config" | sed 's/}//g')
      
      # Remove {} from value (for something like "{100=4c69fead-b0a8-4092-9cbd-a3856765b6e2}" we will end up
      # with "100=4c69fead-b0a8-4092-9cbd-a3856765b6e2".
      queues=$(echo "$queues" | sed 's/{//g')
      queues=$(echo "$queues" | sed 's/}//g')
      
      # Save misc. information in globals
      g_qos_info_uuid=$qos_uuid
      g_qos_info_external_ids=""
      g_qos_info_other_config=$other_config
      g_qos_info_queues=$queues
      g_qos_info_type=$qos_type

      # other_config configuration items are separated by IFS
      IFS=',' read -ra  g_qos_info_other_config_array <<< "$g_qos_info_other_config"  
    fi
  fi

  port_log_qos_info $pname
}

#==================================================================================================================
# Only handling max-rate at present.
#==================================================================================================================
vnt_node_get_qos_htb()
{
  local kvm_name=$1
  local pnumber=-1
  local queue_number=0
  local other_config=""

  message "retrieving htb qos info for kvm: [$kvm_name]"

  # Get port number from kvm namex
  vm_name_to_port_number $kvm_name pnumber

  # Construct the unique queue id for the kvm/linux-htb
  queue_number=${map_qos_type_params_partition["linux-htb"]}
  queue_number=$((queue_number+pnumber))
  
  # Get queue uuid (if any) associated with the kvm (max-rate information)
  ovs_port_find_qos_queue_record $pnumber $queue_number

  if [[ "$g_qos_queue_record_uuid" != "" ]]; then

    # Get qos uuid associated with port
    table="queue"
    value="other_config"
    ovs_table_get_value "queue" $g_qos_queue_record_uuid $value other_config

    # Update qos array (all possible qos for the port/vm)
    g_qos_info_other_config_array+=( "$other_config" )

  fi
}

#==================================================================================================================
#
#==================================================================================================================
vnt_node_get_qos_ingress_policing_rate()
{
  local kvm_name=$1
  local pname=""
  local table=""
  local pnumber=-1
  local ingress_policing_rate=-1

  message "retrieving ingress policing rate info for kvm: [$kvm_name]"

  # Get port name from kvm name
  vm_name_to_port_name $kvm_name pname

  # Get port number from kvm name
  vm_name_to_port_number $kvm_name pnumber

  # Initialize all possible qos (table) related parameters, etc.
  g_qos_info_kvm_name="$kvm_name"
  g_qos_info_port_name="$pname"
  g_qos_info_port_number="$pnumber"
  unset g_qos_ingress_policing_config_array

  # Find record in "interface" table
  table="interface"
  condition="name=$pname"
  ovs_table_find_record $table "$condition" uuid

  # Ingress policing rate configured?
  if [[ "$uuid" != "" ]]; then

    # Get qos uuid associated with port
    ovs_table_get_value $table $uuid "ingress_policing_rate" ingress_policing_rate

    # Update qos array (all possible qos for the port/vm)
    g_qos_ingress_policing_config_array+=( "ingress_policing_rate:$ingress_policing_rate" )    
  fi

  port_log_qos_info $pname
}

#==================================================================================================================
#
#=================================================================================================================
function qos_read_configuration()
{
  # Source host and environment specific VNT configuration
  source "ui-utils.sh"
  
  # Source common helpers
  source "$g_common_utils_config_file"
}

# Executing form bash console?
if [[ "$CONSOLE_MODE" == "true" ]]; then

  # Capture time when file was sourced 
  g_sourced_datetime="$(date +%c)"

  # Provision environment based on configuration file
  qos_read_configuration
fi
