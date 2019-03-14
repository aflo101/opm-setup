#!/bin/bash

# read config.conf
if [$1 = ""]; then 
	echo "Please specify config.conf"
	exit; 
else
	CONFIG=$(cut -d$'\n' -f1 $1 | cut -d "=" -f2) 

	line=( $CONFIG )
	#readarray -t line < $1
	PVWA=${line[0]}
	ADMIN_UN=${line[1]}
	OPM_GRP=${line[2]}
	TARGET_SAFE=${line[3]}
	TARGET_USER=${line[4]}
	VAULTIP=${line[5]};
fi

# ask for admin password to connect PVWA REST
echo -n "Enter Cyberark administrator password:"
read -s ADMIN_PW
echo
# ADMIN_PW="Cyberark1"

# set some constants
#ip4=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
ip4="$HOSTNAME"
PLATFORM="UnixSSH"
ACCT_NAME="Operating System-$PLATFORM-$ip4-$TARGET_USER"
ROOT_ACCT_NAME="Operating System-$PLATFORM-$ip4-root"
OPM_USER="OPM_$HOSTNAME"

PVWAURL="https://$PVWA/PasswordVault/"
LOGON_RESOURCE="$PVWAURL/WebServices/auth/Cyberark/CyberArkAuthenticationService.svc/Logon"
LOGOFF_RESOURCE="$PVWAURL/WebServices/auth/Cyberark/CyberArkAuthenticationService.svc/Logoff"
GETGRP_RESOURCE="$PVWAURL/api/UserGroups?filter=groupType%20eq%20Vault&search=opm_agents"
ADDTOGRP_RESOURCE="$PVWAURL/api/UserGroups/$OPM_GROUP/Members/"
ACCOUNTS_RESOURCE="$PVWAURL/api/Accounts"

CRED_LOC="$PWD/RHELinux-Intel64/user.cred"
VAULT_LOC="$PWD/RHELinux-Intel64/Vault.ini"

# install dependencies
yum install redhat-lsb -y
if [ ! -f /usr/bin/jq ]; then
        echo "No jq found. Copying"
		chmod +x bin/jq
        cp bin/jq /usr/bin
else
        echo "jq installed. Moving on."
fi


# create credfile
chmod +x ./RHELinux-Intel64/CreateCredFile
./RHELinux-Intel64/CreateCredFile ./RHELinux-Intel64/user.cred Password -Username administrator -Password $ADMIN_PW

# build /var/tmp/aimparms
head -n 1 ./RHELinux-Intel64/aimparms.sample > /var/tmp/aimparms
echo "AcceptCyberArkEULA=Yes" >> /var/tmp/aimparms
echo "CreateVaultEnvironment=Yes" >> /var/tmp/aimparms
echo "LicensedProducts=OPM" >> /var/tmp/aimparms
echo "CredFilePath=$CRED_LOC" >> /var/tmp/aimparms
echo "VaultFilePath=$VAULT_LOC" >> /var/tmp/aimparms
tail -24 ./RHELinux-Intel64/aimparms.sample >> /var/tmp/aimparms

# build vault.ini
cp ./RHELinux-Intel64/Vault.ini ./RHELinux-Intel64/Vault.tmp
head -n 1 ./RHELinux-Intel64/Vault.ini > ./RHELinux-Intel64/Vault.tmp
echo "ADDRESS=$VAULTIP" >> ./RHELinux-Intel64/Vault.tmp
tail -33 ./RHELinux-Intel64/Vault.ini >> ./RHELinux-Intel64/Vault.tmp
cp RHELinux-Intel64/Vault.tmp RHELinux-Intel64/Vault.ini
rm RHELinux-Intel64/Vault.tmp

# install OPM and PAM
rpm -ivh ./RHELinux-Intel64/CARKaim*
rpm -ivh ./RHELinux-Intel64/PAM/CARKpam*

# get logon token
LOGON_TOKEN=$(curl --insecure -s -H "Accept:application/json" -H "Content-Type:application/json" -X POST --data '{"username":"'"$ADMIN_UN"'", "password":"'"$ADMIN_PW"'"}' $LOGON_RESOURCE | jq '.CyberArkLogonResult' | sed 's|["]||g')

echo
echo "Logon Successful."

# get group id
OPM_GROUP=$(curl --insecure -s  -H "Authorization:$LOGON_TOKEN" -H "Accept:application/json" -X GET "$GETGRP_RESOURCE" | jq '.[] | .[0] | .id')
ADDTOGRP_RESOURCE="$PVWAURL/api/UserGroups/$OPM_GROUP/Members/"

 
echo "Have group ID."

# add opm agent to group
curl --insecure -s -H "Authorization:$LOGON_TOKEN" -H "Accept:application/json" -H "Content-Type:application/json" -X POST --data '{"MemberID":"'"$OPM_USER"'"}' $ADDTOGRP_RESOURCE

echo
echo "Agent added successfully to $OPM_GRP"

# add local accounts to safe
curl --insecure -s -H "Authorization:$LOGON_TOKEN" -H "Content-Type:application/json" -H "Accept:application/json" -X POST -d '{"name":"'"$ACCT_NAME"'", "address":"'"$ip4"'", "userName":"'"$TARGET_USER"'", "platformId":"'"$PLATFORM"'", "safeName":"'"$TARGET_SAFE"'", "secretType":"password", "secret":"Cyberark1", "secretManagement": {"automaticManagementEnabled":true}}' $ACCOUNTS_RESOURCE
curl --insecure -s -H "Authorization:$LOGON_TOKEN" -H "Content-Type:application/json" -H "Accept:application/json" -X POST -d '{"name":"'"$ROOT_ACCT_NAME"'", "address":"'"$ip4"'", "userName":"root", "platformId":"'"$PLATFORM"'", "safeName":"'"$TARGET_SAFE"'", "secretType":"password", "secret":"Cyberark1", "secretManagement": {"automaticManagementEnabled":true}}' $ACCOUNTS_RESOURCE

echo 
echo "Added $TARGET_USER."
echo "Added root."
echo

# logoff
curl --insecure -s -H "Authorization:$LOGON_TOKEN" -H "Content-Type:application/json" -X POST "$LOGOFF_RESOURCE" -d ""

echo
echo "Finished."
