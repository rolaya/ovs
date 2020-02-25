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
vnt_utils_show_menu()
{
  local datetime=""
  local first_vm="1"

  # Environment 
  echo
  echo -e "${TEXT_VIEW_NORMAL_GREEN}Environment"
  echo "=========================================================================================================================="
  echo -e "${TEXT_VIEW_NORMAL}"

  # Get date/time (useful for keeping track of changes)
  datetime="$(date +%c)"

  echo "KVM host configuration file:   [$g_kvm_host_config_file]"
  echo "Host name:                     [$HOSTNAME]"
  echo "Sourced time:                  [$g_sourced_datetime]"
  echo "Current time:                  [$datetime]"

  echo
  echo "Number of KVMs:                [$NUMBER_OF_VMS]"
  echo "KVM base name:                 [$VM_BASE_NAME]"
  echo "KVM range:                     [$VM_BASE_NAME$first_vm..$VM_BASE_NAME$NUMBER_OF_VMS]"
  echo "KVM port range:                [$OVS_PORT_NAME_BASE$OVS_PORT_INDEX_BASE..$OVS_PORT_NAME_BASE$((NUMBER_OF_VMS-1))]"
  echo

  # KVM guest (VNT network node) deployment
  echo
  echo -e "${TEXT_VIEW_NORMAL_GREEN}KVM guest management"
  echo "=========================================================================================================================="
  echo -e "${TEXT_VIEW_NORMAL}"
  show_menu_option "kvm_list     " " - \"$HOSTNAME\" guest list"
  show_menu_option "kvm_start    " " - \"$KVM_GUEST_NAME\" guest start"
  show_menu_option "kvm_shutdown " " - \"$KVM_GUEST_NAME\" guest shutdown"
  echo
}

#==================================================================================================================
#
#=================================================================================================================
function vnt_read_configuration()
{
  # Source OVS helpers
  source "$g_ovs_config_file"

  # Source KVM helpers
  source "$g_ovs_config_file"
}

# Capture time when file was sourced 
g_sourced_datetime="$(date +%c)"

# Provision environment based on configuration file
vnt_read_configuration

# Display helper "menu"
vnt_utils_show_menu
