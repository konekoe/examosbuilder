#!/bin/sh
#
# ~./.xinitrc
#
# Executed by startx


# applies all xorg configs in /etc/X11/xinit/xinitrc.d
if [ -d /etc/X11/xinit/xinitrc.d]; then
        for f in /etc/X11/xinit/xinitrc.d/*; do
                [ -x "$f" ] && ."$f"
        done
        unset f
fi


# Let root user attach to the Xsession
xhost si:localuser:root

# Export the XDG_SESSION_TYPE, which is left unset for some reason
# https://bbs.archlinux.org/viewtopic.php?id=243298
export XDG_SESSION_TYPE="X11"

# finally start cinnamon session
exec cinnamon-session
