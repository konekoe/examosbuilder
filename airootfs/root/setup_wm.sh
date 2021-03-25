#!/bin/bash
set -e -u

# load the default plank configuration
cat /root/plank-dconf.ini | sudo -u student dbus-launch dconf load /net/launchpad/plank/docks/

# enable plank-starter service for user student
sudo -u student systemctl --user enable plank-starter


# disable cinnamon menu bars for student
sudo -u student dbus-launch dconf write /org/cinnamon/panels-enabled "['']"

# set date format
sudo -u student dbus-launch dconf write /org/cinnamon/date-format "'DD.MM.YYYY'"

# set tilix as default terminal application
sudo -u student dbus-launch dconf write /org/cinnamon/desktop/applications/terminal/exec "'tilix'"
sudo -u student dbus-launch dconf write /org/cinnamon/desktop/applications/terminal/exec-arg "''"

# set initial scaling for the desktop
sudo -u student dbus-launch dconf write /org/cinnamon/desktop/interface/cursor-size 40
sudo -u student dbus-launch dconf write /org/cinnamon/desktop/interface/text-scaling-factor 1.5
sudo -u student dbus-launch dconf write /org/cinnamon/desktop/session/idle-delay 1500

# set power options
sudo -u student dbus-launch dconf write /org/cinnamon/desktop/session/idle-delay 1500
sudo -u student dbus-launch dconf write /org/cinnamon/settings-daemon/plugins/power/button-power "'interactive'"
sudo -u student dbus-launch dconf write /org/cinnamon/settings-daemon/plugins/power/sleep-inactive-battery-timeout 0
sudo -u student dbus-launch dconf write /org/cinnamon/settings-daemon/plugins/power/lid-close-ac-action "'nothing'"
sudo -u student dbus-launch dconf write /org/cinnamon/settings-daemon/plugins/power/lid-close-battery-action "'nothing'"
sudo -u student dbus-launch dconf write /org/cinnamon/settings-daemon/plugins/power/sleep-inactive-ac-timeout 0
sudo -u student dbus-launch dconf write /org/cinnamon/settings-daemon/plugins/power/sleep-display-ac 0
sudo -u student dbus-launch dconf write /org/cinnamon/settings-daemon/plugins/power/sleep-display-battery 0

# set initial keyboards
sudo -u student dbus-launch dconf write /org/gnome/libgnomekbd/keyboard/layouts "['fi', 'fi\tmac', 'us', 'us\tmac']"

# allow opening terminal from Nemo
sudo -u student dbus-launch dconf write /org/nemo/preferences/show-open-in-terminal-toolbar true