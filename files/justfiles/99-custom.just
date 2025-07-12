# vim: set ft=make :

alias upgrade := update

# Update system, flatpaks, and containers all at once
update:
    #!/usr/bin/bash
    SERVICE="rpm-ostreed-automatic.service"

    if systemctl is-active --quiet "$SERVICE"; then
        echo "automatic updates are currently running, use \`journalctl -fexu $SERVICE\` to see logs"
        exit 1
    fi

    # rpm-ostree used due to bootc upgrade not supporting local layered packages
    rpm-ostree upgrade

    # Updates system Flatpaks
    if flatpak remotes | grep -q system; then
        flatpak update -y
    fi

    # Update user Flatpaks
    if flatpak remotes | grep -q user; then
        flatpak update --user -y
    fi

    # Guard Brew if the user does not own brew/doesn't exist
    if [[ -O /var/home/linuxbrew/.linuxbrew/bin/brew ]]; then
        # Upgrade will run brew update if needed
        /var/home/linuxbrew/.linuxbrew/bin/brew upgrade
    fi

alias auto-update := toggle-updates

# Turn automatic updates on or off
toggle-updates ACTION="prompt":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    CURRENT_STATE="Disabled"
    if systemctl is-enabled -q rpm-ostreed-automatic.timer; then
        CURRENT_STATE="Enabled"
    fi
    OPTION={{ ACTION }}
    if [ "$OPTION" == "prompt" ]; then
        echo "Automatic updates are currently: ${bold}${CURRENT_STATE}${normal}"
        echo "Enable or Disable automatic updates?"
        OPTION=$(ugum choose Enable Disable)
    elif [ "$OPTION" == "help" ]; then
        echo "Usage: ujust toggle-updates <option>"
        echo "  <option>: Specify the quick option - 'enable' or 'disable'"
        echo "  Use 'enable' to Enable automatic updates."
        echo "  Use 'disable' to Disable automatic updates."
        exit 0
    fi
    TIMER="rpm-ostreed-automatic.timer"
    if [ "${OPTION,,}" == "enable" ]; then
        run0 systemctl enable "$TIMER"
    elif [ "${OPTION,,}" == "disable" ]; then
        run0 systemctl disable "$TIMER"
    fi

# Configure Bluetooth headset profile
configure-bluetooth-headset-profile ACTION="prompt":
    #!/usr/bin/run0 /usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    CURRENT_STATE="Enabled (Default)"
    FILE_CONF="/usr/share/ublue-os/custom/51-disable-bluetooth-headphone-profile-switch.conf"
    WIREPLUMBER_DIR="/etc/wireplumber/wireplumber.conf.d"
    WIREPLUMBER_FILE="51-disable-bluetooth-headphone-profile-switch.conf"
    if [ -f "${WIREPLUMBER_DIR}/${WIREPLUMBER_FILE}" ]; then
      CURRENT_STATE="Disabled"
    fi
    OPTION={{ ACTION }}
    if [ "$OPTION" == "prompt" ]; then
    echo "${bold}Configuring Bluetooth headset profile behavior${normal}"    
    echo "Bluetooth headset profile is currently: ${bold}${CURRENT_STATE}${normal}"
    echo 'Disabling Bluetooth headset profile can be useful if you do not use mic from Bluetooth headphones & want to avoid lower audio quality from sudden headset profile switch.'
    echo 'Enable or Disable Bluetooth headset profile? Press ESC to exit.'
    OPTION=$(ugum choose "Enable (Default)" Disable)
    elif [ "$OPTION" == "help" ]; then
      echo "Usage: just configure-bluetooth-headset-profile <option>"
      echo "  <option>: Specify the quick option - 'disable' or 'enable'"
      echo "  Use 'disable' to disable Bluetooth headset profile."
      echo "  Use 'enable' to revert to defaults."
      exit 0
    fi    
    if [ "${OPTION,,}" == "disable" ]; then
      if ! [ -f "${WIREPLUMBER_DIR}/${WIREPLUMBER_FILE}" ]; then
        mkdir -p "${WIREPLUMBER_DIR}"
        cp "${FILE_CONF}" "${WIREPLUMBER_DIR}/${WIREPLUMBER_FILE}"
        systemctl --user restart wireplumber
          echo 'Disable Bluetooth headset profile setting applied.'
      else
        printf "\e[1;31mERROR: Bluetooth headset profile is already disabled, no change is made.\e[0m\n" 1>&2
      fi  
    elif [ "$OPTION" == "Enable (Default)" ] || [ "${OPTION,,}" == "enable" ]; then
      if [ $(find "${WIREPLUMBER_DIR}" -type f | wc -l) -eq 1 ] && [ -f "${WIREPLUMBER_DIR}/${WIREPLUMBER_FILE}" ]; then
        rm -r "${WIREPLUMBER_DIR}"
        systemctl --user restart wireplumber
          echo 'Reverted setting "Bluetooth headset profile" to defaults.'
      elif [ -f "${WIREPLUMBER_DIR}/${WIREPLUMBER_FILE}" ]; then
        rm "${WIREPLUMBER_DIR}/${WIREPLUMBER_FILE}"
        systemctl --user restart wireplumber
          echo 'Reverted setting "Bluetooth headset profile" to defaults (Enabled).'
      elif [ ! -f "${WIREPLUMBER_DIR}/${WIREPLUMBER_FILE}" ]; then
        printf "\e[1;31mERROR: Bluetooth headset profile is already enabled, no change is made.\e[0m\n" 1>&2
      fi
    fi

