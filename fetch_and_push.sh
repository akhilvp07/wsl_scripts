#!/bin/bash

REPO_BASE_PATH="${HOME}/git/pri_bare/" # Set the base path of the repos
LOG_FILE_PATH="${HOME}/logs/" # Set the directory to which log files needs to be stored
REPO_PATH_E30="${REPO_BASE_PATH}e30.git" # Set the e30 repo path here
REPO_PATH_EVCLIENT="${REPO_BASE_PATH}ev-client.git"  # Set the ev-client repo path here
REPO_PATH_TRAFFIC="${REPO_BASE_PATH}traffic.git"   # Set the traffic repo path here
REPO_PATH_2900DSP="${REPO_BASE_PATH}e2900dsp.git"   # Set the e2900dsp repo path here
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

# Fetches the latest changes from the remote repository for a given repository path and logs the results.
#
# Parameters:
#   - REPO_PATH: The path to the repository.
#   - LOG_FILE: The path to the log file.
function fetch_repo() {
    REPO_PATH=$1
    LOG_FILE=$2
    # Fetch the last success time from file
    last_success > /dev/null 2>&1
    {
        # Go to repo
        cd "$REPO_PATH"
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
# Check if the logs directory exists
if [ ! -d "$LOG_FILE_PATH" ]; then
  # Create the logs directory
  mkdir -p "$LOG_FILE_PATH" || { echo "Error: Unable to create logs directory '$LOG_FILE_PATH'. Exiting." >&2; exit 1; }
fi

for REPO_PATH in "$REPO_PATH_E30" "$REPO_PATH_EVCLIENT" "$REPO_PATH_TRAFFIC" "$REPO_PATH_2900DSP"; do

    # Extract the base name of the repository from REPO_PATH
    BASE_REPO_NAME="${REPO_PATH//*\//}"
    # Create the log file path
    LOG_FILE="${LOG_FILE_PATH}${BASE_REPO_NAME}.log"
    # Create the log file if it doesn't exist
    touch "$LOG_FILE"

    # Fetch the latest changes from the remote repository and log the results
    fetch_repo "$REPO_PATH" "$LOG_FILE" &
done
