#!/bin/bash
########################################################
#  © Copyright 2005-2017 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

@ vim_install()
{
   [[ $_WHOAMI = root ]] ||
   {
      :sudo_available || { echo "Sudo access is required, but is not available";  return 1; }
      sudo $_program vim install
      return
   }

   yum -y install    \
      @development   \
      ncurses        \
      ncurses-devel  \
      perl           \
      perl-devel     \
      python         \
      python-devel   \
      ruby           \
      ruby-devel

   INSTALL_TMP_DIR=$(mktemp -d)

   cd "$INSTALL_TMP_DIR"
   git clone https://github.com/vim/vim.git

   cd "vim"
   ./configure --with-features=huge --enable-rubyinterp --enable-pythoninterp --enable-multibyte
   make && make install

   cd /usr/local/bin
   ln -sf vim vi

   local (@)_FunctionPath
   :function_path -v (@)_FunctionPath
   (cd "$(@)_FunctionPath/_vim/files"; tar cpf - .) | (cd /; tar xpf -)
   chown -R root:root /usr/local/share/vim

   [[ -d $INSTALL_TMP_DIR ]] && rm -rf "$INSTALL_TMP_DIR"

   mkdir -p /orig/usr/bin

   local Target
   for Target in vi vim; do
      if [[ ! -f /orig/usr/bin/$Target ]]; then
         mv /usr/bin/$Target /orig/usr/bin/.
         ln -s /usr/local/bin/$Target /usr/bin/$Target
      fi
   done

   (@)::vim_config
   (@)::vim_config /etc/skel
}

@ vim_config()
{
   local ConfigDir="${1:-$HOME}"
   cd "$ConfigDir"

   mkdir -p .vim/swp .vim/save

   local (@)_FunctionPath
   :function_path -v (@)_FunctionPath

   rm -f .vimrc .gvimrc
   cp $(@)_FunctionPath/_vim/gvimrc .gvimrc
   ln -s .gvimrc .vimrc
}
