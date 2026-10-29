#!/bin/bash

#################################################
# Created by: Drak                              #
# GitHub: https://www.github.com/DrakDv         #
# Created for: PlasHost                         #
# GitHub: https://www.github.com/PlasHost       #
# Thanks for using my script!                   #
#################################################

echo -e "Starting up..."

# Check for empty input
if [ -z "$1" ]; then
    set -- "?"
fi

# Function to echo usage and exit
echo_usage_and_exit() {
    echo -e "$1"
    echo -e "$2"
    exit
}

# Detect distro family (debian = Ubuntu/Debian, rhel = Rocky/Alma/CentOS/Fedora/RHEL)
detect_distro() {
    DISTRO_ID="unknown"
    DISTRO_FAMILY="unknown"
    if [ -r /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID="$ID"
        case " $ID $ID_LIKE " in
            *" debian "* | *" ubuntu "*) DISTRO_FAMILY="debian" ;;
            *" rhel "* | *" fedora "* | *" centos "*) DISTRO_FAMILY="rhel" ;;
        esac
    fi

    if [ "$DISTRO_FAMILY" = "unknown" ]; then
        if command -v apt >/dev/null 2>&1; then
            DISTRO_FAMILY="debian"
        elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
            DISTRO_FAMILY="rhel"
        fi
    fi

    if command -v dnf >/dev/null 2>&1; then
        RHEL_PKG="dnf"
    else
        RHEL_PKG="yum"
    fi
}

# Update + upgrade system packages using the right package manager
system_upgrade() {
    case "$DISTRO_FAMILY" in
        "debian")
            sudo apt update && sudo apt upgrade -y
            ;;
        "rhel")
            sudo "$RHEL_PKG" makecache && sudo "$RHEL_PKG" upgrade -y
            ;;
        *)
            echo -e "Unsupported distro '$DISTRO_ID' (no apt, dnf or yum found)."
            exit 1
            ;;
    esac
}

detect_distro

