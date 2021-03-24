#!/bin/bash
#

## Function to scan Centos/Redhat
rpmscan()
{
echo "Checking requirements ..."
openssl version 2>/dev/null
if [ $? -ne 0 ]
then
	yum -y install openssl
fi
git version 2>/dev/null
if [ $? -ne 0 ]
then
        yum -y install git
fi
echo '2+1'|bc > /dev/null 2>&1
if [ $? -ne 0 ]
then
        yum -y install bc
fi
route > /dev/null 2>&1
if [ $? -ne 0 ]
then
        yum -y install net-tools
fi
clamscan -V > /dev/null 2>&1
if [ $? -ne 0 ]
then
        yum -y install clamav
	if [ $? -ne 0 ]
	then
		echo "Clamav not installed"
		exit
	fi
fi
#token=`openssl rsautl -inkey gitkey -decrypt <gitenc`
openssl enc -aes-256-cbc -d -in gitkey.enc -out /tmp/gitkey -pass pass:$salt
token=`cat /tmp/gitkey`
WDIR=/var/tmp/clamscan
mcuser=`last|egrep -i 'pts|tty1'|tail -1|awk '{print $1}'`
HDIR=`grep $mcuser /etc/passwd | cut -d ":" -f6`
if [ -d $WDIR ]
then
        rm -rf $WDIR
fi
mkdir -p $WDIR
echo "Preparing system ..."
git clone https://$token@github.com/corestackreports/clamreport.git $WDIR/report > /dev/null 2>&1
echo "Performing clam scan ..."
echo "This should take a while ..."
systemctl stop clamav-freshclam
freshclam
clamscan --max-filesize=5M --max-scansize=5M -ri $HDIR/ > $WDIR/report.txt
ls -l /sys/class/power_supply/|grep BAT > /dev/null 2>&1
if [ $? -eq 0 ]
then
	mctype="Laptop"
else
	mctype="Workstation/Server"
fi
update=`grep Updated: /var/log/yum.log|tail -1|awk '{print $1" "$2" "$3}'`
netintf=`route | grep '^default' | grep -o '[^ ]*$'|tail -1`
mac=`cat /sys/class/net/$netintf/address`
engver=`clamscan -V|awk -F/ '{print $1}'|awk '{print $NF}'`
dbver=`clamscan -V|awk -F/ '{print $2}'`
host=`uname -n`
infected=`cat $WDIR/report.txt|grep -i infected|awk '{print $NF}'`
dt=`date`
scanned=`cat $WDIR/report.txt|grep -i scanned|grep -i files|awk '{print $NF}'`
echo "Exporting result"
awk -v mac="$mac" -F , '{if ( $3 != mac ) print}' $WDIR/report/clamscanreport.csv > $WDIR/clamscanreport.csv
echo "$host,$mcuser,$mac,$mctype,$update,$engver,$dbver,$dt,$scanned,$infected" >> $WDIR/clamscanreport.csv
cp $WDIR/clamscanreport.csv $WDIR/report/clamscanreport.csv
cd $WDIR/report/
git config user.name $host
git config user.email $host@corestack.io
git add . > /dev/null 2>&1
git commit -m "updated $host clamav scan report" > /dev/null 2>&1
git push https://$token@github.com/corestackreports/clamreport.git > /dev/null 2>&1
echo "Performing cleanup ..."
rm -rf $WDIR/report > /dev/null 2>&1
rm $WDIR/clamscanreport.csv > /dev/null 2>&1
echo "Report collected at: $WDIR/report.txt"
}

## Function to perform debian/ubuntu scan
debscan()
{
echo "Checking requirements ..."
openssl version 2>/dev/null
if [ $? -ne 0 ]
then
        apt -y install openssl
fi
git version 2>/dev/null
if [ $? -ne 0 ]
then
        apt -y install git
fi
echo '2+1'|bc > /dev/null 2>&1
if [ $? -ne 0 ]
then
        apt -y install bc
fi
route > /dev/null 2>&1
if [ $? -ne 0 ]
then
        apt -y install net-tools
fi
#token=`openssl rsautl -inkey gitkey -decrypt <gitenc`
openssl enc -aes-256-cbc -d -in gitkey.enc -out /tmp/gitkey -pass pass:$salt
if [ $? -ne 0 ]
then
	openssl enc -aes-256-cbc -d -in gitkey.enc -out /tmp/gitkey -pass pass:$salt -md md5
fi
token=`cat /tmp/gitkey`
WDIR=/var/tmp/osscan
mcuser=`last|egrep -i 'pts|tty1'|tail -1|awk '{print $1}'`
HDIR=`grep $mcuser /etc/passwd | cut -d ":" -f6`
if [ -d $WDIR ]
then
        rm -rf $WDIR
fi
mkdir -p $WDIR
echo "Preparing system ..."
git clone https://$token@github.com/corestackreports/clamreport.git $WDIR/report > /dev/null 2>&1
echo "Performing OS Update ..."
echo "This should take a while ..."
apt-get update -y | tee -a /tmp/update-output.txt
apt-get upgrade -y | tee -a /tmp/update-output.txt
apt-get clean | tee -a /tmp/update-output.txt
ls -l /sys/class/power_supply/|grep BAT > /dev/null 2>&1
if [ $? -eq 0 ]
then
	mctype="Laptop"
else
	mctype="Workstation/Server"
fi
update=`ls -ltr /var/cache/apt/archives|tail -1|awk '{print $6" "$7" "$8}'`
osver=`lsb_release -ar 2>/dev/null | grep -i description | cut -s -f2`
netintf=`route | grep '^default' | grep -o '[^ ]*$'|tail -1`
mac=`cat /sys/class/net/$netintf/address`
host=`uname -n`
dt=`date`
echo "Exporting result"
awk -v mac="$mac" -F , '{if ( $3 != mac ) print}' $WDIR/report/osscanreport.csv > $WDIR/osscanreport.csv
echo "$host,$mcuser,$mac,$mctype,$osver,$update" >> $WDIR/osscanreport.csv
cp $WDIR/osscanreport.csv $WDIR/report/osscanreport.csv
cd $WDIR/report/
git config user.name $host
git config user.email $host@corestack.io
git add . > /dev/null 2>&1
git commit -m "updated $host os scan report" > /dev/null 2>&1
git push https://$token@github.com/corestackreports/clamreport.git > /dev/null 2>&1
echo "Performing cleanup ..."
rm -rf $WDIR/report > /dev/null 2>&1
rm $WDIR/osscanreport.csv > /dev/null 2>&1
echo "Report collected at: $WDIR/report.txt"
}

### Main Program

salt=$1

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

if [[ $salt == "" ]]; then
   echo "Decryption key not provided"
   exit 1
fi

cat /etc/*-release|grep -w NAME|egrep -i "ubuntu|debian" > /dev/null 2>&1
if [ $? -eq 0 ]
then
	debscan
	exit 0
fi

cat /etc/*-release|grep -w NAME|egrep -i "centos|redhat" > /dev/null 2>&1
if [ $? -eq 0 ]
then
        rpmscan
fi
