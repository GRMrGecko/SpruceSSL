#!/bin/sh
# Copyright 2003-2009, Mike Solomon <mas63@cornell.edu>
# SIMBL is released under the GNU General Public License v2.
# http://www.opensource.org/licenses/gpl-2.0.php

PACKAGE_PATH=$1
INSTALL_PATH=$2
INSTALL_VOLUME=$3
SYSTEM_ROOT=$4

RESOURCES="${PACKAGE_PATH}/Contents/Resources"

# FIXME(mike) maybe we should copy this out of the install package instead?
LAUNCHD_PLIST="/Library/ScriptingAdditions/SIMBL.osax/Contents/Resources/SIMBL Agent.app/Contents/Resources/net.culater.SIMBL.Agent.plist"
OSAX_PLIST="/Library/ScriptingAdditions/SIMBL.osax/Contents/Info.plist"

# remove old InputManager if it exists, otherwise these
# two will contend when applications run under 32-bit mode
SIMBL_INPUTMANAGER="/Library/InputManagers/SIMBL"
if [ -d "$SIMBL_INPUTMANAGER" ]; then
  rm -rf "$SIMBL_INPUTMANAGER"
fi

LAUNCH_AGENTS_DIR="/Library/LaunchAgents"
if [ ! -d "$LAUNCH_AGENTS_DIR" ]; then
  mkdir -p "$LAUNCH_AGENTS_DIR"
  chown root:wheel "$LAUNCH_AGENTS_DIR"
fi
# ensure agents are world-readable, but must be no more permissive
# than 755, otherwise they are just skipped.
chmod 755 "$LAUNCH_AGENTS_DIR"

# ensure that this loads on restart
cp "$LAUNCHD_PLIST" "$LAUNCH_AGENTS_DIR"
if [ $? != 0 ]; then
  exit 1
fi

# create a system-wide location for plugins
SIMBL_PLUGINS_DIR="/Library/Application Support/SIMBL/Plugins"
if [ ! -d "$SIMBL_PLUGINS_DIR" ]; then
  mkdir -p "$SIMBL_PLUGINS_DIR"
  chown root:admin "$SIMBL_PLUGINS_DIR"
fi
# ensure plugins are world-readable
chmod 775 "$SIMBL_PLUGINS_DIR"

# ensure that ScriptingAdditions is world-readable
SCRIPTING_ADDITIONS_DIR="/Library/ScriptingAdditions"
chown root:admin "$SCRIPTING_ADDITIONS_DIR"
chmod 775 "$SCRIPTING_ADDITIONS_DIR"
if [ $? != 0 ]; then
  exit 1
fi

# stop any running agent by unloading it, in case we have made changes
# to the agent that won't take effect until the application is restarted
# NOTE: this runs *as* root, but $USER is the user that launched Installer.app
# we don't want the agent running as root, nor do we want to force the user to
# logout, so we try to kill any agents and then start the new version just for
# this user.
echo "Stop SIMBL Agent"
echo su -l $USER  -c "/bin/launchctl unload -F -S Aqua \"${LAUNCHD_PLIST}\""
su -l $USER -c "/bin/launchctl unload -F -S Aqua \"${LAUNCHD_PLIST}\""

# This clears out any buggy instance we may have started with previous versions
# of the package.
echo "Stop root SIMBL Agent"
/bin/launchctl unload -F -S Aqua "${LAUNCHD_PLIST}"

# If there are other users, kill the current agents - launchd will restart
# them with the newly installed code
/usr/bin/killall "SIMBL Agent"

echo "Start SIMBL Agent"
echo su -l $USER -c "/bin/launchctl load -F -S Aqua \"${LAUNCHD_PLIST}\""
su -l $USER -c "/bin/launchctl load -F -S Aqua \"${LAUNCHD_PLIST}\""
if [ $? != 0 ]; then
  exit 1
fi

# Under 10.6, the Leopard-compatible OSAX event causes a spurious entry in the
# console. This is harmless and the warning is completely pointless, the event
# won't ever be triggered on Snow Leopard. Equally pointless are the complaints
# about this. If one reads the output of the Console, the least one can do is
# be prepared to understand the statements made there.
sw_vers | grep "ProductVersion:.*10\.6"
if [ $? == 0 ]; then
  echo "pruning Leopard event handler"
  /usr/libexec/PlistBuddy -c "Delete :OSAXHandlers:Events:SIMeleop" "$OSAX_PLIST"
fi