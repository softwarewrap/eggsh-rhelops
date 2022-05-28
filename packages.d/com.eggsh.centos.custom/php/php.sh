#!/bin/bash

@ install_php()
{
   yum install -y http://rpms.remirepo.net/enterprise/remi-release-7.rpm
   yum install yum-utils
   yum-config-manager --enable remi-php72
   yum install php php-mcrypt php-cli php-gd php-curl php-mysql php-ldap php-zip php-fileinfo
}
