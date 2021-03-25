#!/bin/bash
set -e -u

# sed -i 's/#\(en_US\.UTF-8\)/\1/' /etc/locale.gen
sed -i 's/#\(fi_FI\.UTF-8\)/\1/' /etc/locale.gen
# sed -i 's/#\(sv_FI\.UTF-8\)/\1/' /etc/locale.gen
locale-gen

ln -sf /usr/share/zoneinfo/Europe/Helsinki /etc/localtime

usermod -s /usr/bin/bash root

cp -aT /etc/skel/ /root/
useradd -m -p "" -g users -G "audio,network,rfkill,power" -s /bin/bash student
useradd -m -p "" -g users -G "adm,audio,floppy,log,network,rfkill,scanner,storage,optical,power,wheel" -s /bin/bash teacher

# create a desktop entry to examtool browser for student
mkdir /home/student/Desktop


# Copy Tilix shortcut to desktop
echo -e "[Desktop Entry]\nVersion=1.0\nName=Terminal\nKeywords=shell;prompt;command;commandline;cmd\nExec=tilix" > /home/student/Desktop/Tilix.desktop
echo -e "Terminal=false\nType=Application\nStartupNotify=true\nCategories=System;TerinalEmulator\nIcon=com.gexperts.Tilix" >> /home/student/Desktop/Tilix.desktop
chmod +x /home/student/Desktop/Tilix.desktop

chown -R student:users /home/student
chown -R teacher:users /home/teacher

sudo groupadd staff
sudo usermod -a -G staff teacher

echo "teacher:teacher" | chpasswd

sed -i 's/#\(PermitRootLogin \).\+/\1yes/' /etc/ssh/sshd_config
sed -i "s/#Server/Server/g" /etc/pacman.d/mirrorlist


# mask emergency and rescue services so that students can not boot into
# rescue mode
#systemctl mask emergency.service emergency.target rescue.service rescue.target

# mask udisks2 service, that tries to automount every possible device
#systemctl mask udisks2

systemctl enable pacman-init.service NetworkManager.service wifi-prober.service
systemctl set-default multi-user.target

glib-compile-schemas /usr/share/glib-2.0/schemas

# Give display access to root user
# This works on Cinnamon, because Cinnamon stores the .Xauthority
# file in user's home folder. For example Gnome does not.
#echo "export XAUTHORITY=/home/student/.Xauthority" >> /etc/profile


# Set OS name & so on ...
echo "NAME=\"ExamOS\"" > /etc/os-release
echo "PRETTY_NAME=\"ExamOS\"" >> /etc/os-release
echo "ID=\"examos\"" >> /etc/os-release
echo "ID_LIKE=\"archlinux\"" >> /etc/os-release
echo "BUILD_ID=$(date +%Y-%m-%d)" >> /etc/os-release
echo "ANSI_COLOR=\"0;31\"" >> /etc/os-release

# set hostname
echo "examiso" > /etc/hostname

# set FF homepage
#echo "lockPref(\"app.update.enabled\", false);" >> /usr/lib/firefox/browser/defaults/preferences/vendor.js
#echo "lockPref(\"app.update.auto\", false);" >> /usr/lib/firefox/browser/defaults/preferences/vendor.js
#echo "lockPref(\"app.update.mode\", 0);" >> /usr/lib/firefox/browser/defaults/preferences/vendor.js
#echo "lockPref(\"app.update.service.enabled\", false);" >> /usr/lib/firefox/browser/defaults/preferences/vendor.js
#echo "pref(\"browser.rights.3.shown\", true);" >> /usr/lib/firefox/browser/defaults/preferences/vendor.js
#echo "pref(\"browser.startup.homepage_override.mstone\",\"ignore\");" >> /usr/lib/firefox/browser/defaults/preferences/vendor.js
#echo "defaultPref(\"browser.startup.homepage\",\"data:text/plain,browser.startup.homepage=http://c7241-1.comnet.aalto.fi\");" >> /usr/lib/firefox/browser/defaults/preferences/vendor.js
#echo "pref(\"plugins.notifyMissingFlash\", false);" >> /usr/lib/firefox/browser/defaults/preferences/vendor.js

# suppress GNOME accessibility bus errors
echo "export NO_AT_BRIDGE=1" >> /etc/environment

# remove PC speaker beep sound
echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf

# add needed plugins to vscode
sudo -u student code --install-extension ms-python.python
# sudo -u student code --install-extension ms-vscode.cpptools

