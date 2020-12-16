#!/bin/bash

# -------- Lab OpenStack All in One by DevStack -------
# Requirements:
#   + VPS for this lab: 3cpu / 8G 
#   + Only one card public 
#   + OS: Ubuntu 18.04 x64 
#   + Remove netplan, use ifupdown (openvswitch)
# ------------------------------------------------------


# --- log dir ---
pwd_log="$PWD/install_devstack.log"


RepairEnv () {

# --- update lbs, dependencies ---
echo "START -------------- `date +%Y-%m-%d-%H:%M:%S`" > $pwd_log
printf "Update dependencies, development, ... -------------- \n" >> $pwd_log
apt update && apt dist-upgrade -y

# --- install ifupdown ---
printf "\nInstall ifupdown -------------- `date +%Y-%m-%d-%H:%M:%S` \n" >> $pwd_log
apt install ifupdown net-tools -y

# --- check ip server ---
printf "\nConfig card public with ifupdown -------------- \n" >> $pwd_log
ip=$(ip addr | grep 'state UP' -A2 | grep inet | head -n1 | awk '{print $2}' | cut -f1  -d'/')
netmask=$(ip addr | grep 'state UP' -A2 | grep inet | head -n1 | awk '{print $2}' | cut -f2  -d'/')
gateway=$(route -n | sort | head -n1| awk '{print $2}')
eth=$(ip addr | grep 'state UP' | awk '{print$2}' | cut -f1  -d':')

# --- config ip pub by ifupdown
cat << EOF > /etc/network/interfaces
auto lo
iface lo inet loopback

auto $eth
iface $eth inet static
address $ip
netmask $netmask
gateway $gateway
dns-nameservers 1.1.1.1 8.8.8.8
EOF

printf "\nInterfaces -------------- " >> $pwd_log
cat /etc/network/interfaces >> $pwd_log

printf "\nConfig card public with ifupdown -------------- " >> $pwd_log
ifdown --force $eth lo && ifup -a >> $pwd_log

# --- remove netplan ---
printf "\nRemove netplan -------------- \n" >> $pwd_log
systemctl stop networkd-dispatcher
systemctl disable networkd-dispatcher
systemctl mask networkd-dispatcher
apt purge nplan netplan.io -y

# --- install resolvconf ---
printf "\nInstall resolvconf -------------- \n" >> $pwd_log
apt install resolvconf -y
echo "nameserver 1.1.1.1" >> /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolvconf/resolv.conf.d/head
echo "nameserver 8.8.8.8" >> /etc/resolvconf/resolv.conf.d/head

printf "\nRestart resolvconf service -------------- \n" >> $pwd_log
service resolvconf restart  >> $pwd_log

# --- check network --- 
printf "\nCheck network -------------- \n" >> $pwd_log
ifconfig >> $pwd_log

# --- reboot server ---
printf "\n\n`date +%Y-%m-%d-%H:%M:%S` ----------------------"  >> $pwd_log
echo "Environment devstack is completed !!!" >> $pwd_log
printf "Reboot server after installing updates ... \n" >> $pwd_log

# --- reboot server ---
while true; do
    read -p "\n\n Do you wish to reboot this server?" yn
    case $yn in
        [Yy]* ) reboot; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done


}



InstallDevStack () {

# --- add user stack ---  
echo "START -------------- `date +%Y-%m-%d-%H:%M:%S`" > $pwd_log
printf "\nAdd user stack --------------  \n" >> $pwd_log
home_stack="/opt/stack"
useradd -s /bin/bash -d $home_stack -m stack

# --- use cmd sudo don't need enter password ---
printf "\nAdd user stack -------------- \n" >> $pwd_log
echo "stack ALL=(ALL) NOPASSWD: ALL"|tee /etc/sudoers.d/stack

# --- create local.conf ---
localconfig="
[[local|localrc]]

ADMIN_PASSWORD=s3cr3t@dm1n
DATABASE_PASSWORD=s3cr3t@dm1n
#MYSQL_PASSWORD=s3cr3t@dm1n
RABBIT_PASSWORD=s3cr3t@dm1n
SERVICE_PASSWORD=s3cr3t@dm1n
SERVICE_TOKEN=11111222223333344444

KEYSTONE_TOKEN_FORMAT=fernet

# Logging
LOGFILE=/opt/stack/logs/stack.sh.log
VERBOSE=True
LOG_COLOR=True
SCREEN_LOGDIR=/opt/stack/logs
ENABLE_DEBUG_LOG_LEVEL=True
ENABLE_VERBOSE_LOG_LEVEL=True

# Neutron ML2 with OpenVSwitch
Q_PLUGIN=ml2
Q_AGENT=openvswitch

enable_service n-novnc
enable_service n-cauth

disable_service tempest

[[post-config|/etc/neutron/dhcp_agent.ini]]
[DEFAULT]
enable_isolated_metadata = True
"

# --- switch user ---
printf "\nSwitch user - stack -------------- \n" >> $pwd_log

su - stack << EOF
    git clone https://git.openstack.org/openstack-dev/devstack --branch stable/victoria
    mkdir logs
    cd devstack
    echo "$localconfig" > ./local.conf
    chmod +x ./stack.sh
    ./stack.sh
    echo "source ~/devstack/openrc admin admin"  >> ~/.bashrc 
    rm -rf ./local.conf
EOF


# --- install completed ---
printf "\n\n--------------------------------- `date +%Y-%m-%d-%H:%M:%S` "  >> $pwd_log
echo "Install devstack completed !!!" >> $pwd_log

}


# ----- main ----
PS3='Please enter your choices: '
options=("Repair Environment" "Install DevStack" "Quit")

select opt in "${options[@]}"
do
    case $opt in
        "Repair Environment")
			#Done
            RepairEnv
            ;;
        "Install DevStack")
			#Done 
            InstallDevStack
            ;;
        "Quit")
            break
            ;;
			 *)
			echo "invalid option $REPLY"
			;;
    esac
done

