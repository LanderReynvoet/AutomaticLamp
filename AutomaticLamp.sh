#!/bin/bash 

#require sudo 

if [[ $(/usr/bin/id -u) -ne 0 ]]; then 
echo "Run script with root privelleges" 
exit 
fi 


#saving input variables

#before setup 

apt update  

apt upgrade -y 

#dependencies 

apt install ca-certificates apt-transport-https -y 

apt install apache2 php-mysql libapache2-mod-php7.3 -y 

apt install php-common php-mbstring php-xml php-zip php-curl -y 

apt install mariadb-server-10.3 -y 

#configure 