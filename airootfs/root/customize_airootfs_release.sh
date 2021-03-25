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
cp /usr/share/applications/examtool-browser.desktop /home/student/Desktop/examtool-browser.desktop
chmod +x /home/student/Desktop/examtool-browser.desktop
cp /usr/share/applications/examtool-browser-portal.desktop /home/student/Desktop/examtool-browser-portal.desktop
chmod +x /home/student/Desktop/examtool-browser-portal.desktop

# Copy DPI toggle script shortcut to desktop too
cp /usr/share/applications/examos-toggle-dpi.desktop /home/student/Desktop/examos-toggle-dpi.desktop
chmod +x /home/student/Desktop/examos-toggle-dpi.desktop

# Copy Tilix shortcut to desktop
echo -e "[Desktop Entry]\nVersion=1.0\nName=Terminal\nKeywords=shell;prompt;command;commandline;cmd\nExec=tilix" > /home/student/Desktop/Tilix.desktop
echo -e "Terminal=false\nType=Application\nStartupNotify=true\nCategories=System;TerinalEmulator\nIcon=com.gexperts.Tilix" >> /home/student/Desktop/Tilix.desktop
chmod +x /home/student/Desktop/Tilix.desktop

chown -R student:users /home/student
chown -R teacher:users /home/teacher

sudo groupadd staff
sudo usermod -a -G staff teacher

echo "teacher:securepassword" | chpasswd

sed -i 's/#\(PermitRootLogin \).\+/\1yes/' /etc/ssh/sshd_config
sed -i "s/#Server/Server/g" /etc/pacman.d/mirrorlist


# mask emergency and rescue services so that students can not boot into
# rescue mode
systemctl mask emergency.service emergency.target rescue.service rescue.target

# mask udisks2 service, that tries to automount every possible device
systemctl mask udisks2

# enable needed system services
systemctl enable pacman-init.service NetworkManager.service examtool-daemon.service examtool-hw-collector.service wifi-prober.service

# enable konekoe session listener service for user student
sudo -u student systemctl --user enable konekoe-session-listener

systemctl set-default multi-user.target

glib-compile-schemas /usr/share/glib-2.0/schemas

# Give display access to root user
# This works on Cinnamon, because Cinnamon stores the .Xauthority
# file in user's home folder. For example Gnome does not.
echo "export XAUTHORITY=/home/student/.Xauthority" >> /etc/profile


# Set OS name & so on ...
echo "NAME=\"ExamOS\"" > /etc/os-release
echo "PRETTY_NAME=\"ExamOS\"" >> /etc/os-release
echo "ID=\"examos\"" >> /etc/os-release
echo "ID_LIKE=\"archlinux\"" >> /etc/os-release
echo "BUILD_ID=$(date +%Y-%m-%d)" >> /etc/os-release
echo "ANSI_COLOR=\"0;31\"" >> /etc/os-release

# set hostname
echo "examiso" > /etc/hostname

# suppress GNOME accessibility bus errors
echo "export NO_AT_BRIDGE=1" >> /etc/environment

# remove PC speaker beep sound
echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf

# add needed plugins to vscode
sudo -u student code --install-extension ms-python.python
# sudo -u student code --install-extension ms-vscode.cpptools
