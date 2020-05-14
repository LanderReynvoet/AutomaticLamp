#!/bin/bash

#Will check if you run the script with root privileges
function check_if_sudo {
if (( $EUID != 0))
then echo -e "\e[1;91mRun script with root privileges\e[0m"
exit
fi
}
#This function will set up all variables used in the script (username, password, projectname)
function setting_up_variables {

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
}
#Here the script updates the list of available packages and their versions and also installs newer versions of the packages
function uptodate {
echo -e "\e[1;92mstarting update\e[0m"
apt update
echo -e "\e[1;92mupdate finished\e[0m"

sleep 2

echo -e "\e[1;92mstarting upgrade\e[0m"
apt upgrade -y
echo -e "\e[1;92mupgrade finished\e[0m"

sleep 2
}
#Here you can choose to make a new user or use an exsisting one to create project on
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
		password=$(perl -e 'print crypt($ARGV[0], "password")' $pass)
		useradd -m -p "$password" "$user" -s /bin/bash -U
		[ $? -eq 0 ] && echo -e "\e[1;92mUser has been added!\e[0m" || echo -e "\e[1;91mFailed to add a user!\e[0m"
	fi
           }
#All dependencies needed to set up the LAMP stack will be installed here
function gathering_dependencies {
echo -e "\e[1;92mstarting gathering dependencies, a lost of dependencies can be found on the landing page of the script\e[0m"
apt install ca-certificates apt-transport-https -y
apt install apache2 -y
apt install php -y
apt install mariadb-server mariadb-client -y
apt install openssl -y
echo -e "\e[1;92mAll necessary dependencies installed\e[0m"
	}
#This will setup the SSL certificate so HTTPS can be used
function ssl_cert {
echo -e "\e[1;92mEnabeling ssl mod\e[0m"
sudo a2enmod ssl
echo -e "\e[1;92mGenerating ssl certificate\e[0m"
mkdir /etc/ssl/certs/
openssl req -new -x509 -days 365 -nodes -out /etc/ssl/certs/$projectname.pem -keyout /etc/ssl/certs/$projectname.key -subj "/C=BE/ST=WVL/L=BRUGGE/O=$projectname/OU=Department $projectname/CN=ssl"

}
#This will set up an virtual host that uses HTTPS, also copies the basic php site for the project
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
#Stops Apache2 showing information about your server version, operating system, modules installed, etc
function apache2_security {
	echo "ServerSignature Off" >> /etc/apache2/apache2.conf
	sed -i 's|Options Indexes FollowSymlinks|Options -Indexes|g' /etc/apache2/apache2.conf
	echo -e "\e[1;92mBasic Apache2 security done\e[0m"
}
#Here we setup the database for the project
function setup_mysql {
	systemctl start mysql
	mysql -e "CREATE DATABASE ${projectname} /*\!40100 DEFAULT CHARACTER SET utf8 */;"
	mysql -e "show databases;"
	mysql -e "CREATE USER '${user}'@'localhost' IDENTIFIED BY '${pass}';"
	mysql -e "GRANT ALL PRIVILEGES ON *.* TO '${user}'@'localhost' IDENTIFIED BY '${pass}' ;"
	mysql -e "FLUSH PRIVILEGES;"
}
#To work with the datbase not by commandline we also install phpmyadmin
function phpmyadmin {
	#echo "phpmyadmin phpmyadmin/internal/skip-preseed boolean true" | debconf-set-selections
	#echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect" | debconf-set-selections
	#echo "phpmyadmin phpmyadmin/dbconfig-install boolean false" | debconf-set-selections
	apt install debconf-utils -y 
	debconf-set-selections <<<'phpmyadmin phpmyadmin/dbconfig-install boolean true'
	debconf-set-selections <<<'phpmyadmin phpmyadmin/app-password-confirm password ${pass}'
	debconf-set-selections <<<'phpmyadmin phpmyadmin/mysql/admin-pass password ${pass}'
	debconf-set-selections <<<'phpmyadmin phpmyadmin/mysql/app-pass password ${pass}'
	debconf-set-selections <<<'phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2'
	apt install phpmyadmin php-mbstring php-gettext -y 
	phpenmod mbstring
	systemctl restart apache2
	mysql -e "SELECT user,authentication_string,plugin,host FROM mysql.user;"
	echo -e "\e[1;92mPhpmyadmin installation done\e[0m"
}

#display info
echo -e "\e[1;91mErrors will be displayed Red\e[0m"
echo -e "\e[1;92mInfo will be displayed in Cyan\e[0m"
check_if_sudo
setting_up_variables
make_user
gathering_dependencies
ssl_cert
apache2_setup
apache2_security
setup_mysql
phpmyadmin


