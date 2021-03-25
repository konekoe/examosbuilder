#!/bin/sh
#
# ~/.bash_profile skeleton for liveUSB
#


[[ -f ~/.bashrc ]] && . ~/.bashrc

if [[ -z $DISPLAY && $XDG_VTNR -eq 1 ]]; then
	exec startx
fi