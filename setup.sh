#! /usr/bin/env bash

if ! [ "$(id -u)" = 0 ]; then
	echo "Please run this as root"
	exit 1
fi

if ps faux | grep -q AvorionServer >/dev/null 2>&1; then
	echo "Please make ensure Avorion is off and disabled"
	exit 2
fi

if ! ( cd ./root >/dev/null 2>&1 ); then
	echo "Unable to switch to root. Please make sure to run this from the project root"
	exit 1
fi

if ! [ -e working ] && ! [ -d working ]; then
	if ! mkdir working >/dev/null; then
		echo "Failed to create 'working' directory"
		exit 3
	fi
fi

if ! [ -e backup ]; then
	if ! mkdir working >/dev/null; then
		echo "Failed to create 'working' directory"
		exit 3
	fi
fi

( cd backup || exit 3 )
( cd working || exit 3 )

mv -t backup/ \
	/etc/avorioncmd-tmux.conf \
	/etc/avorionsettings.conf \
	/etc/systemd/system/avorionservers.target \
	/etc/systemd/system/avorion@.service \
	/etc/systemd/system/steamcmd.service \
	/usr/local/bin/avorion-cmd \

install -m 644 etc/avorioncmd-tmux.conf /etc/avorioncmd-tmux.conf
install -m 644 etc/avorionsettings.conf /etc/avorionsettings.conf
install -m 644 etc/systemd/system/avorionservers.target /etc/systemd/system/avorionservers.target
install -m 644 etc/systemd/system/avorion@.service /etc/systemd/system/avorion@.service
install -m 0440 etc/sudoers.d/avorion-ds9 /etc/sudoers.d/avorion-ds9
install -m 755 usr/local/bin/avorion-cmd /usr/local/bin/avorion-cmd
