#!/bin/sh

###################################################################################################################
# Common global utils file.
g_common_utils_config_file="common-utils.sh"
###################################################################################################################

###################################################################################################################
# The global OVS configuration file.
g_ovs_utils_config_file="ovs-utils.sh"
###################################################################################################################

###################################################################################################################
# The global KVM configuration file.
g_kvm_utils_config_file="kvm-utils.sh"
###################################################################################################################

# This setting "drives" how the VNT framework scripts are executed (bash console/java application)
CONSOLE_MODE=true

# This setting determines whether a "menuing" system is displayed at the console
DISPLAY_API_MENUS=true

#==================================================================================================================
#
#=================================================================================================================
function vnt_deployment_read_configuration()
{
  # Generic/common UI utils
  source "ui-utils.sh"

  # Source common helpers
  source "$g_common_utils_config_file"

  # Source common helpers
  source "$g_common_utils_config_file"

  # Source OVS helpers
  source "$g_ovs_utils_config_file"

  # Source KVM helpers
  source "$g_kvm_utils_config_file"

  # Source VNT utils (main menu)
  source "$g_vnt_utils_config_file"  
}

# Executing form bash console?
if [[ "$CONSOLE_MODE" == "true" ]]; then

  # Capture time when file was sourced 
  g_sourced_datetime="$(date +%c)"

  # Provision environment based on configuration file
  vnt_deployment_read_configuration
fi

