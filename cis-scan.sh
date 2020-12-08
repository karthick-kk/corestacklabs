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

token=`openssl rsautl -inkey gitkey -decrypt <gitenc`

WDIR=/var/tmp/cisscan
if [ -d $WDIR ]
then
	rm -rf $WDIR
fi
mkdir -p $WDIR

echo "Preparing system ..."

git clone https://$token@github.com/corestackreports/cisscripts.git $WDIR/scripts > /dev/null 2>&1
git clone https://$token@github.com/corestackreports/cisscore.git $WDIR/report > /dev/null 2>&1

echo "Performing CIS benchmark scan ..."
cd $WDIR/scripts/centos-cis-benchmark/
bash centos-cis-benchmark.sh > $WDIR/result.txt

host=`hostname`
echo "Exporting result"

awk -v host="$host" -F , '{if ( $1 != host ) print}' $WDIR/report/va.csv > $WDIR/va.csv
tail -1 $WDIR/result.txt|sed 's/|/,/g' >> $WDIR/va.csv
cp $WDIR/va.csv $WDIR/report/va.csv
cd $WDIR/report/
git config user.name $host
git config user.email $host@corestack.io
git add . > /dev/null 2>&1
git commit -m "updated $host cis scan report" > /dev/null 2>&1
git push https://$token@github.com/corestackreports/cisscore.git > /dev/null 2>&1

echo "Performing cleanup ..."
rm -rf $WDIR/scripts > /dev/null 2>&1
rm -rf $WDIR/report > /dev/null 2>&1
rm $WDIR/va.csv > /dev/null 2>&1

echo "Report collected at: $WDIR/result.txt"
}

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


token=`openssl rsautl -inkey gitkey -decrypt <gitenc`

WDIR=/var/tmp/cisscan
if [ -d $WDIR ]
then
        rm -rf $WDIR
fi
mkdir -p $WDIR

echo "Preparing system ..."

git clone https://$token@github.com/corestackreports/cisscripts.git $WDIR/scripts > /dev/null 2>&1
git clone https://$token@github.com/corestackreports/cisscore.git $WDIR/report > /dev/null 2>&1

echo "Performing CIS benchmark scan ..."
cd $WDIR/scripts/debian-cis
cp debian/default /etc/default/cis-hardening
sed -i "s#CIS_ROOT_DIR=.*#CIS_ROOT_DIR='$(pwd)'#" /etc/default/cis-hardening
bin/hardening.sh --audit-all 2>/dev/null > $WDIR/result.txt

host=`hostname`
echo "Exporting result"

awk -v host="$host" -F , '{if ( $1 != host ) print}' $WDIR/report/va.csv > $WDIR/va.csv
tail -1 $WDIR/result.txt|sed 's/|/,/g' >> $WDIR/va.csv
cp $WDIR/va.csv $WDIR/report/va.csv
cd $WDIR/report/
git config user.name $host
git config user.email $host@corestack.io
git add . > /dev/null 2>&1
git commit -m "updated $host cis scan report" > /dev/null 2>&1
git push https://$token@github.com/corestackreports/cisscore.git > /dev/null 2>&1

echo "Performing cleanup ..."
rm -rf $WDIR/scripts > /dev/null 2>&1
rm -rf $WDIR/report > /dev/null 2>&1
rm $WDIR/va.csv > /dev/null 2>&1

echo "Report collected at: $WDIR/result.txt"
}

### Main Program

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
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
