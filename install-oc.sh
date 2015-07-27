#!/bin/bash

## Author: Andrew Reeves
## Purpose: Install ownCloud (current release) on Debian 7.
## Notes: Uses ownCloud repositories to install most recent version
##			on a Debian 7.x system with MySQL backend and forced
##			SSL (using self-signed cert). Script assumes system
##			is a fresh install (tested using a minimal net-install
##			base) with no additional configurations set.
##			Script will perform the following actions:
##			1. Collect relevant information needed for install.
##			2. Set IP stack (IP, Netmask, DNS, and Gateway).
##			3. Install MySQL and configure ownCloud database.
##			4. Install latest version of ownCloud from
##			   community repository.
##			5. Configure SSL and create self-signed cert.
##			6. Configure Apache/ownCloud site.
##				- Enforce SSL.
##				- Configure additional ownCloud site variables.
##				- Very basic clean up.
##
## How to use:
##			1. Copy this script file to any directory on your system.
##			2. chmod the script so it can run.
##				Ex. ~$ chmod 700 install-oc.sh
##			3. Elevate to root.
##				Ex. ~$ su    (provide root pw when prompted)
##			4. Execute script.
##				Ex. ~$ ./install-oc.sh
##			5. Answer all questions then sit back for a few minutes.
##
## Post-install notes:
##			1. A restart is highly recommended.
##

## Create pause function to be used later.
pause(){
 read -n1 -rsp $'Press any key to continue...\n'
}


## Collect some information before we move forward.
read -p "Enter a static IP to be used for this server (e.g. 192.168.1.105):" ipaddr
read -p "Enter a subnet mask (e.g. 255.255.255.0):" subnet
read -p "Enter a gateway (e.g. 192.168.1.1):" gateway
read -p "Specify your primary DNS (e.g. 4.2.2.1):" pridns
read -p "Specify your secondary DNS (e.g. 4.2.2.2):" secdns
echo "Specify a password for the MySQL root user"
read -p "(It is highly recommended to set a strong password here):" sqlrootpw
read -p "Specify a name for the OwnCloud database:" ocdb
read -p "Specify a name for the ownCloud database user:" ocdbuser
echo "Specify a password for the ownCloud database user"
read -p "(Strong password recommended, should be different from MySQL root password):" ocdbpw
read -p "SSL info: Enter your country (e.g. US):" country
read -p "SSL info: Enter your state (e.g. DC):" state
read -p "SSL info: Enter your city (e.g. Arlington):" city
read -p "SSL info: Enter your organization (e.g. Home):" org

echo "Setting static IP..."
echo "# This file describes the network interfaces available on your system" > /etc/network/interfaces
echo "# and how to activate them. For more information, see interfaces(5)." >> /etc/network/interfaces
echo "" >> /etc/network/interfaces
echo "# The loopback network interface" >> /etc/network/interfaces
echo "auto lo" >> /etc/network/interfaces
echo "iface lo inet loopback" >> /etc/network/interfaces
echo "" >> /etc/network/interfaces
echo "# The primary network interface" >> /etc/network/interfaces
echo "auto eth0" >> /etc/network/interfaces
echo "iface eth0 inet static" >> /etc/network/interfaces
echo "address $ipaddr" >> /etc/network/interfaces
echo "netmask $subnet" >> /etc/network/interfaces
echo "gateway $gateway" >> /etc/network/interfaces
sleep 1

echo "Setting DNS..."
echo "domain localdomain" > /etc/resolve.conf
echo "search localdomain" >> /etc/resolve.conf
echo "nameserver $pridns" >> /etc/resolve.conf
echo "nameserver $secdns" >> /etc/resolve.conf
sleep 1

echo "Updating aptitude repositories..."
sleep 3
apt-get update

echo "Installing MySQL..."
sleep 3
echo "mysql-server mysql-server/root_password password $sqlrootpw" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $sqlrootpw" | debconf-set-selections
apt-get -y install mysql-server mysql-client

echo "Configuring ownCloud DB..."
sleep 3
mysql -u root -p$sqlrootpw -e "CREATE DATABASE $ocdb; GRANT ALL ON $ocdb.* to '$ocdbuser'@'localhost' identified by '$ocdbpw';"

