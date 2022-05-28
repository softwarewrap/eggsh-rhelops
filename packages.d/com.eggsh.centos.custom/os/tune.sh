#!/bin/bash

@ os_tune_kernel_all()
{
   [[ $_WHOAMI = root ]] || { echo "This command must be run as root"; return 1; }

   (@)::os_tune_kernel_limits
   (@)::os_tune_kernel_sysctl
}

@ os_tune_kernel_limits()
{
   [[ $_WHOAMI = root ]] || { echo "This command must be run as root"; return 1; }

   :archive /etc/security/limits.conf

   cat > /etc/security/limits.conf << xxxENDxxx
# /etc/security/limits.conf
#
#Each line describes a limit for a user in the form:
#
#<domain>        <type>  <item>  <value>
#
#Where:
#<domain> can be:
#        - an user name
#        - a group name, with @group syntax
#        - the wildcard *, for default entry
#        - the wildcard %, can be also used with %group syntax,
#                 for maxlogin limit
#
#<type> can have the two values:
#        - "soft" for enforcing the soft limits
#        - "hard" for enforcing hard limits
#
#<item> can be one of the following:
#        - core - limits the core file size (KB)
#        - data - max data size (KB)
#        - fsize - maximum filesize (KB)
#        - memlock - max locked-in-memory address space (KB)
#        - nofile - max number of open files
#        - rss - max resident set size (KB)
#        - stack - max stack size (KB)
#        - cpu - max CPU time (MIN)
#        - nproc - max number of processes
#        - as - address space limit (KB)
#        - maxlogins - max number of logins for this user
#        - maxsyslogins - max number of logins on the system
#        - priority - the priority to run user process with
#        - locks - max number of file locks the user can hold
#        - sigpending - max number of pending signals
#        - msgqueue - max memory used by POSIX message queues (bytes)
#        - nice - max nice priority allowed to raise to values: [-20, 19]
#        - rtprio - max realtime priority
#
#<domain>      <type>  <item>         <value>
#

# SOFT LIMITS
*                soft    nofile          1024
*                soft    nproc           2047
*                soft    stack           10240

# HARD LIMITS
*                hard    nofile          65536
*                hard    nproc           unlimited
*                hard    stack           unlimited

# End of file
xxxENDxxx

   :archive /etc/security/limits.d/20-nproc.conf
   cat > /etc/security/limits.d/20-nproc.conf << xxxENDxxx
# Default limit for number of user's processes to prevent
# accidental fork bombs.
# See rhbz #432903 for reasoning.

*          soft    nproc     unlimited
root       soft    nproc     unlimited
xxxENDxxx
}

@ os_tune_kernel_sysctl()
{
   [[ $_WHOAMI = root ]] || { echo "This command must be run as root"; return 1; }

   # Archive any existing file
   :archive /etc/sysctl.d/20-limits.conf

   cat >> /etc/sysctl.d/20-limits.conf << xxxENDxxx
# +---------------------------------------------------------+
# | SHARED MEMORY                                           |
# +---------------------------------------------------------+

# Maximum size (in bytes) for a shared memory segment
kernel.shmmax = 4294967295

# Maximum amount of shared memory (in pages) that
# can be used at one time on the system and should be at
# least ceil(SHMMAX/PAGE_SIZE)
kernel.shmall = 2097152

# Maximum number of shared memory segments system wide
kernel.shmmni = 4096

# +---------------------------------------------------------+
# | SEMAPHORES                                              |
# +---------------------------------------------------------+

# SEMMSL_value  SEMMNS_value  SEMOPM_value  SEMMNI_value
kernel.sem = 250 32000 100 128

# +---------------------------------------------------------+
# | NETWORKING                                              |
# ----------------------------------------------------------+

# Defines the local port range that is used by TCP and UDP
# traffic to choose the local port
net.ipv4.ip_local_port_range = 9000 65500

# Default setting in bytes of the socket "receive" buffer which
# may be set by using the SO_RCVBUF socket option
net.core.rmem_default = 262144

# Maximum setting in bytes of the socket "receive" buffer which
# may be set by using the SO_RCVBUF socket option
net.core.rmem_max = 4194304

# Default setting in bytes of the socket "send" buffer which
# may be set by using the SO_SNDBUF socket option
net.core.wmem_default = 262144

# Maximum setting in bytes of the socket "send" buffer which 
# may be set by using the SO_SNDBUF socket option
net.core.wmem_max = 1048576

net.core.netdev_max_backlog = 5000
net.core.somaxconn = 3000
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.tcp_keepalive_probes = 5

# Disable IPv6
net.ipv6.conf.all.disable_ipv6 = 1

# +---------------------------------------------------------+
# | FILE HANDLES                                            |
# ----------------------------------------------------------+

# Maximum number of file-handles that the Linux kernel will allocate
fs.file-max = 6815744

# Maximum number of allowable concurrent asynchronous I/O requests requests
fs.aio-max-nr = 1048576
xxxENDxxx

   sysctl -p /etc/sysctl.d/20-limits.conf
}
