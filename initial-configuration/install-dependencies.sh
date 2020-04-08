#!/usr/bin/env bash

mkdir -p /usr/local/docker-config
cp -r config/* /usr/local/docker-config/

echo "Starting update"
yum -y update 

echo "Finished update, adding epel, docker-ce, mysql-community-release repositories and installing wget and yum-utils"
yum -y install epel-release wget yum-utils
yum-config-manager  --add-repo https://download.docker.com/linux/centos/docker-ce.repo
wget http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm
rpm -ivh mysql-community-release-el7-5.noarch.rpm
yum-config-manager --disable mysql56-community
yum-config-manager --enable mysql57-community-dmr
yum -y update

echo "Added docker-ce repo, starting docker install"
yum -y install docker-ce docker-ce-cli containerd.io

echo "Finished docker install, enabling and starting docker service"
systemctl enable docker
service docker start

echo "Installing MySQL"
yum -y install mysql-community-server
systemctl start mysqld
echo "default-time-zone='-00:00'" >> /etc/my.cnf
echo "[mysql]" > ~/.my.cnf
echo "user = root" >> ~/.my.cnf
echo "password = `grep "temporary password" /var/log/mysqld.log | cut -d ' ' -f 11`" >> ~/.my.cnf

 < /dev/urandom tr -dc @^=+$*%_A-Z-a-z-0-9 | head -c${1:-24} > pass.tmp
mysql -u root --connect-expired-password -e "alter user 'root'@'localhost' identified by '`cat pass.tmp`';flush privileges;"
sed -i "s/password = .*/password = `cat pass.tmp`/g" ~/.my.cnf
rm -f pass.tmp

mysql -u root -e "create database picsure"
mysql -u root -e "create database auth"

 < /dev/urandom tr -dc @^=+$*%_A-Z-a-z-0-9 | head -c${1:-24} > airflow.tmp
mysql -u root -e "grant all privileges on auth.* to 'airflow'@'%' identified by '`cat airflow.tmp`';flush privileges;";
mysql -u root -e "grant all privileges on picsure.* to 'airflow'@'%' identified by '`cat airflow.tmp`';flush privileges;";
sed -i s/__AIRFLOW_MYSQL_PASSWORD__/`cat airflow.tmp`/g /usr/local/docker-config/flyway/auth/flyway-auth.conf
sed -i s/__AIRFLOW_MYSQL_PASSWORD__/`cat airflow.tmp`/g /usr/local/docker-config/flyway/auth/sql.properties
sed -i s/__AIRFLOW_MYSQL_PASSWORD__/`cat airflow.tmp`/g /usr/local/docker-config/flyway/picsure/flyway-picsure.conf
sed -i s/__AIRFLOW_MYSQL_PASSWORD__/`cat airflow.tmp`/g /usr/local/docker-config/flyway/picsure/sql.properties
rm -f airflow.tmp

 < /dev/urandom tr -dc @^=+$*%_A-Z-a-z-0-9 | head -c${1:-24} > picsure.tmp
mysql -u root -e "grant all privileges on picsure.* to 'picsure'@'%' identified by '`cat picsure.tmp`';flush privileges;";
sed -i s/__PIC_SURE_MYSQL_PASSWORD__/`cat picsure.tmp`/g /usr/local/docker-config/wildfly/standalone.xml
rm -f picsure.tmp

 < /dev/urandom tr -dc @^=+$*%_A-Z-a-z-0-9 | head -c${1:-24} > auth.tmp
mysql -u root -e "grant all privileges on auth.* to 'auth'@'%' identified by '`cat auth.tmp`';flush privileges;";
sed -i s/__AUTH_MYSQL_PASSWORD__/`cat auth.tmp`/g /usr/local/docker-config/wildfly/standalone.xml
rm -f auth.tmp

echo "Building and installing Jenkins"
docker build -t pic-sure-jenkins:`git log -n 1 | grep commit | cut -d ' ' -f 2 | cut -c 1-7` jenkins/jenkins-docker
docker tag pic-sure-jenkins:`git log -n 1 | grep commit | cut -d ' ' -f 2 | cut -c 1-7` pic-sure-jenkins:LATEST
echo "Creating Jenkins Log Path"
mkdir -p /var/log/jenkins-docker-logs
mkdir -p /var/jenkins_home
cp -r jenkins/jenkins-docker/jobs /var/jenkins_home/jobs



