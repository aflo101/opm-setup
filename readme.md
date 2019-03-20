In CyberArk - this portion refers to using local CyberArk groups for psuedo-AD Bridging. Same methodology can be used within Active Directory for the opm_users group and user.
	Create (or give your administrator user permissions to modify) a Linux safe. (this is your $TARGET_SAFE).
	Create opm_agents group (ex. opm_agents - this is your $OPM_GRP).
		Give your opm_agents group permissions to read/list/use passswords on your Linux safe ($TARGET_SAFE).
	Create opm_users group. (ex. opm_users - gives your users ability to adbridge and pimsu on Linux hosts)
		Create a local user (your ADbridge user) and add this user to opm_users group. Give your opm_users group read/list/use on Linux safe

In config.conf (on OPM server) IMPORTANT: CONFIG.CONF DOESN'T LIKE VALUES WITH SPACES. TRY TO AVOID FOR NOW.
	Set $PVWA (ex. components.cyberarkdemo.com - NO HTTPS)
	Set $ADMIN_UN (ex. administrator - LOGOFF PRIVATEARK CLIENT)
	Set $OPM_GRP (ex. opm_agents)
	Set $TARGET_SAFE (ex. Linux-Root)
	Set $TARGET_USER (ex. logon)
	Set $VAULTIP (ex. 10.0.1.10)

On local host
	unzip OPM (RHELLinux...zip) into this directory.
	vi /etc/ssh/sshd_config - ChallengeResponseAuthentication yes (allows PAM password authentication)
	
Run setup.sh (as root or with sudo)
	sudo ./setup.sh config.ini

Reboot linux server after completion
	sudo reboot now
	
Test!
	{your ADBridge user}@{opmhost}
	ex: alex@rhel02
	

Notes:
Make sure your PVWA bindings are set to the address you configure for PVWA in config.conf

