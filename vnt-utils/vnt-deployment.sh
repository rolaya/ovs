#!/bin/sh

# This setting "drives" how the VNT framework scripts are executed (bash console/java application)
CONSOLE_MODE=true

# This setting determines whether a "menuing" system is displayed at the console
DISPLAY_API_MENUS=true

# CONSOLE_MODE environment variable not set?
if [[ -z "$CONSOLE_MODE" ]]; then
  CONSOLE_MODE=true
  DISPLAY_API_MENUS=true
fi

# CONSOLE_MODE environment variable not set?
if [[ "$CONSOLE_MODE" == true ]]; then

  # Source host and environment specific VNT configuration
  source "ui-utils.sh"

  # Echo name of file being sourced
  this_script_name=`basename -- $BASH_SOURCE`
  source_file_message "Sourcing file:" "$this_script_name"
fi

#==================================================================================================================
#
#=================================================================================================================
function vnt_deployment_read_configuration()
{
  # All global script files are defined here
  source "vnt-scripts.sh"

  # Source common helpers
  source "$g_common_utils_script_file"

  # Source qos helpers
  source "$g_qos_utils_script_file"

  # Source OVS helpers
  source "$g_ovs_utils_script_file"

  # Source KVM helpers
  source "$g_kvm_utils_script_file"

  # Source KVM helpers
  source "$g_vnt_utils_script_file"
}

# Executing form bash console?
if [[ "$CONSOLE_MODE" == "true" ]]; then

  # Capture time when file was sourced 
  g_sourced_datetime="$(date +%c)"

  # Provision environment based on configuration file
  vnt_deployment_read_configuration
fi