echo "Downloading ownCloud setup files..."
sleep 3
wget "http://download.opensuse.org/repositories/isv:ownCloud:community/Debian_7.0/Release.key"
apt-key add - < Release.key
echo "deb http://download.opensuse.org/repositories/isv:ownCloud:community/Debian_7.0/ /" >> /etc/apt/sources.list.d/owncloud.list

echo "Installing ownCloud..."
sleep 3
apt-get update
apt-get -y install owncloud

echo "Setting ownCloud directory permissions..."
sleep 3
## This section uses official ownCloud documentation standards
ocpath='/var/www/owncloud'
htuser='www-data'
htgroup='www-data'

find ${ocpath}/ -type f -print0 | xargs -0 chmod 0640
find ${ocpath}/ -type d -print0 | xargs -0 chmod 0750

chown -R root:${htuser} ${ocpath}/
chown -R ${htuser}:${htgroup} ${ocpath}/apps/
chown -R ${htuser}:${htgroup} ${ocpath}/config/
chown -R ${htuser}:${htgroup} ${ocpath}/data/
chown -R ${htuser}:${htgroup} ${ocpath}/themes/
## End permissions adjustment.

echo "Configuring SSL..."
sleep 3
mkdir /etc/apache2/ssl

openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=$country/ST=$state/L=$city/O=$org/CN=$ipaddr" -keyout owncloud.key  -out owncloud.crt

mv owncloud.key /etc/apache2/ssl/owncloud.key
mv owncloud.crt /etc/apache2/ssl/owncloud.crt

chmod 400 /etc/apache2/ssl/owncloud.key
chmod 400 /etc/apache2/ssl/owncloud.crt

echo "Enabling SSL and restarting services..."
sleep 3
a2enmod ssl
a2enmod headers
a2enmod env
service apache2 restart

echo "Configuring Apache/ownCloud site..."
sleep 3

cp /etc/apache2/ports.conf /etc/apache2/ports.bak

echo "NameVirtualHost $ipaddr:443" > /etc/apache2/ports.conf
echo "" >> /etc/apache2/ports.conf
echo "<IfModule mod_ssl.c>" >> /etc/apache2/ports.conf
echo "Listen 443" >> /etc/apache2/ports.conf
echo "</IfModule>" >> /etc/apache2/ports.conf
echo "" >> /etc/apache2/ports.conf
echo "<IfModule mod_gnutls.c>" >> /etc/apache2/ports.conf
echo "Listen 443" >> /etc/apache2/ports.conf
echo "</IfModule>" >> /etc/apache2/ports.conf

mkdir /var/www/logs

echo "<VirtualHost $ipaddr:443>" > /etc/apache2/sites-available/myowncloudserver
echo "ServerName myowncloudserver.com" >> /etc/apache2/sites-available/myowncloudserver
echo 'Header always add Strict-Transport-Security "max-age=15768000; includeSubDomains; preload"' >> /etc/apache2/sites-available/myowncloudserver
echo "SSLEngine on" >> /etc/apache2/sites-available/myowncloudserver
echo "SSLCertificateFile /etc/apache2/ssl/owncloud.crt" >> /etc/apache2/sites-available/myowncloudserver
echo "SSLCertificateKeyFile /etc/apache2/ssl/owncloud.key" >> /etc/apache2/sites-available/myowncloudserver
echo "DocumentRoot /var/www/owncloud" >> /etc/apache2/sites-available/myowncloudserver
echo "CustomLog /var/www/logs/ssl-access_log combined" >> /etc/apache2/sites-available/myowncloudserver
echo "ErrorLog /var/www/logs/ssl-error_log" >> /etc/apache2/sites-available/myowncloudserver
echo "</VirtualHost>" >> /etc/apache2/sites-available/myowncloudserver

echo "Removing default/OOB Apache sites..."
sleep 3
find /etc/apache2/sites-enabled/ -type l -exec rm "{}" \;

echo "Activating ownCloud site..."
sleep 3
a2ensite myowncloudserver
service apache2 restart

## Wait for setup wizard to be finalized
## then adjust .htaccess permissions.
echo "Please launch the Post-Install Wizard by visiting https://$ipaddr"
echo "When you are done return to this window and press any key to continue."
pause
chown root:${htuser} ${ocpath}/.htaccess
chown root:${htuser} ${ocpath}/data/.htaccess

chmod 0644 ${ocpath}/.htaccess
chmod 0644 ${ocpath}/data/.htaccess
## End .htaccess adjustment.

echo "All done! Please restart your computer for good measure."