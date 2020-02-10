#!/bin/bash

# This scripts is meant to be easy-to-use
# Aimed at archives: extract zip, rar, tar, etc...
# Currently all exit statuses are set to 0
# Log file location is set to "$LOG_FILE"
# All files extrated will have full paths
#
# - - - - - - - - CAUTION!!! - - - - - - - -
#
# All progs WILL overwrite any existing files!
# Keep track of log file. Might become large
# Consider removing it

LOG_DIR=$HOME/logs # Log file not in /var/logs due to permission issues
LOG_FILE=$LOG_DIR/$(basename "$0".log)
ROOT_UID=0
#ARGS_COUNT=2 # unused yet TODO
A_NAME=$(basename "$1" | sed -r '$s/\.(zip|rar|bz2|gz|tar.gz|tar.bz2)$//I' | sed -r '$s/ //g') # Strip archive extension

trap 'logger "~~~~~~~~~~~~~~ xtract.sh stopped ~~~~~~~~~~~~~"' 1 0

logger () { # This is just output redirection for the log file
    echo -e "$@" #SC2u086
    echo -e "$(date +\|%T.\[%4N\]\|) $*" > /dev/null >> "${LOG_FILE}" 2>&1
}

spin () { # Makeshift progress indicator
# It should be used after longer processess
# e.g. extracting, converting, etc.
    i=1
    pid=$!  # get the PID of the external utility. Maybe a better way of doing this...
#             SC2181: Check exit code directly with e.g. 'if mycmd;', not $!
    sp='/-\|'  # <`~~~ these are the actual spinner chars.
    n=${#sp}
    while [[ -d /proc/$pid ]]; do   # PID directory probing
        echo -ne "\b${sp:i++%n:1}"  # Print a character then delete it inplace
        sleep 0.08
    done
    printf -- "\b\033[32mDone\033[0m"
    echo
    sleep 0.05
}

checker () { # checks if nedded program is installed
    echo "Checking installed programs"
    if command -v "$*" > /dev/null 2>&1; then
        logger "Found $*"
    else
        echo "$* not installed."
        exit 1;
    fi
}

xtract () { # main script
    case "$1" in
        *.zip )
            checker unzip
            logger "Archive info:\n$(unzip -Z -z -h -t "$1")" > /dev/null 2>&1
            logger "Checking archive integrity"
            if logger "$(unzip -t -q "$1")" > /dev/null 2>&1 & # this syntax logs and executes a command... probably a better way of doing it
            then spin; fi

            logger "Starting extraction"
            if logger "...$(unzip -o -q "$1")" > /dev/null 2>&1 &
            then spin; fi;
            ;;

        *.rar ) # Logging is too bloated
            checker unrar
            logger "Checking archive integrity"
            if logger "$(unrar t -idpdc "$1")" > /dev/null 2>&1 &
            then spin; fi
            if logger "$(unrar x -y -o+ -idpdc "$1")" > /dev/null 2>&1 &
            then spin; fi
            ;;

        *.tar | *.tar.* )
            checker tar
            logger "Starting extraction"
            if logger "...$(tar xaf "$1")" > /dev/null 2>&1 &
            then spin; fi
            ;;

        *.7z) # Again.. bloated logging
            checker 7z
            logger "Checking archive integrity"
            if logger "$(7z t -bb0 -bd "$1")" > /dev/null 2>&1 &
            then spin; fi
            logger "Starting extraction"
            if logger "$(7z x -bb0 -bd -aoa "$1")" > /dev/null 2>&1 &
            then spin; fi
            ;;

        * )
            echo "Unsupported file format"; exit 1
            ;;
    esac
    logger "Files from '$1' extracted successfuly"
}

init () { # initialization - basic checks and main script invoker

    echo >> "${LOG_FILE}"
    logger "~~~~~~~~~~~~~~ xtract.sh xecuted ~~~~~~~~~~~~~"
    if [[ -z $1 ]]; then # If no args are given display basic usage details and exit
        echo "Usage: $(basename "$0" .sh) [path-to-archive] (This will extract the file in your current directory!)"
        exit 1 # Exit if no args given
    elif [[ $UID -eq $ROOT_UID ]]; then # second check - Am I root?
        echo "This script shouldn't be run as root"
        exit 1; fi # Exit if root

    xtract "$1"
    logger "Archive size: $(du -sh "$1" | awk '{print $1}')"
    logger "Extracted size: $(du -sh "$A_NAME" | awk '{print $1}')" # if du returns error log it
    echo "Log file - ${LOG_FILE}"
}

init "$@"
