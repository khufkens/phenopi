#!/bin/bash

# raspberry pi
# real time clock installation script
# run this script after the normal install routine
# as it reboots on success
# 
# requirements: an internet connection

# set default password
password="raspberry"

# first test the connection to the google name server
connection=`ping -q -W 1 -c 1 8.8.8.8 > /dev/null && echo ok || echo error`

# If the connection is down, bail
if [[ $connection != "ok" ]];then
	echo "No internet connection, can't determine time zone!"
	echo "Please connect to the net first."
	exit 1
else

	# determine the pi's external ip address
	current_ip=$(curl -s ifconfig.me)

	# get geolocation data 
	geolocation_data=$(curl -s http://freegeoip.net/xml/${current_ip})

	# look up the location based upon the external ip
	latitude=$(echo ${geolocation_data} | \
		grep -o -P -i "(?<=<Latitude>).*(?=</Latitude>)")
	
	longitude=$(echo ${geolocation_data} | \
		grep -o -P -i "(?<=<Longitude>).*(?=</Longitude>)")

	# check if we have an internet connection
	timezone_data=$(curl -s http://www.earthtools.org/timezone/$latitude/$longitude)

	# grab the timezone offset from UTC (non daylight savings correction)
	time_offset=$(echo ${timezone_data} | \
		grep -o -P -i "(?<=<offset>).*(?=</offset>)")

	# grab the sign of the time_offset
	sign=`echo $time_offset | cut -c'1'`

	# swap the sign of the offset to 
	# convert the sign from the UTC time zone TZ variable (for plotting in overlay)
	if [ "$sign" = "+" ]; then
		tzone=`echo "$time_offset" | sed 's/-/+/g'`
	else
		tzone=`echo "$time_offset" | sed 's/+/-/g'`
	fi

	# set the time zone, time will be set by the NTP server
	# if online
	`echo sudo ln -sf /usr/share/zoneinfo/Etc/GMT$tzone /etc/localtime`

	# install all necessary packages
	echo $password | sudo -Sk apt-get -y install i2c-tools
	echo $password | sudo -Sk apt-get -y install libi2c-dev
	echo $password | sudo -Sk apt-get -y install python-smbus


	# check if we have a real time clock (RTC)
	# i2c device (only check the bus 1 - newer pi s) 	
	rtc_present=$(echo $password | sudo i2cdetect -y 1 | grep UU | wc -l)

	# So check if the boot config is up to date,
	# if so continue to check if there is a RTC
	# if not update boot parameters and reboot

	# check boot config parameters
	i2c=`grep "dtparam=i2c_arm=on" /boot/config.txt | wc -l`
	rtc=`grep "dtoverlay=ds1307-rtc" /boot/config.txt | wc -l`

	if [[ i2c == 0 && rtc == 0 ]]; then
		# adjust config.txt
		sudo cat "dtparam=i2c1=on" >> /boot/config.txt
		sudo cat "dtparam=i2c_arm=on" >> /boot/config.txt
	fi

	i2c=`grep "i2c" /etc/modules | wc -l`
	rtc=`grep "rtc" /etc/modules | wc -l`

	if [[ i2c == 0 && rtc == 0 ]]; then
		# add modules to /etc/modules
		sudo cat "i2c-bcm2708" >> /etc/modules
		sudo cat "i2c-dev" >> /etc/modules
		sudo cat "rtc-ds1307" >> /etc/modules
	fi

	# If there is no RTC clock, set time zone
	# offset and exit
	if [[ ${rtc_present} == 0 ]];then
		exit 1
	fi

fi

exit 0









