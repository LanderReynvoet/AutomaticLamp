#!/bin/bash

#require sudo

if (( $EUID != 0))
then echo -e "\e[1;91mRun script with root privileges\e[0m"
exit
fi

#display info

echo -e "\e[1;91mErrors will be displayed Red\e[0m"
echo -e "\e[1;92mInfo will be displayed in Cyan\e[0m"

#saving input variables
echo "To submit input, press [ENTER]"

echo "What is your project name:"
read projectname

echo -e "\e[1;92mProject name set to:"$projectname

echo "What is the username:"
echo -e "\e[1;91m!!This username will be used everywhere!!\e[0m"
read user

echo -e "\e[1;92mUsername set to:"$user"\e[0m"
echo "what is your password:"
read pass

echo -e "\e[1;92mpassword set\e[0m"

#before setup

echo -e "\e[1;92mstarting update\e[0m"
apt update
echo -e "\e[1;92mupdate finished\e[0m"

sleep 2

echo -e "\e[1;92mstarting upgrade\e[0m"
apt upgrade -y
echo -e "\e[1;92mupgrade finished\e[0m"

sleep 2
#making user


function make_user {
	grep -F "$user" /etc/passwd >/dev/null

	if [ $? -eq 0 ]; then
		echo "$user exists!"
		exit 1
	else
		pass=$(perl -e 'print crypt($ARGV[0], "password")' $pass)
		useradd -m -p "$pass" "$user" -s /bin/bash -U
		[ $? -eq 0 ] && echo -e "\e[1;92mUser has been added!\e[0m" || echo -e "\e[1;91mFailed to add a user!\e[0m"
	fi
           }
make_user

sleep 2

#Gathering dependencies

echo -e "\e[1;92mstarting certificates install\e[0m"
apt install ca-certificates apt-transport-https -y
echo -e "\e[1;92mcertificates finished\e[0m"

echo -e "\e[1;92mstarting apache2 install\e[0m"
apt install apache2 -y
echo -e "\e[1;92mapache finished\e[0m"

echo -e "\e[1;92mstarting php install\e[0m"
apt install php -y
echo -e "\e[1;92mphp install finished\e[0m"

echo -e "\e[1;92mstarting mariadb-server install\e[0m"
apt install mariadb-server mariadb-client -y
echo -e "\e[1;92mmariadb install finished\e[0m"
