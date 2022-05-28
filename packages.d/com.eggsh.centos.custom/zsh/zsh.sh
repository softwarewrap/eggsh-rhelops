#!/bin/bash

@ zsh_install()
{
   [[ $_WHOAMI = root ]] ||
   {
      :sudo_available || { echo "Sudo access is required, but is not available";  return 1; }
      sudo $_program zsh install
      return
   }

   yum -y install @development zsh

   INSTALL_TMP_DIR=$(mktemp -d)

   local (@)_FunctionPath
   :function_path -v (@)_FunctionPath
   (cd "$(@)_FunctionPath/_zsh/files"; tar cf - .) | (cd /; tar xf -)

   local File
   for File in pfrag path timestamp; do
      gcc -o /usr/local/bin/$File $(@)_FunctionPath/_zsh/$File.c
   done

   (@)::zsh_config
   (@)::zsh_config /etc/skel
}

@ zsh_config()
{
   local ConfigDir="${1:-$HOME}"
   cd "$ConfigDir"

   local (@)_FunctionPath
   :function_path -v (@)_FunctionPath

   cp $(@)_FunctionPath/_zsh/zshenv .zshenv
   cp $(@)_FunctionPath/_zsh/zshrc .zshrc
}
