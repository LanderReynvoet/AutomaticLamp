#!/bin/bash

#require sudo

if (( $EUID != 0))
then echo "Run script with root privileges"
exit
fi

#saving input variables
echo "To submit input, press [ENTER]"

echo "What is your project name:"
read projectname

echo "Project name set to:"$projectname

echo -e "\e[1;91m!!Username will be used everywhere!!\e[0m"

echo "What is the username:"
read user

echo "Username set to:"$user

echo "what is your password:"
read pass

echo "password database set"

#before setup

echo "starting update"
apt update
echo "update finished"

sleep 2

echo "starting upgrade"
apt upgrade -y
echo "upgrade finished"

sleep 2
#making user


function make_user {
	egrep -F "$user" /etc/passwd >/dev/null

	if [ $? -eq 0 ]; then
		echo "$user exists!"
		exit 1
	else
		pass=$(perl -e 'print crypt($ARGV[0], "password")' $pass)
		useradd -m -p "$pass" "$user" -s /bin/bash -U
		[ $? -eq 0 ] && echo -e "\e[1;92mUser has been added!\e[0m" || echo "Failed to add a user!"
	fi
           }
make_user
#dependencies

echo "starting certificates install"
apt install ca-certificates apt-transport-https -y
echo "certificates finished"

echo "starting apache2 install"
apt install apache2 php-mysql libapache2-mod-php -y
echo "apache finished"

echo "starting php install"
apt install php-common php-mbstring php-xml php-zip php-curl -y
echo "php install finished"

echo "starting mariadb-server install"
apt install mariadb-server -y
echo "mariadb install finished"
