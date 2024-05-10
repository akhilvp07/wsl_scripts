#!/bin/bash

REPO_BASE_PATH="${HOME}/git/pri_bare/" # Set the base path of the repos
LOG_FILE_PATH="${HOME}/logs/" # Set the directory to which log files needs to be stored
SEC_PASS="Think@123" # Secondary PC's(Fedora 20 Local git server) git user password

#Change only the lines above

REMOTE="secondary"  # Set the git remote name of the secondary repo from 'git remote -v'
REPO_PATH_E30="${REPO_BASE_PATH}e30.git" 
REPO_PATH_EVCLIENT="${REPO_BASE_PATH}ev-client.git" 
REPO_PATH_TRAFFIC="${REPO_BASE_PATH}traffic.git"  
REPO_PATH_2900DSP="${REPO_BASE_PATH}e2900dsp.git"
LAST_SUCCESS=""

# List of repositories
declare -A repos=(
["e30"]="ssh://git@bitbucket.rbbn.com:7999/em/e30.git"
["ev-client"]="ssh://git@bitbucket.rbbn.com:7999/scc/ev-client.git"
["traffic"]="ssh://git@bitbucket.rbbn.com:7999/em/traffic.git"
["e2900dsp"]="ssh://git@bitbucket.rbbn.com:7999/ed/e2900dsp.git"
)

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
function clone_repo() {
    REPO_PATH=$1
    repo_name=$(basename "$REPO_PATH" .git)
    REPO_URL=${repos[$repo_name]}
    echo "Use below command to clone $repo_name repo"
    if [ ! -d "${REPO_BASE_PATH}${repo_name}.git" ]; then
        echo "git clone --bare "$REPO_URL" "$REPO_PATH""
        exit
    else
        echo "Repository $repo_name already exists locally."
    fi
}

function verify_requirements() {
    # Check if the logs directory exists
    if [ ! -d "$LOG_FILE_PATH" ]; then
        # Create the logs directory
        mkdir -p "$LOG_FILE_PATH" || { echo "Error: Unable to create logs directory '$LOG_FILE_PATH'. Exiting." >&2; exit 1; }
    fi

    # Check if sshpass is installed
    if ! command -v sshpass > /dev/null; then
        echo 'sshpass is not installed, installing it...'
        sudo apt-get install -y sshpass
    else
        echo 'sshpass is already installed'
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
        cd "$REPO_PATH" || { echo "Error: $REPO_PATH not found. Please clone the bare repo!"; clone_repo "$REPO_PATH"; exit; }
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
verify_requirements

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
