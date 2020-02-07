#!/bin/sh

# Source host and environment specific VNT configuration
source "ui-utils.sh"

# The global configuration file for CentOS VNT VM
g_centos_config_file="config.env.kvm_vnt_vm"

#==================================================================================================================
#
#==================================================================================================================
centos_describe_provisioning()
{
  local datetime=""

  # Environment 
  echo
  echo -e "${TEXT_VIEW_NORMAL_GREEN}Environment"
  echo "=========================================================================================================================="
  echo -e "${TEXT_VIEW_NORMAL}"

  # Get date/time (useful for keeping track of changes)
  datetime="$(date +%c)"

  echo "Configuration file:              [$g_centos_config_file]"
  echo "Host name:                       [$HOSTNAME]"
  echo "Sourced time:                    [$g_sourced_datetime]"
  echo "Current time:                    [$datetime]"
  echo "KVM VNT VM name:                 [$KVM_VNT_VM_NAME]"
  echo

  show_config_section "General system configuration"

  nfs_show_config_item "update /etc/hosts as required to access hosts in local network by name (sudo required)"
  nfs_show_config_item "sudo yum update"
  nfs_show_config_item "sudo yum group install \"Virtualization Host\""
  nfs_show_config_item "sudo yum install git"
}

#==================================================================================================================
#
#==================================================================================================================
function kvm_read_configuration()
{
  # Source host and environment specific VNT configuration
  source "$g_centos_config_file"
}

# Capture time when file was sourced 
g_sourced_datetime="$(date +%c)"

# Provision environment based on configuration file
kvm_read_configuration

# Display helper "menu"
centos_describe_provisioning