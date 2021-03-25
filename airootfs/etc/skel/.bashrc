#
# .bashrc
#

# get out if not interactive
if [[ $- != *i* ]]; then return; fi

# tilix VTE fix
# show help message first time tilix is opened
if [[ $TILIX_ID ]] || [ $VTE_VERSION ]; then
	source /etc/profile.d/vte.sh
	if [ -f ~/.terminalhelp ]; then
		sed -i "s/\[\[BUILDNO\]\]/$(sed -n 's/BUILD_ID=//p' /etc/os-release)/" ~/.terminalhelp
		cat ~/.terminalhelp 2>/dev/null
		rm ~/.terminalhelp 2>/dev/null
	fi
fi
