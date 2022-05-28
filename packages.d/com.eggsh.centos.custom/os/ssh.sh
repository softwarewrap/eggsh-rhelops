#!/bin/bash

@ ssh_config__INFO() { echo 'Configure /etc/ssh/sshd_config'; }
@ ssh_config__HELP()
{
   :man "
OPTIONS:
   -f|--force           ^Turn archiving force mode on
   -p|--port <port>     ^Set port to <port> [default: 22]

DESCRIPTION:
   Configure the sshd_config file. This consists of:

      - Removing comments, blank lines, and reducing tabs to spaces
      - Changing the following entrys:

            AddressFamily inet^
            PasswordAuthentication no^
            Port <port>^

   <red>Important:</red> It is critical that access to the server via ssh certificate
   be possible before applying this change; otherwise, after the change to
   <b>PasswordAuthentication</b>, it will not be possible to login.

   This command automatically saves the original to the archive directory.
   Running this command a second time will have no effect unless the <b>-f</b> option
   is used. This command must be run as root.

$(:align <<<"
FILES:
   /etc/ssh/sshd_config ^|: The updated configuration file
   /orig/etc/ssh/sshd_config ^|: The archived (original) configuration file
|
SEE ALSO:
   $_programName :archive ^|: $(:archive__INFO)")
"
}

@ ssh_config()
{
   local Options
   Options=$(getopt -o p: -l "port:" -n "${FUNCNAME[0]}" -- "$@") || return 1
   eval set -- "$Options"

   local Port='22'
   while true ; do
      case "$1" in
      -p|--port)  Port="$2"; shift 2;;
      --)         shift; break;;
      esac
   done

   [[ $_WHOAMI = root ]] || { echo "This command must be run as root"; return 1; }

   # Ensure the entry is a valid port
   [[ $Port =~ ^[1-9][0-9]*$ ]] || { echo "Not a port: $Port"; return 1; }
   (( $Port > 0 && $Port < 655536 )) || { echo "Port is not in range: $Port"; return 1; }

   if :archive /etc/ssh/sshd_config; then
      sed -i \
            -e '/^#/d' \
            -e '/^$/d' \
            -e 's/\s*#.*//' \
            -e '/^AddressFamily /d' \
            -e '/^PasswordAuthentication /d' \
            -e '/^Port /d' \
            -e 's/\t\+/ /g' \
            -e 's/\s\+/ /g' \
         /etc/ssh/sshd_config

      cat >> /etc/ssh/sshd_config << xxxENDxxx
AddressFamily inet
PasswordAuthentication no
Port $Port
xxxENDxxx

      sed 's/\s/\t/' /etc/ssh/sshd_config | expand -40 | sort -f -o /etc/ssh/sshd_config

      systemctl restart sshd.service
   fi
}
