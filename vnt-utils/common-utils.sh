#!/bin/sh

# Generic/common UI utils
source "ui-utils.sh"

###################################################################################################################
# The global OVS configuration file.
g_ovs_config_file="ovs-utils.sh"
###################################################################################################################

###################################################################################################################
# The global KVM configuration file.
g_kvm_config_file="kvm-utils.sh"
###################################################################################################################

#==================================================================================================================
# 
#==================================================================================================================
vm_name_to_port_number()
{
  local kvm_name=$1
  local port_number=0
  local pattern="s/${VM_BASE_NAME}//g"

  # Given a KVM node name (e.g. kvm-vnt-node1) return its port number (1 less than the name index)
  port_number=$(echo "$kvm_name" | sed "$pattern")
  port_number=$((port_number-1))

  # Return port number to caller.
  eval "$2=$port_number"
}

#==================================================================================================================
# 
#==================================================================================================================
vm_name_to_port_name()
{
  local kvm_name=$1
  local pnumber=0
  local port_name=""

  # Given KVM name, gets its corresponding port number
  vm_name_to_port_number $kvm_name pnumber

  # Format the port name for the KVM (something like "vnet0")
  port_name="$OVS_PORT_NAME_BASE$pnumber"
  
  echo "node name: [$kvm_name]"
  echo "port name: [$port_name]"

  # Return port name to caller.
  eval "$2=$port_name"
}

