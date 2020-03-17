#!/bin/sh

# The global VNC (Virtual Network Computing client/server application) configuration file
g_vnc_config_file="config.env.vnc"

#==================================================================================================================
#
#==================================================================================================================
vnc_utils_show_menu()
{
  local datetime=""

  # Environment 
  echo
  echo -e "${TEXT_VIEW_NORMAL_GREEN}Environment"
  echo "=========================================================================================================================="
  echo -e "${TEXT_VIEW_NORMAL}"

  # Get date/time (useful for keeping track of changes)
  datetime="$(date +%c)"

  echo "Configuration file:                           [$g_vnc_config_file]"
  echo "Host name:                                    [$HOSTNAME]"
  echo "Sourced time:                                 [$g_sourced_datetime]"
  echo "Current time:                                 [$datetime]"
  echo "CentOS \"GNOME Desktop\" environment group ID:  [$CENTOS_GROUP_GNOME_DESKTOP_ENV_ID]"
  echo

  # Deployment
  echo
  echo -e "${TEXT_VIEW_NORMAL_GREEN}Deployment"
  echo "=========================================================================================================================="
  echo -e "${TEXT_VIEW_NORMAL}"
  show_menu_option "vnc_utils_show_menu                  " " - Show help"
  show_menu_option "vnc_provision                        " " - Provision VNC server/client"
  show_menu_option "vnc_server_provision                 " " - Provision VNC server"
  show_menu_option "vnc_client_provision                 " " - Provision VNC client"
}

#==================================================================================================================
# VNC server/client provision
#==================================================================================================================
vnc_provision()
{
  local command=""
  local group_id=$CENTOS_GROUP_GNOME_DESKTOP_ENV_ID

  # Install the "GNOME Desktop" environment group (gnome-desktop-environment)
  command="sudo yum groups install $group_id"
  echo "Executing: [$command]"
  $command

  # Update system after install
  command="sudo yum update"
  echo "Executing: [$command]"
  $command

  vnc_server_provision
  vnc_client_provision

  # Update system after install
  command="sudo yum update"
  echo "Executing: [$command]"
  $command  
}


#==================================================================================================================
# VNC server provision
#==================================================================================================================
vnc_server_provision()
{
  local command=""

  command="sudo yum install vnc-server"
  echo "Executing: [$command]"
  $command           
}

#==================================================================================================================
# VNC client provision
#==================================================================================================================
vnc_client_provision()
{
  local command=""

  command="sudo yum install vnc"
  echo "Executing: [$command]"
  $command                 
}

#==================================================================================================================
#
#=================================================================================================================
function vnc_read_configuration()
{
  # Source host and environment specific VNT configuration
  source "$g_vnc_config_file"
}

# Executing form bash console?
if [[ "$CONSOLE_MODE" == "true" ]]; then

  # Capture time when file was sourced 
  g_sourced_datetime="$(date +%c)"

  # Provision environment based on configuration file
  vnc_read_configuration

  if [[ "$DISPLAY_API_MENUS" == "true" ]]; then

    # Display helper "menu"
    vnc_utils_show_menu
  fi
fi

