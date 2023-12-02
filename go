#!/bin/bash

#################################################
# Created by: NitrateOrigins                    #
# GitHub: https://www.github.com/NitrateOrigins #
# Created for: The Templex Server               #
# GitHub: https://www.github.com/TemplexMC      #
# Thanks for using my script!                   #
#################################################

echo -e "Starting up..."

# Check for empty input
if [ -z "$1" ]; then
    1=?
    exit
fi

# Function to echo usage and exit
echo_usage_and_exit() {
    echo -e "$1"
    echo -e "$2"
    exit
}

case "$1" in
    "i")
        echo -e "Installing..."
        mkdir -p ~/bin
        echo -e "Making directory..."

        cd ~/bin || exit
        curl -o "go" "https://raw.githubusercontent.com/PlasHost/public-scripts/master/go"
        echo -e "Cloning go command..."

        chmod +x "go"
        echo -e "Parsing as script..."

        echo -e "\nalias go='~/bin/go'" >> ~/.bashrc
        echo -e "Installing to .bashrc..."
        ;;

    "uz")
        [ -z "$2" ] && echo_usage_and_exit "You need to specify a string!" "Usage: go un <file>"
        echo "Unzipping '$2'..."
        tar -xvf "$2"
        echo "Done unzipping..."
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
        [ -z "$2" ] && echo_usage_and_exit "You need to specify a port!" "Usage: go $1 <port>"
        echo -e "Killing port $2..."
        sudo kill -9 "$(sudo lsof -t -i :$2)"
        echo -e "Killed port $2."
        ;;

    "b")
        [ -z "$2" ] && echo_usage_and_exit "You need to specify a file!" "Usage: go b <file name>"
        echo -e "Bashing..."
        chmod 777 "$2"
        echo -e "Bashed."
        ;;

    "up")
        echo -e "Updating..."
        sudo apt update
        sudo apt upgrade
        echo -e "Updated."
        ;;

    "--")
        echo -e "Upgrading..."
        sudo apt update && sudo apt upgrade -y
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
        nano "${2:-$HOME/bin/go}"
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
