# System authorization information
auth --enableshadow --passalgo=sha512
# Use network installation
url --url="https://dl.fedoraproject.org/pub/fedora/linux/releases/22/Server/x86_64/os/"
# Use text mode install
text
# Run the Setup Agent on first boot
firstboot --enable
ignoredisk --only-use=vda
# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'
# System language
lang en_US.UTF-8
# Network information
network  --bootproto=dhcp --device=eth0 --ipv6=auto --activate
# Root password
rootpw --iscrypted $6$devconf16$bZCWfUNjasD/0ZfvnPhifOV/nzyaThWun7Skjs4oaab9CkVk2FzEBQKf6olWkZYWrC0d7EsVXbrSMqEtOGW100

# Do not configure the X Window System
skipx
# System timezone
timezone US/Eastern --isUtc 
# System bootloader configuration
bootloader --location=mbr --boot-drive=vda
autopart --type=plain
# Partition clearing information
clearpart --all --initlabel --drives=vda

%packages
kernel-devel
%end

%post
dnf groupinstall -y "Development Tools" "RPM Development Tools" "Text-based Internet" "System Tools"
dnf install -y kernel-debuginfo kernel-tools
dnf install -y net-tools
dnf install -y dnf-plugins-core
dnf copr enable -y ndokos/configtools
dnf copr enable -y ndokos/pbench
dnf install -q -y pbench-agent
dnf install -q -y pbench-fio fio
FIO_VERSION=$(/usr/bin/fio --version | sed s/fio-//g)
sed -i s/ver=2.2.5/ver=$FIO_VERSION/g /opt/pbench-agent/bench-scripts/pbench_fio
source /etc/profile.d/pbench-agent.sh
register-tool-set
# dnf -y update
# sed -i -e s/^HWADDR.*// /etc/sysconfig/network-scripts/ifcfg-eth0
# /bin/rm -f /etc/hostname
%end

shutdown
