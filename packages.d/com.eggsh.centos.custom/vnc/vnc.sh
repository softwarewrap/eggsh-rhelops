#!/bin/bash

@ vnc_install()
{
   [[ $_WHOAMI = root ]] ||
   {
      :sudo_available || { echo "Sudo access is required, but is not available";  return 1; }
      sudo $_program vnc install
      return
   }

   yum -y install tigervnc tigervnc-server
}

@ vnc_config()
{
   [[ $_WHOAMI = root ]] ||
   {
      :sudo_available || { echo "Sudo access is required, but is not available";  return 1; }
      sudo $_program vnc config "$@"
      return
   }

   local -r OPTIONS=$(getopt -o as:u: -l "all,specification:,user:" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local All=false
   local -a Users=()
   local -a UserModifications=()
   local SpecificationFile=

   while true ; do
      case "$1" in
      -a|--all)
         All=true
         shift;;

      -s|--specification)
         SpecificationFile="$2"
         shift 2;;

      -u|--user)
         UserModifications+=( "$2" )
         shift 2;;

      --) shift; break;;
      esac
   done

   if [[ ! -f $SpecificationFile ]] ; then
      echo "Usage: vnc config -s <JSON-Specification-File> [-a] {-u <user>}*"
      return 1
   fi

   :new :JSON (@)_SpecJSON
   (@)::vnc_config,Read "$SpecificationFile"
#  [[ $? -eq 0 ]] || return

   local Group Password User UserHome UserVNCDir UserVNCPort
   local -i RFBPort
   if $All ; then
      for User in $(jq -r '.users|keys_unsorted[]' <<<"${!(@)_SpecJSON}"); do
         if [[ ! " ${UserModifications[@]} " =~ " $User " ]]; then
            Users+=( "$User" )
         fi
      done
   else
      Users=( "${UserModifications[@]}" )
   fi

   for User in "${Users[@]}"; do
      echo "User: $User"
      $(@)_SpecJSON:select ".users.$User.group" -d "${(@)_Spec[.defaults.group]}"
      $(@)_SpecJSON:select ".users.$User.password" -d "${(@)_Spec[.defaults.password]}"
      $(@)_SpecJSON:select ".users.$User.shell" -d "${(@)_Spec[.defaults.shell]}"

      # TBD: Fix - default above should have worked
      [[ ${(@)_Spec[".users.$User.password"]} != null ]] || (@)_Spec[".users.$User.password"]="${(@)_Spec['.defaults.password']}" 
      [[ ${(@)_Spec[".users.$User.group"]} != null ]] || (@)_Spec[".users.$User.group"]="${(@)_Spec['.defaults.group']}" 
      [[ ${(@)_Spec[".users.$User.shell"]} != null ]] || (@)_Spec[".users.$User.shell"]="${(@)_Spec['.defaults.shell']}" 

      [[ -n ${(@)_Spec[".users.$User.password"]} ]] || { echo "No password provided for $User: skipping"; continue; }
      [[ -n ${(@)_Spec[".users.$User.group"]} ]] || (@)_Spec[".users.$User.group"]='users'
      [[ -n ${(@)_Spec[".users.$User.shell"]} ]] || (@)_Spec[".users.$User.shell"]='/bin/zsh'

      $(@)_SpecJSON:select ".users.$User.home"
      $(@)_SpecJSON:select ".users.$User.port" -d ''

      Group=$(getent group "${(@)_Spec[.users.$User.group]}" | cut -d: -f1)
      Password="${(@)_Spec[.users.$User.password]}"

      if [[ -z "$(getent passwd "$User" | cut -d: -f1)" ]] ; then
         if [[ -n $Group ]] ; then
            useradd -d "${(@)_Spec[.users.$User.home]}" -g "${(@)_Spec[.users.$User.group]}" \
               -m -s "${(@)_Spec[.users.$User.shell]}" $User
            echo "$User:${(@)_Spec[.users.$User.password]}" | chpasswd
         else
            echo "Cannot create user $User because group is unknown"
            continue
         fi
      fi

      sed -i "/^$User/d" /etc/sudoers
      echo "$User    ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers

      UserHome=$(getent passwd "$User" | cut -d: -f6)
      UserVNCDir="$UserHome/.vnc"
      UserVNCPort="${(@)_Spec[.users.$User.port]}"

      mkdir -p "$UserVNCDir"
      echo "$Password" | vncpasswd -f > "$UserVNCDir/passwd"
      chmod 600 "$UserVNCDir/passwd"
      chown -R --reference="$UserHome" "$UserVNCDir"

      if [[ -f /etc/systemd/system/vncserver@:${(@)_Spec[.users.$User.port]}.service ]] ; then
         systemctl stop vncserver@:${(@)_Spec[.users.$User.port]}.service
      fi

      # ExecStart=/usr/sbin/runuser -l <USER> -c "/usr/bin/vncserver %i"
      if [[ -n $UserVNCPort ]]; then
         if systemctl list-unit-files | grep -q vncserver@:$UserVNCPort.service ; then
            # Remove existing service
            systemctl stop vncserver@:$UserVNCPort.service
            systemctl disable vncserver@:$UserVNCPort.service
            rm -f /etc/systemd/system/vncserver@:$UserVNCPort.service
            systemctl daemon-reload
            systemctl reset-failed
         fi

         sed -e "s|<USER>|$User|g" \
             -e "s|^\(ExecStart=.*%i\)|\1 -geometry 1920x1200|" \
            < /lib/systemd/system/vncserver@.service \
            > /etc/systemd/system/vncserver@:$UserVNCPort.service

         systemctl daemon-reload
         systemctl enable vncserver@:$UserVNCPort.service
         systemctl start vncserver@:$UserVNCPort.service

         echo "Started VNC for $User:$Group @ $UserHome on port $UserVNCPort"
      fi
   done

   (@)::vnc_config,DumpSpec
}

@ vnc_config,Read()
{
   local SpecificationFile="$1"
   local Spec="$(@)_SpecJSON"
   shift

   # Set options
   $Spec:option +envsubst
   + option +raw

   # Set properties
   + property error.suffix   "File:     ^$SpecificationFile"
   + property save.type      associative   # associative, positional, string, none
   + property save.var       (@)_Spec

   :try {
      + readfile "$SpecificationFile"
      + select .defaults.group -d ''
      + select .defaults.password -d ''
      + select .defaults.shell -d ''
   } :catch {
      if [[ $(+ property error.stack) != true ]] ; then
            Text="
$_RED$_UNDERLINE[ERROR] vnc_config EXCEPTION $_tryStatus CAUGHT ON LINE $_tryErrorLine$_NORMAL

$(+ property error.text)
$(::stacktrace 0)"

         + property error.text "$Text"
      fi

      $Spec:property --color error.text
      return $_tryStatus
   }

   return 0
}

@ vnc_config,DumpSpec()
{
   echo "================================================== SPECIFICATION:"
   local Spec=$(@)_SpecJSON
   echo "SPEC":
   jq -cr . <<<"${!Spec}"

   echo -e "\nVARIABLES:"
   for Key in $(printf "%s\n" "${!(@)_Spec[@]}" | LC_ALL=C sort -u | tr '\n' ' '); do
      echo "$Key: ${(@)_Spec[$Key]}"
   done
   echo
}
