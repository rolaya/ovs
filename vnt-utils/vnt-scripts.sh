#!/bin/sh

# VNT_SCRIPTS_SOURCED?
if [[ -z "$VNT_SCRIPTS_SOURCED" ]]; then
  
  # Helps source only once.
  VNT_SCRIPTS_SOURCED=true

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

  ###################################################################################################################
  # Common global utils file.
  g_common_utils_script_file="common-utils.sh"
  ###################################################################################################################

  ###################################################################################################################
  # The global qos utils file.
  g_qos_utils_script_file="qos-utils.sh"
  ###################################################################################################################

  ###################################################################################################################
  # The global OVS utils file.
  g_ovs_utils_script_file="ovs-utils.sh"
  ###################################################################################################################

  ###################################################################################################################
  # The global KVM utils file.
  g_kvm_utils_script_file="kvm-utils.sh"
  ###################################################################################################################

  ###################################################################################################################
  # The global VNT utils file.
  g_vnt_utils_script_file="vnt-utils.sh"
  ###################################################################################################################
fi
