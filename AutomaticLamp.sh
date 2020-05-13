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
projectroot=/home/$user/$projectname
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
		echo -e "\e[1;92m${user} exists! project will be installed in homedir\e[0m"
		if [ -d "$projectroot" ]; then
		  echo -e "\e[1;91m!!Projectroot already exists!!\e[0m"
		  echo "Choose new projectname or exsisting folder will be overwritten:"
		  read projectname
		fi

	else
		pass=$(perl -e 'print crypt($ARGV[0], "password")' $pass)
		useradd -m -p "$pass" "$user" -s /bin/bash -U
		[ $? -eq 0 ] && echo -e "\e[1;92mUser has been added!\e[0m" || echo -e "\e[1;91mFailed to add a user!\e[0m"
	fi
           }
make_user

sleep 2

#Gathering dependencies
function gathering_dependencies {
echo -e "\e[1;92mstarting gathering dependencies, a lost of dependencies can be found on the landing page of the script\e[0m"
apt install ca-certificates apt-transport-https -y
apt install apache2 -y
apt install php -y
apt install mariadb-server mariadb-client -y
apt install openssl -y
echo -e "\e[1;92mAll necessary dependencies installed\e[0m"
	}
gathering_dependencies



#setting setting up ssl
function ssl_cert {
echo -e "\e[1;92mEnabeling ssl mod\e[0m"
sudo a2enmod ssl
echo -e "\e[1;92mGenerating ssl certificate\e[0m"
mkdir /etc/ssl/certs/
openssl req -new -x509 -days 365 -nodes -out /etc/ssl/certs/$projectname.pem -keyout /etc/ssl/certs/$projectname.key -subj "/C=BE/ST=WVL/L=BRUGGE/O=$projectname/OU=Department $projectname/CN=ssl"

}
ssl_cert



#basic apache2 setup
function apache2_setup {
systemctl restart apache2
systemctl enable apache2
a2dissite 000-default.conf
sed -i 's|Listen 80|#Listen 80|g' /etc/apache2/ports.conf

echo "The projectroot is set to:"$projectroot
mkdir $projectroot

ln -s $projectroot /var/www/$projectname
chown $user:$user $projectroot
chmod -R 755 $projectroot

cp /etc/apache2/sites-available/default-ssl.conf /etc/apache2/sites-available/$projectname.conf
sed -i 's|/var/www/html|/var/www/'$projectname'|g' /etc/apache2/sites-available/$projectname.conf
sed -i '/ServerAdmin webmaster@localhost/a ServerName '${projectname}'' /etc/apache2/sites-available/$projectname.conf
sed -i 's|/etc/ssl/certs/ssl-cert-snakeoil.pem|/etc/ssl/certs/'$projectname'.pem|g' /etc/apache2/sites-available/$projectname.conf
sed -i 's|/etc/ssl/private/ssl-cert-snakeoil.key|/etc/ssl/certs/'$projectname'.key|g' /etc/apache2/sites-available/$projectname.conf

echo -e "\e[1;92mCloning basic php landingpage\e[0m"
git clone https://github.com/LanderReynvoet/ALAMPphpsite $projectroot
a2ensite $projectname
systemctl reload apache2
echo -e "\e[1;92mBasic Apache2 setup done\e[0m"
}
apache2_setup
function apache2_security {
	echo "ServerSignature Off" >> /etc/apache2/apache2.conf
	sed -i 's|Options Indexes FollowSymlinks|Options -Indexes|g' /etc/apache2/apache2.conf
	echo -e "\e[1;92mBasic Apache2 security done\e[0m"

}

apache2_security


function setup_mysql {
	systemctl start mysql
	mysql -e "CREATE DATABASE ${projectname} /*\!40100 DEFAULT CHARACTER SET utf8 */;"
	mysql -e "show databases;"
	mysql -e "CREATE USER ${user}@localhost IDENTIFIED BY '${pass}';"
	mysql -e "GRANT ALL PRIVILEGES ON *.* TO '${user}'@'localhost' IDENTIFIED BY '${pass}' ;"
	mysql -e "FLUSH PRIVILEGES;"
}

setup_mysql


