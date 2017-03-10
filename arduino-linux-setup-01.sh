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

    echo "Restarting udev"
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

    user
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

    if [ -f /etc/lsb-release -a ! -f /etc/SuSE-release ]
    then
        #Only for Ubuntu
        sudo apt-get remove modemmanager
    elif [ -f /etc/SuSE-release ]
    then
        #Only for Suse
        sudo zypper remove modemmanager
    elif [ -f /etc/fedora-release ] || [ -f /etc/redhat-release ]
    then
        #Red Hat/Fedora/CentOS
        sudo yum remove modemmanager
    fi

}

SUDOASKED=n

if [ "$1" = "" ]
then
    echo ""
    echo "Run the script with command sudo ./ArduinoIDE_Installation_script.sh \$USER"
    echo ""
else

    sudocheck

    groupsfunc $1

    removemm

    acmrules $1 > /etc/udev/rules.d/90-extraacl.rules

    openocdrules > /etc/udev/rules.d/98-openocd.rules

    avrisprules > /etc/udev/rules.d/avrisp.rules

    refreshudev

    echo "*********** Please Reboot your system ************"
fi
