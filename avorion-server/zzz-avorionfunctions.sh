#!/bin/bash
source /etc/avorionsettings.conf

if [[ "$(groups)" =~ (^$AVORION_ADMIN_GRP | $AVORION_ADMIN_GRP | $AVORION_ADMIN_GRP$) ]] || [[ "$(id -u)" == 0 ]]; then
	function avorion-cmd () {
		command -v tmux >/dev/null 2>&1 || {
			echo "avorion-cmd requires tmux to function! Please run apt install -y tmux"
			return 1
		}
		
		if ! { [[ -z "$TMUX" ]] && [[ ! "$TERM" =~ ^(screen|tmux) ]] && [[ -z "$TMUX_PANE" ]]; }; then
			echo "This command should not be run from within a Screen/Tmux session"
		fi

		#####

		local _tmuxsess _tmuxcmd
		local _bld _clr _grn _red _wht
		_clr="$(tput sgr0)"; _bld="$(tput bold)";
		_wht="$(tput setaf 7)"; _grn="$(tput setaf 2)"
		_red="$(tput setaf 1)"; _yel="$(tput setaf 3)"

		if [[ ! "$1" =~ (help|update|validate|showinstances) ]]; then
			_tmuxsess="$2"
			_tmuxsess="${_tmuxsess//[ _]/\-}"
			_tmuxsess="${_tmuxsess//[^a-zA-Z0-9\-]/}"

			systemctl status avorion@"$_tmuxsess".service >/dev/null 2>&1 || {
				echo "$_tmuxsess is not a valid Avorion instance."
				return 1
			}
			
			_tmuxcmd="$(which tmux) -S ${AVORION_SERVICEDIR}/sockets/${_tmuxsess}.sock"
		fi

		case "$1" in 
			attach)
				"$_tmuxcmd" attach-session -t "$_tmuxsess"
				;;
			
			view)
				"$_tmuxcmd" attach-session -t "$_tmuxsess" -r
				;;
			
			exec)
				shift; shift
				"$_tmuxcmd" send-keys "$(printf '%q' "$@")" ENTER \; pipe-pane 'cat > /dev/stdout'
				;;
			
			update)
				[[ -d "/tmp/avorion/updatingavorion.lock" ]] && {
					echo "Update process already running"
					return 1
				}

				mkdir -p /tmp/avorion/updatingavorion.lock >/dev/null 2>&1 || {
					echo "Unable to create avorion lockfile! Check /tmp usage."
					return 1
				}

				_units="$(systemctl list-units 'avorion@*' | grep 'loaded active running' | awk '{print $1}')"
				
				systemctl stop 'avorion@*'
				systemctl disable 'avorion@*'

				echo "Updating Avorion"
				steamcmd '+force_install_dir' ${AVORION_SERVICEDIR}/${AVORION_BINDIR} '+app_update' $AVORION_STEAMID validate '+exit' \
					| tee "${AVORION_SERVICEDIR}/${AVORION_BINDIR}/steamupdate.log"
				
				while read _inst; do
					systemctl enable avorion@"$_inst"
					systemctl start avorion@"$_inst"
				done <<< "${_units}"

				rm -rf /tmp/avorion/updatingavorion.lock >/dev/null 2>&1 || {
					echo "Unable to remove lockfile. Please ensure that the update was finished successfully."
					return 1
				}

				return 0
				;;
			
			showinstances)
				if (( ! "$(find "${AVORION_SERVICEDIR}/sockets" -name '*.sock' | wc -l)" > 0 )); then
					echo "No service instances running"
					return 1
				fi

				printf '%s\n' \
					"${_bld}${$_wht}DeepSpace 9.875 -- Service Instances:${_clr}" \
					"Instance (Service Unit) -- Status"

				find "${AVORION_SERVICEDIR}/sockets" -name '*.sock' -printf '%f\n' | sort | while read -r _sock; do
					local _instance="${_sock%%.sock*}"
				
					if systemctl list-units avorion@* 2>&1 | grep -q "^avorion@${_instance}.service " >/dev/null 2>&1 ; then
						systemctl status avorion@"${_instance}" >/dev/null 2>&1 \
							&& echo "${_instance} (avorion@${_instance}) -- ${_grn}Online${_clr}" \
							|| echo "${_instance} (avorion@${_instance}) -- ${_red}Offline${_clr}"

					elif [[ "$_instance" =~ ^steam(cmd|cli)$ ]]; then
						systemctl status "${_instance}" >/dev/null 2>&1 \
							&& echo "${_instance} (steamcmd.service) -- ${_grn}Online${_clr}" \
							|| echo "${_instance} (steamcmd.service) -- ${_red}Offline${_clr}"

					else
						if [[ -f "/etc/systemd/system/${_instance}.service" ]]; then
							systemctl status "${_instance}" >/dev/null 2>&1 \
								&& echo "${_instance} -- ${_grn}Online${_clr}" \
								|| echo "${_instance} -- ${_red}Offline${_clr}"
						fi
					fi
				done
				;;

			backup)
				echo "TODO: Unimplemented"
				;;

			resetsector)
				echo "TODO: Unimplemented"
				;;

			help)
				echo "Usage: avorion-cmd <option> <parameters>"
				echo "Options:"
				printf '\t%s\n' \
					"update: Force a full Avorion server update. Note that this brings the server down for the duration." \
					"help: This help text"
				
				printf '\t%s\n\t\t%s\n' \
					"attach: Attach to a service instance." \
						"Example: ${_grn}avorion-cmd attach <instance>${_clr}" \
					"view: Attach to a service instance in read-only mode." \
						"Example: ${_grn}avorion-cmd view <instance>${_clr}"
				
				printf '\t%s\n\t\t%s\n\t\t%s\n' \
					"exec: Run the specified commands in the service supplied" \
						"Example: ${_grn}avorion-cmd exec <instance/service> <COMMANDS>" \
						"${_red}WARNING:${_clr} Unfinished/Untested and may be buggy, please dont use this for large Lua scripts commands until further tested." \
					"backup: Force a backup run of the given instance" \
						"Example: ${_grn}avorion-cmd backup <instance>${_clr}" \
						"${_yel}NOTICE:${_clr} Unimplemented at this time." \
					"resetsector: Reset the given sector/sectors for a server instance" \
						"Example: ${_grn}avorion-cmd resetsector <instance> x y${_clr}" \
						"${_yel}NOTICE:${_clr} Unimplemented at this time."
					
					return 0
				;;

			?)
				printf '%s\n' "Invalid argument passed: <$(printf '%q' "$1")>"
				exit
				;;
		esac
	}

	avorion-cmd showinstances
fi

