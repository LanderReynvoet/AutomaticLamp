#!/bin/bash

#display info
function info {
echo -e "\e[1;91mErrors will be displayed Red\e[0m"
echo -e "\e[1;92mInfo will be displayed in Cyan\e[0m"
}
#Will check if you run the script with root privileges
function check_if_sudo {
if (( $EUID != 0))
then echo -e "\e[1;91mRun script with root privileges\e[0m"
exit
fi
}
#This function will set up all variables used in the script (username, password, projectname)
function setting_up_variables {
choice = null
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
apt install apache2 -y # The webserver
apt install php -y # The programming language
apt install mariadb-server mariadb-client -y #The database
apt install openssl -y
apt install unzip -y 
apt install php-imagick php-phpseclib php-php-gettext php-common php-mysql php-gd php-imap php-json php-curl php-zip php-xml php-mbstring php-bz2 php-intl php-gmp -y #required php modules for phpmyadmin
apt install php-dom php-mbstring -y #required for laravel 
apt install php-zip -y
apt install php php-cli -y
apt install sudo

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

if [ $choice = "laravel" ]; then
	ln -s $projectroot/public /var/www/$projectname
fi
cp /etc/apache2/sites-available/default-ssl.conf /etc/apache2/sites-available/$projectname.conf
sed -i 's|/var/www/html|/var/www/'$projectname'|g' /etc/apache2/sites-available/$projectname.conf
sed -i '/ServerAdmin webmaster@localhost/a ServerName '${projectname}'' /etc/apache2/sites-available/$projectname.conf
sed -i '/ServerName '${projectname}'/a ServerAlias '${projectname}'.local' /etc/apache2/sites-available/$projectname.conf 
sed -i 's|/etc/ssl/certs/ssl-cert-snakeoil.pem|/etc/ssl/certs/'$projectname'.pem|g' /etc/apache2/sites-available/$projectname.conf
sed -i 's|/etc/ssl/private/ssl-cert-snakeoil.key|/etc/ssl/certs/'$projectname'.key|g' /etc/apache2/sites-available/$projectname.conf


echo -e "\e[1;92mBasic Apache2 setup done\e[0m"
}
#Clonses php language to projectroot
function php_option {
echo -e "\e[1;92mCloning basic php landingpage\e[0m"
git clone https://github.com/LanderReynvoet/ALAMPphpsite $projectroot
a2ensite $projectname
systemctl reload apache2
systemctl start apache2
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
	wget https://files.phpmyadmin.net/phpMyAdmin/4.9.0.1/phpMyAdmin-4.9.0.1-all-languages.zip -P /tmp
	unzip /tmp/phpMyAdmin-4.9.0.1-all-languages.zip -d /tmp/
	mv /tmp/phpMyAdmin-4.9.0.1-all-languages/ /usr/share/phpmyadmin/
	chown -R www-data:www-data /usr/share/phpmyadmin
	mysql -e "CREATE DATABASE phpmyadmin DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
	mysql -e "GRANT ALL ON phpmyadmin.* TO 'phpmyadmin'@'localhost' IDENTIFIED BY 'phpmyadmin';"
	mysql -e "FLUSH PRIVILEGES;"
	systemctl restart apache2
	cp phpmyadmin.conf /etc/apache2/conf-available/phpmyadmin.conf
	a2enconf phpmyadmin
	mkdir -p /var/lib/phpmyadmin/tmp
	chown www-data:www-data /var/lib/phpmyadmin/tmp
	systemctl reload apache2
	echo -e "\e[1;92mPhpmyadmin installation done\e[0m"
}
#Will run the composer and laravel install 
function install_composer_and_laravel {
sh composerinstall.sh
mv composer.phar /usr/local/bin/composer
su - $user -c "composer global require laravel/installer"
}
#Setup basic laravel in projectroot
function laravel_option {
su - $user -c "~/.composer/vendor/bin/laravel new $projectname"
chmod  -R g+w $projecroot/storage
chown -R www-data:www-data $projectroot/storage
a2ensite $projectname
systemctl reload apache2
systemctl start apache2
}
#Adding user to sudo
function adding_to_sudo {
/sbin/adduser $user sudo
}
#This will make your choice of the new project
#Menu for choosing new project
function choose_project {
echo "Choos new project"
echo "  1) Php basic site"
echo "  2) Laravel"
echo "  3) Stop the script"

read n
case $n in
  1) choice=php;new_project;;
  2) choice=laravel;new_project;;
  3) exit 1;;
  *) echo "invalid option";;
esac
}
#This will only execute the necessary functions if you just want a new project
function new_project {
	info
	check_if_sudo
	setting_up_variables
	make_user
	adding_to_sudo
	ssl_cert
	apache2_setup
	apache2_security
	setup_mysql
	phpmyadmin
	if [ $choice = "php" ]; then
		php_option
	elif [ $choice = "laravel" ]; then
		install_composer_and_laravel
		laravel_option
	else
		choose_project
	fi
}
#Executes all functions
function full {
	info
	check_if_sudo
	setting_up_variables
	make_user
	gathering_dependencies
	adding_to_sudo
	ssl_cert
	apache2_setup
	apache2_security
	setup_mysql
	phpmyadmin
	php_option
}
#This will show the start menu
function menu {
echo "AutomaticLamp"
echo "  1) If you run this script for the first time choose this option"
echo "  2) Another project please"
echo "  3) Stop the script"

read n
case $n in
  1) full;;
  2) choose_project;;
  3) exit 1;;
  *) echo "invalid option";;
esac
}
menu

 