# Enable kernel preemption (requires reboot)
set-kargs-preemption:
    #!/usr/bin/bash
    rpm-ostree kargs --append-if-missing=preempt=full
    echo "Kernel preemption enabled. Please reboot."

# Disable kernel preemption (requires reboot)
remove-kargs-preemption:
    #!/usr/bin/bash
    rpm-ostree kargs --delete-if-present="preempt=full"
    echo "Kernel preemption disabled. Please reboot."

# Set up command-not-found for Homebrew
setup-brew-not-found ACTION="":
    #!/usr/bin/env bash
    source /usr/lib/ujust/ujust.sh

    OPTION={{ ACTION }}
    if [ "$OPTION" == "help" ]; then
        echo "Usage: ujust setup-brew-not-found <option>"
        echo "  <option>: Specify the quick option to skip the prompt"
        echo "  Use 'enable' to select Enable Brew Not Found"
        echo "  Use 'disable' to select Disable Brew Not Found"
        exit 0
    elif [ "$OPTION" == "" ]; then
        echo "${bold}Brew command-not-found Setup${normal}"
        OPTION=$(Choose "Enable Brew command-not-found" "Disable Brew command-not-found")
    fi

    set -euo pipefail

    BREW_BINARY=/home/linuxbrew/.linuxbrew/bin/brew
    HOMEBREW_REPOSITORY=${HOMEBREW_REPOSITORY:-$($BREW_BINARY --repository)}
    if ! $BREW_BINARY -h > /dev/null; then
      echo "Make sure Homebrew is installed first. Check journalctl -e -u brew-setup.service"
      exit
    fi

    if [[ "${OPTION,,}" =~ ^enable ]]; then
        $BREW_BINARY tap homebrew/command-not-found
        run0 tee /etc/profile.d/brew-command-not-found.sh > /dev/null <<EOF
    # Check for interactive bash or zsh and that we haven't already been sourced
    if [[ -d /home/linuxbrew/.linuxbrew && \$- == *i* && BREW_COMMAND_NOT_FOUND != 1 ]] ; then
      HB_CNF_HANDLER="${HOMEBREW_REPOSITORY}/Library/Taps/homebrew/homebrew-command-not-found/handler.sh"
      [ -f "\$HB_CNF_HANDLER" ] && source "\$HB_CNF_HANDLER"
      export BREW_COMMAND_NOT_FOUND=1
    fi
    EOF
        # Necessary for fish since just having a script sourcing it does not work
        FISH_HANDLER="${HOMEBREW_REPOSITORY}/Library/Taps/homebrew/homebrew-command-not-found/handler.fish"

        # Only attempt to symlink if the handler exists
        if [[ -f "$FISH_HANDLER" ]]; then
          run0 ln -sf "$FISH_HANDLER" /etc/fish/conf.d/brew-cnf-handler.fish
        fi

        echo "Brew command-not-found has been ${b}${green}enabled${n}"
    fi

    if [[ "${OPTION,,}" =~ ^disable ]]; then
        $BREW_BINARY untap homebrew/command-not-found
        FILES_TO_BE_REMOVED=()
        [ -f /etc/profile.d/brew-command-not-found.sh ] && FILES_TO_BE_REMOVED+=("/etc/profile.d/brew-command-not-found.sh")
        [ -f /etc/fish/conf.d/brew-command-not-found.fish ] && FILES_TO_BE_REMOVED+=("/etc/fish/conf.d/brew-command-not-found.fish")
        run0 rm -f "${FILES_TO_BE_REMOVED[@]}"
      echo "Brew command-not-found has been ${b}${red}disabled${n}"
    fi
