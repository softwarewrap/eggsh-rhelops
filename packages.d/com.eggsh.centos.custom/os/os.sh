#!/bin/bash
########################################################
#  © Copyright 2005-2017 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

@ os_install_basics()
{
   [[ $_WHOAMI = root ]] ||
   {
      :sudo_available || { echo "Sudo access is required, but is not available";  return 1; }
      sudo $_program os install basics
      return
   }

   sed -i '/\s*alias /d' /etc/profile.d/colorls.sh

   # Turn off unneeded services
   for Service in NetworkManager.service postfix.service firewalld.service ; do
      if [[ $( systemctl list-unit-files $Service |
                  grep $Service |
                  awk '{print $2}') = disabled ]] ; then 
         systemctl stop $Service
         systemctl disable $Service
      fi
   done

   # Disable SELinux
   sed -i 's/SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
   setenforce 0
   touch /.autorelabel

   #  UPDATE ROOT FileSYSTEM TO NOT WRITE ON ACCESS
   sed -i 's#^\([^ ]*\s* / \s*.*defaults\)#&,noatime#' /etc/fstab

   # FIX SYSTEMD MODES
   local Item File
   for Item in ebtables wpa_supplicant ; do
      File=/usr/lib/systemd/system/$Item.service
      if [[ -x $File ]]; then
         chmod a-x "$File"
      fi
   done
   for Item in auditd ; do
      File=/usr/lib/systemd/system/$Item.service
      chmod a+r "$File"
   done

   # ADD HARDWARE MONITORING
   yum -y install hdparm
}

@ os_disable_firewall()
{
   [[ $_WHOAMI = root ]] ||
   {
      :sudo_available || { echo "Sudo access is required, but is not available";  return 1; }
      sudo $_program os disable firewall
      return
   }

   for State in enable stop start stop disable mask ; do
      systemctl $State firewalld
   done

   yum -y install iptables-services
   for State in enable stop start ; do
      systemctl $State iptables.service
   done

   iptables -L
   iptables-save > /etc/sysconfig/iptables

   for State in stop disable mask ; do
      systemctl $State iptables.service
   done
}

@ os_install_hypervisor()
{
   [[ $_WHOAMI = root ]] ||
   {
      :sudo_available || { echo "Sudo access is required, but is not available";  return 1; }
      sudo $_program os install graphical
      return
   }

   yum -y install                      \
      @hardware-monitoring             \
      @virtualization                  \
      @virtualization-client           \
      @virtualization-host-environment \
      @virtualization-hypervisor       \
      @virtualization-tools            \
      GeoIP                            \
      libguestfs-bash-completion       \
      libmemcached                     \
      proftpd                          \
      qemu-kvm-tools                   \
      rpmdevtools                      \
      tcl                              \
      tk                               \
      tuned                            \
      xorriso

   # TBD: Optimization for the grub bootloader
   # Change the elevator to deadline
}

@ os_install_graphical()
{
   [[ $_WHOAMI = root ]] ||
   {
      :sudo_available || { echo "Sudo access is required, but is not available";  return 1; }
      sudo $_program os install graphical
      return
   }

   yum -y install                         \
      @base                               \
      @compat-libraries                   \
      @core                               \
      @desktop-debugging                  \
      @development                        \
      @dial-up                            \
      @dns-server                         \
      expect                              \
      @file-server                        \
      @fonts                              \
      ftp                                 \
      @ftp-server                         \
      @gnome-desktop                      \
      gnome-shell-extension-dash-to-dock  \
      @^graphical-server-environment      \
      @guest-agents                       \
      @guest-desktop-agents               \
      @ha                                 \
      @input-methods                      \
      @internet-browser                   \
      jq                                  \
      kexec-tools                         \
      @large-systems                      \
      @multimedia                         \
      @network-file-system-client         \
      @performance                        \
      @print-client                       \
      @remote-system-management           \
      @x11                                \
      xorg-x11-apps

   systemctl set-default graphical.target
   nohup systemctl start graphical.target &

   systemctl stop packagekit
   systemctl disable packagekit
   yum -y erase PackageKit

   (@)::os_install_graphical,GDM

   # Bug fix: gnome-terminal as root won't work
   # Fixes throw: Error constructing proxy for org.gnome.Terminal:/org/gnome/Terminal/Factory0
   # See: https://wiki.gnome.org/Apps/Terminal/FAQ#Exit_status_8
   localectl set-locale LANG=en_US.UTF-8

   # DISABLE USER LIST
   LOGIN_CONF_FILE="/etc/dconf/db/gdm.d/00-login-screen"
   cat > "$LOGIN_CONF_FILE" << xxxENDxxx
[org/gnome/login-screen]
disable-user-list=true

[org/gnome/desktop/session]
idle-delay=uint32 0

[org/gnome/desktop/screensaver]
lock-enabled=false
xxxENDxxx

   local (@)_FunctionPath
   :function_path -v (@)_FunctionPath
   (cd "$(@)_FunctionPath/_os/files"; tar cpf - .) | (cd /; tar xpf -)

   dconf update

   # Update font cache
   fc-cache
}

@ os_install_graphical,GDM()
{
   cat > /etc/gdm/custom.conf << xxxENDxxx
# GDM configuration storage

[daemon]

[security]
DisallowTCP=false
AllowRemoteRoot=true

[xdmcp]
Enable=true

[greeter]
IncludeAll=true

[chooser]

[debug]
xxxENDxxx
}
