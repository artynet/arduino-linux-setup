# arduino-linux-setup.sh : A simple Arduino setup script for Linux systems
# Copyright (C) 2015 Arduino Srl
#
# Author : Arturo Rinaldi
# E-mail : arturo@arduino.org
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Release v3 changelog :
#
#	+ The most common linux distros are now fully supported
#
#	+ now the script checks for SUDO permissions
#

#! /bin/bash

# if [[ $EUID != 0 ]] ; then
#   echo This must be run as root!
#   exit 1
# fi

sudocheck () {
	#
	# Check SUDO privileges
	#
	if [ $SUDOASKED = n ]
	then
        echo ""
		echo SUDO privileges are required
		echo -n Do you have SUDO privileges'?'
        echo ""
		read ans
		case $ans in
			y|Y|YES|yes|Yes)
				echo Continuing with script
				SUDOASKED=y
				sudo grep timestamp_timeout /etc/sudoers >tmp$$
				timeout=`cat tmp$$|awk '/./ {print $4}'`
				rm -f tmp$$
				if [ "@@" = "@$timeout@" ]
				then
					sudo cp /etc/sudoers tmp$$
					sudo chown $USER tmp$$
					sudo chmod 644 tmp$$
					echo "Defaults  timestamp_timeout = 90" >>tmp$$
					sudo cp tmp$$ /etc/sudoers
					sudo chown root /etc/sudoers
					sudo chmod 440 /etc/sudoers
				elif [ "$timeout" -lt 90 ]
				then
					echo You need to have a timestamp_timout in /etc/sudoers of 90 or more
					echo Please ensure that your timestamp_timeout is 90 or more
					exit
				fi
				;;
			*)
				echo Exiting.  Please ensure that you have SUDO privileges on this system!
				exit 0
				;;
		esac
	fi
}

refreshudev () {

	echo ""
    echo "Restarting udev"
	echo ""

    sudo service udev restart
    sudo udevadm control --reload-rules
    sudo udevadm trigger

}

groupsfunc () {

    echo ""
    echo "******* Add User to dialout,tty, uucp, plugdev groups *******"
    echo ""

    sudo usermod -a -G tty $1
    sudo usermod -a -G dialout $1
    sudo usermod -a -G uucp $1
    sudo groupadd plugdev
    sudo usermod -a -G plugdev $1

}

acmrules () {

    echo ""
    echo "Setting serial port rules"
    echo ""

cat <<EOF
"KERNEL="ttyUSB[0-9]*", TAG+="udev-acl", TAG+="uaccess", OWNER="$1"
"KERNEL="ttyACM[0-9]*", TAG+="udev-acl", TAG+="uaccess", OWNER="$1"
EOF

}

openocdrules () {

    echo ""
	echo "Adding Arduino M0/M0 Pro Rules"
    echo ""

cat <<EOF
ACTION!="add|change", GOTO="openocd_rules_end"
SUBSYSTEM!="usb|tty|hidraw", GOTO="openocd_rules_end"

#Please keep this list sorted by VID:PID

#CMSIS-DAP compatible adapters
ATTRS{product}=="*CMSIS-DAP*", MODE="664", GROUP="plugdev"

LABEL="openocd_rules_end"
EOF

}

avrisprules () {

cat <<EOF
SUBSYSTEM!="usb_device", ACTION!="add", GOTO="avrisp_end"
# Atmel Corp. JTAG ICE mkII
ATTR{idVendor}=="03eb", ATTRS{idProduct}=="2103", MODE="660", GROUP="dialout"
# Atmel Corp. AVRISP mkII
ATTR{idVendor}=="03eb", ATTRS{idProduct}=="2104", MODE="660", GROUP="dialout"
# Atmel Corp. Dragon
ATTR{idVendor}=="03eb", ATTRS{idProduct}=="2107", MODE="660", GROUP="dialout"

LABEL="avrisp_end"
EOF

}

removemm () {

    echo ""
    echo "******* Removing modem manager *******"
    echo ""

    if [ -f /etc/lsb-release -a ! -f /etc/SuSE-release ] || [ -f /etc/debian_version ] || [ -f /etc/linuxmint/info ]
    then
        #Only for Ubuntu/Mint/Debian
        sudo apt-get remove modemmanager
    elif [ -f /etc/SuSE-release ]
    then
        #Only for Suse
        sudo zypper remove modemmanager
    elif [ -f /etc/fedora-release ] || [ -f /etc/redhat-release ]
    then
        #Only for Red Hat/Fedora/CentOS
        sudo yum remove modemmanager
	else
		echo ""
		echo "Your system is not supported, please take care of it with your package manager"
		echo ""
    fi

}


if [ "$1" = "" ]
then
    echo ""
    echo "Run the script with command sudo ./arduino-linux-setup.sh \$USER"
    echo ""
else

	[ `whoami` != $1 ] &&  echo "The user name is not the right one, please double-check !" && exit 1

	SUDOASKED=n

    sudocheck

    groupsfunc $1

    removemm

    acmrules $1 > /etc/udev/rules.d/90-extraacl.rules

    openocdrules > /etc/udev/rules.d/98-openocd.rules

    avrisprules > /etc/udev/rules.d/avrisp.rules

    refreshudev

	echo ""
    echo "*********** Please Reboot your system ************"
	echo ""
fi
