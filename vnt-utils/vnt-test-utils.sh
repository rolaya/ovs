#!/bin/sh

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
#==================================================================================================================
vnt_test_utils_show_menu()
{
  local datetime=""
  local first_vm="1"

  # Environment 
  echo
  echo -e "${TEXT_VIEW_NORMAL_GREEN}VNT Platform Test Utils Environment"
  echo "=========================================================================================================================="
  echo -e "${TEXT_VIEW_NORMAL}"

  # Get date/time (useful for keeping track of changes)
  datetime="$(date +%c)"

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
  echo -e "${TEXT_VIEW_NORMAL_GREEN}VNT Platform Test Utils management"
  echo "=========================================================================================================================="
  echo -e "${TEXT_VIEW_NORMAL}"
  show_menu_option "vnt_lauch_iperf_servers    " " - Launch [$((NUMBER_OF_VMS+1))] iperf servers"
}

#==================================================================================================================
# 
#==================================================================================================================
vnt_lauch_iperf_servers()
{
  local command=""
  local base_port=5000
  local ipert_server_port=0

  # Start "NUMBER_OF_VMS=1" iperf3 servers on (ports staring at 5001)
  for ((i = 1; i <= $((NUMBER_OF_VMS+1)); i++)) do

    ipert_server_port=$((base_port+i))
    message "starting iperf3 on port: [$ipert_server_port]..." "$TEXT_VIEW_NORMAL_GREEN"

    command="iperf3 -s -D -V -p $ipert_server_port"
    echo "executing: [$command]..."
    $command
  
  done
}

#==================================================================================================================
#
#=================================================================================================================
function vnt_test_utils_read_configuration()
{
  # All global script files are defined here
  source "vnt-scripts.sh"

  # Source common helpers
  source "$g_common_utils_script_file"

  # Source OVS helpers
  source "$g_ovs_utils_script_file"

  # Source KVM helpers
  source "$g_kvm_utils_script_file"
}

# Executing form bash console?
if [[ "$CONSOLE_MODE" == "true" ]]; then

  # Capture time when file was sourced 
  g_sourced_datetime="$(date +%c)"

  # Provision environment based on configuration file
  vnt_test_utils_read_configuration

  if [[ "$DISPLAY_API_MENUS" == "true" ]]; then

    # Display helper "menu"
    vnt_test_utils_show_menu
  fi
fi
