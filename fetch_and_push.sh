#!/bin/bash

REPO_PATH_E30="/home/akhil/git/pri_bare/e30.git" # Set the e30 repo path here
LOG_FILE_E30="/home/akhil/logs/fetch_e30.log"   # Set the e30 log file location
REPO_PATH_EVCLIENT="/home/akhil/git/pri_bare/ev-client.git"  # Set the ev-client repo path here
LOG_FILE_EVCLIENT="/home/akhil/logs/fetch_evclient.log"    # Set the ev-client log file location
REPO_PATH_TRAFFIC="/home/akhil/git/pri_bare/traffic.git"   # Set the traffic repo path here
LOG_FILE_TRAFFIC="/home/akhil/logs/fetch_traffic.log"     # Set the traffic log file location
REPO_PATH_2900DSP="/home/akhil/git/pri_bare/e2900dsp.git"   # Set the e2900dsp repo path here
LOG_FILE_2900DSP="/home/akhil/logs/fetch_e2900dsp.log"     # Set the traffic log file location
REMOTE="secondary"  # Set the git remote name from 'git remote -v'
SEC_PASS="Think@123" # Secondary PC's authentication password
LAST_SUCCESS=""

function last_success() {
    LAST_SUCCESS=$(sed -n "/Last successful fetch on/p" "$LOG_FILE" | cut -f 5- -d" ")
    if [ "$LAST_SUCCESS" = "" ]; then
        LAST_SUCCESS="--"
    fi
}

function validate_fetch() {
    RETVAL=$?
    if [ $RETVAL -ne 0 ]; then
        echo "-------------------------------------------------------------------" >> "$LOG_FILE"
        echo "Fetch origin failed!" >> "$LOG_FILE"
        echo "Last successful fetch on $LAST_SUCCESS" >> "$LOG_FILE"
        echo "-------------------------------------------------------------------" >> "$LOG_FILE"
        exit
    else
        LAST_SUCCESS=$(date)
        echo "-------------------------------------------------------------------" >> "$LOG_FILE"
        echo "Last successful fetch on $LAST_SUCCESS" >> "$LOG_FILE"
        echo "-------------------------------------------------------------------" >> "$LOG_FILE"
    fi
}

function validate_execution() {
    RETVAL=$?
    if [ $RETVAL -ne 0 ]; then
        echo "-------------------------------------------------------------------" >> "$LOG_FILE"
        echo "$1" >> "$LOG_FILE"
        echo "-------------------------------------------------------------------" >> "$LOG_FILE"
        exit
    fi
}

function fetch_repo() {
    REPO_PATH=$1
    LOG_FILE=$2
    # Fetch the last success time from file
    last_success > /dev/null 2>&1
    {
        # Go to repo
        cd "$REPO_PATH" || exit
        validate_execution "Repo $REPO_PATH not found!"
        # Fetch origin
        echo "Trying to fetch origin : $(date)"
        git fetch origin
        validate_fetch
        # Force(-f) push to secondary repo configured as remote
        echo "Pushing changes to $REMOTE"
        sshpass -p "$SEC_PASS" git push "$REMOTE" -f --all
        validate_execution "git push failed!"
    } >> "$LOG_FILE" 2>&1 &
}

# Main
fetch_repo "$REPO_PATH_E30" "$LOG_FILE_E30" &
fetch_repo "$REPO_PATH_EVCLIENT" "$LOG_FILE_EVCLIENT" &
fetch_repo "$REPO_PATH_TRAFFIC" "$LOG_FILE_TRAFFIC" &
fetch_repo "$REPO_PATH_2900DSP" "$LOG_FILE_2900DSP" &