case "$1" in
    "i")
        echo -e "Installing helpful command..."
        echo -e "Making directory..."
        mkdir -p ~/bin

        cd ~/bin || exit
        echo -e "Cloning helpful command..."
        curl -o "helpful" "https://raw.githubusercontent.com/PlasHost/public-scripts/master/helpful.sh"
        chmod +x "helpful"

        echo -e "Parsing as script..."

        echo -e "Installing to .bashrc..."
        echo -e "\nalias helpful='~/bin/helpful'" >> ~/.bashrc
        source ~/.bashrc
        echo -e "Installed! If commands do not work, run the following command:"
        echo -e ""
        echo -e "     source ~/.bashrc"
        echo -e ""
        ;;

    "u")
        echo -e "Updating helpful command..."
        echo -e "Making directory..."
        mkdir -p ~/bin

        cd ~/bin || exit
        echo -e "Cloning helpful command..."
        curl -o "helpful" "https://raw.githubusercontent.com/PlasHost/public-scripts/master/helpful.sh"
        chmod +x "helpful"

        clear
        echo -e ""
        echo -e "Updated! Note: This did not install it into your .bashrc!"
        echo -e "If you have issues with running the command, try installing it instead!"
        echo -e ""
        ;;

    "uz")
        [ -z "$2" ] && echo_usage_and_exit "You need to specify a string!" "Usage: go un <file>"
        echo "Unzipping '$2'..."
        tar -xvf "$2"
        echo "Done unzipping..."
        ;;

    "n-link")
        [ -z "$2" ] && echo_usage_and_exit "You need to specify a string!" "Usage: go n-link <nginx-file-name>"
        echo "Linking '$2'..."
        if [ "$DISTRO_FAMILY" = "rhel" ] && [ ! -d /etc/nginx/sites-enabled ]; then
            # Rocky/RHEL nginx has no sites-enabled; it loads /etc/nginx/conf.d/*.conf
            ln -s "/etc/nginx/sites-available/$2" "/etc/nginx/conf.d/${2%.conf}.conf"
        else
            ln -s "/etc/nginx/sites-available/$2" "/etc/nginx/sites-enabled/$2"
        fi
        echo "Done linking..."
        ;;

    "zi")
        [ -z "$2" ] && echo_usage_and_exit "You need to specify a string!" "Usage: go zi <name> <path/to/file>"
        [ -z "$3" ] && echo_usage_and_exit "You need to specify a path!" "Usage: go zi <name> <path/to/file>"
        echo "Zipping '$3' into '$2.tar.gz'..."
        tar -czvf "$2.tar.gz" "$3"
        echo "Done zipping..."
        ;;

    "look")
        [ -z "$2" ] && echo_usage_and_exit "You need to specify a string!" "Usage: go look <string> <file>"
        [ -z "$3" ] && echo_usage_and_exit "You need to specify a file!" "Usage: go look <string> <file>"
        echo "Looking for '$2' in '$3'..."
        grep "$2" "$3"
        echo "Done looking... Above is what I found..."
        ;;

    "f")
        [ -z "$2" ] && echo_usage_and_exit "You need to specify a time (in days)!" "Usage: go f <days> <file extension>"
        [ -z "$3" ] && echo_usage_and_exit "You need to specify a file extension!" "Usage: go f <days> <file extension>"
        echo -e "Finding and deleting files older than $2 days with extension $3..."
        find . -type f -mtime +"$2" -name "*.$3" -execdir rm -rfv '{}' \;
        ;;

    "d")
        [ -z "$2" ] && echo_usage_and_exit "You need to specify a screen!" "Usage: go d <screen>"
        echo -e "Detaching screen '$2'..."
        screen -d "$2"
        echo -e "Detached screen '$2'."
        ;;

    "tk" | "kt")
        [ -z "$2" ] && echo_usage_and_exit "You need to specify a port!" "Usage: helpful $1 <port>"
        echo -e "Killing port $2..."
        if sudo lsof -t -i :"$2" | xargs -r sudo kill -9; then
            echo -e "Killed port $2."
        else
            echo -e "Failed to kill port $2 (no processes found or permission issue)."
        fi
        ;;

    "b")
        [ -z "$2" ] && echo_usage_and_exit "You need to specify a file!" "Usage: go b <file name>"
        echo -e "Bashing..."
        chmod 777 "$2"
        echo -e "Bashed."
        ;;

    "up")
        echo -e "Updating ($DISTRO_ID)..."
        system_upgrade
        echo -e "Updated."
        ;;

    "--")
        echo -e "Upgrading ($DISTRO_ID)..."
        system_upgrade
        echo -e "Upgraded."
        ;;

    "s")
        [ -z "$2" ] && echo_usage_and_exit "You need to specify a screen name!" "Usage: go s <screen name>"
        echo -e "Starting..."
        screen -R "$2"
        clear
        echo -e "Done."
        ;;

    "e")
        echo -e "Editing..."
        nano "${2:-$HOME/bin/helpful}"
        clear
        echo -e "Done."
        ;;

    "k")
        [ -z "$2" ] && echo_usage_and_exit "You need to specify a screen name!" "Usage: go k <screen name>"
        echo -e "Killing..."
        screen -X -S "$2" kill
        echo -e "Killed. Listing screens..."
        screen -list
        echo -e "Done."
        ;;

    "?")
        echo -e "--- List of commands ---"
        echo -e "go     > Goes to the \"Main\" screen."
        echo -e "..."
        ;;

    ".")
        echo -e "Retrieving..."
        screen -list
        echo -e "Retrieved!"
        echo -e "Done."
        echo -e "Done."
        ;;

    "m")
        [ -z "$2" ] && echo_usage_and_exit "You need to specify a directory name!" "Usage: go m <name of directory>"
        echo -e "Making..."
        mkdir -p "$2"
        echo -e "Made!"
        ;;

    *)
        echo -e "Going..."
        screen -rx "$1"
        clear
        echo -e "Done."
        ;;
esac

exit
