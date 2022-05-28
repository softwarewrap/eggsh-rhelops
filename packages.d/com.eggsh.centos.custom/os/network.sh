#!/bin/bash
########################################################
#  © Copyright 2005-2017 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

@ network_update_dhcp__INFO() { echo "Update dhclient.conf and fix hostname and DNS"; }
@ network_update_dhcp()
{
   echo -n "Enter Host FQDN > "
   read install_HOST_FQDN
   echo -n "Enter domain search paths > "
   read install_TLD_SEARCH
   echo -n "Enter DNS search paths > "
   read install_DNS_SEARCH

   yum -y erase cloud-init

   # Perform temporary fix effective until the next reboot on /etc/resolv.conf
   # It is not necessary to save this file because it is subject to regeneration
   local HOST_NAME=$(echo "$install_HOST_FQDN" | sed 's/\..*//')
   local HOST_TLD=$(echo "$install_HOST_FQDN" | sed 's/^[^.]*\.//')

   if [[ $install_HOST_FQDN != $(cat /etc/hostname) ]] ; then
      hostnamectl set-hostname $install_HOST_FQDN
   fi

   sed -i -e '/^\s*search/d' -e '/^\s*nameserver/d' /etc/resolv.conf
   cat >> /etc/resolv.conf << xxxENDxxx
search $install_TLD_SEARCH
xxxENDxxx

   local NAMESERVER
   for NAMESERVER in $install_DNS_SEARCH ; do
      echo "nameserver $NAMESERVER"
   done >> /etc/resolv.conf

   # Configure dhclient.conf that generates files after each reboot
      local NIC=$(install_network__GetNIC)
      if [[ -n $NIC ]] ; then
         {
         cat << xxxENDxxx
timeout 300;
retry 60;

interface "$NIC"
{
   supersede host-name "$HOST_NAME";
   supersede domain-name "$HOST_TLD";
xxxENDxxx

         local TLD_LIST=$(echo "$install_TLD_SEARCH" | sed -e 's|\([^ ]*\)|"\1"|g' -e 's|  *|, |g')
         echo "   supersede domain-search $TLD_LIST;"


         local DNS_LIST=$(echo "$install_DNS_SEARCH" | sed -e 's|  *|, |g')
         cat << xxxENDxxx
   supersede domain-name-servers $DNS_LIST;
}
xxxENDxxx
         } > /etc/dhcp/dhclient.conf
      else
         echo 1 "[ERROR] No network interface was found."
      fi

   echo "Done."
}

install_network__GetNIC()
{
   local TMP1=/tmp/ifdata1$$
   local TMP2=/tmp/ifdata2$$

   local WAIT
   [[ $# -gt 0 ]] && WAIT="$1" || WAIT=5

   install_network__Ifdata > $TMP1 
   sleep $WAIT
   install_network__Ifdata > $TMP2 

   local NIC=$(comm -23 "$TMP1" "$TMP2" | awk '{print $1}' | sed 's/:$//')
   /bin/rm -f "$TMP1" "$TMP2"

   if [[ -z $NIC ]] ; then
      [[ $WAIT -le 40 ]] && NIC=$(install_network__GetNIC $(($WAIT * 2)))
   fi

   echo $NIC
}

install_network__Ifdata()
{
   ifconfig | sed -e 's/^[^ ]/###&/'| sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/ /g' | sed 's/###/\n/g' | sort | grep -v "^\(lo\|qb\|qv\|tap\|br\)"
}
