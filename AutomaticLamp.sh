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

echo "What is the username for the database:"
read db_user

echo "Username for the database set to:"$db_user

echo "what is your password for the database:"
read db_pass

echo "password for the database set"

#before setup

echo "starting update"
apt update
echo "update finished"

sleep 2

echo "starting upgrade"
apt upgrade -y
echo "upgrade finished"

sleep 2

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

