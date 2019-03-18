# read config.ini
if ["$1" = ""]; then 
	echo "Please specify config.ini"
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

# install dependencies
if [ ! -f /usr/bin/jq ]; then
        echo "No jq found. Copying"
		chmod +x bin/jq
        cp bin/jq /usr/bin
else
        echo "jq installed. Moving on."
fi

# set some constants
OPM_USER="OPM_$HOSTNAME"
PVWAURL="https://$PVWA/PasswordVault/"
LOGON_RESOURCE="$PVWAURL/WebServices/auth/Cyberark/CyberArkAuthenticationService.svc/Logon"
LOGOFF_RESOURCE="$PVWAURL/WebServices/auth/Cyberark/CyberArkAuthenticationService.svc/Logoff"
DELUSER_RESOURCE="$PVWAURL/WebServices/PIMServices.svc/Users/$OPM_USER"
GET_ACCT_RESOURCE="$PVWAURL/WebServices/PIMServices.svc/Accounts?Keywords=$ip4&Safe=Linux-root"
GET_ACCTS_RESOURCE="$PVWAURL/api/Accounts?search=$ip4"

# get logon token
LOGON_TOKEN=$(curl --insecure -s -H "Accept:application/json" -H "Content-Type:application/json" -X POST --data '{"username":"'"$ADMIN_UN"'", "password":"'"$ADMIN_PW"'"}' $LOGON_RESOURCE | jq '.CyberArkLogonResult' | sed 's|["]||g')

# remove provider from agents group
curl --insecure -s -H "Authorization:$LOGON_TOKEN" -H "Content-Type:application/json" -X DELETE "$DELUSER_RESOURCE"

# get local accounts respective to host
ACCT_ID=$(curl --insecure -s -H "Authorization:$LOGON_TOKEN" -H "Accept:application/json" -H "Content-Type:application/json" -X GET -d "" $GET_ACCTS_RESOURCE | jq '.value|.[]|.id' | sed 's|["]||g')
arr=(`echo ${ACCT_ID}`);
LOGONACCT_ID=${arr[0]}
ROOTACCT_ID=${arr[1]}
DEL_LOGON_RESOURCE="$PVWAURL/WebServices/PIMServices.svc/Accounts/$LOGONACCT_ID"
DEL_ROOT_RESOURCE="$PVWAURL/WebServices/PIMServices.svc/Accounts/$ROOTACCT_ID"

# delete local accounts
curl --insecure -s -H "Authorization:$LOGON_TOKEN" -H "Accept:application/json" -H "Content-Type:application/json" -X DELETE $DEL_LOGON_RESOURCE -d ""
curl --insecure -s -H "Authorization:$LOGON_TOKEN" -H "Accept:application/json" -H "Content-Type:application/json" -X DELETE $DEL_ROOT_RESOURCE -d ""


# logoff
curl --insecure -s -H "Authorization:$LOGON_TOKEN" -H "Content-Type:application/json" -X POST "$LOGOFF_RESOURCE" -d ""
rm /usr/bin/jq

# uninstall OPM
rpm -evh CARKpam
rpm -evh CARKaim
