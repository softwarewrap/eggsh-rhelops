#!/bin/bash
########################################################
#  © Copyright 2005-2017 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

@ cf_install_client()
{
   [[ $_WHOAMI = root ]] ||
   {
      :sudo_available || { echo "Sudo access is required, but is not available";  return 1; }
      sudo $_program cf install client "$@"
      return
   }

   # Install the BOSH CLI
   yum -y install       \
      gcc               \
      gcc-c++           \
      libxml2-devel     \
      libxslt-devel     \
      mariadb           \
      openssl-devel     \
      patch             \
      postgresql-devel  \
      postgresql-libs   \
      rake              \
      ruby              \
      ruby-devel        \
      rubygem-nokogiri  \
      sqlite-devel

   gem install yajl-ruby
   gem install bosh_cli --no-ri --no-rdoc

   # Install the Cloud Foundry CLI
   rm -f /etc/yum.repos.d/cloudfoundry-cli.repo
   wget -O /etc/yum.repos.d/cloudfoundry-cli.repo https://packages.cloudfoundry.org/fedora/cloudfoundry-cli.repo
   yum install -y cf-cli
}

@ openstack_install_client()
{
   [[ $_WHOAMI = root ]] ||
   {
      :sudo_available || { echo "Sudo access is required, but is not available";  return 1; }
      sudo $_program openstack install client "$@"
      return
   }

   yum install -y python-devel python-pip
   pip install --upgrade pip
   pip install python-openstackclient
}
