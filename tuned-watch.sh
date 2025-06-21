#!/bin/bash
# /usr/local/bin/tuned-watch.sh

# Configuration file path
CONFIG_FILE=~/.config/tuned-watch.conf # Adjust path as needed for user service config

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration file '$CONFIG_FILE' not found!" >&2
    exit 1
fi

# Source the configuration file
# This will load GAME_PROCESS_PROFILES, DEFAULT_PROFILE, and POLL_INTERVAL into the script's environment
source "$CONFIG_FILE"

log_message() {
    logger -t tuned-watch "INFO: $1"
}

# Function to get the current active tuned profile
get_current_profile() {
    tuned-adm active | awk -F': ' '{print $2}'
}

# Function to find the profile associated with any running process
# Returns the profile name if found, otherwise an empty string
find_running_process_profile() {
    for process_name in "${!GAME_PROCESS_PROFILES[@]}"; do # Iterate over keys (process names)
        if pgrep -x "$process_name" > /dev/null; then
            echo "${GAME_PROCESS_PROFILES[$process_name]}" # Return the associated profile
            return 0 # Found a running process, exit
        fi
    done
    return 1 # No configured processes found running
}

# Main loop
while true; do
    CURRENT_PROFILE=$(get_current_profile)
    DESIRED_PROFILE=$(find_running_process_profile) # Get the profile for any running game/app

    if [ -n "$DESIRED_PROFILE" ]; then # Check if DESIRED_PROFILE is not empty (i.e., a process was found)
        # A configured process is running, and we know its desired profile
        if [ "$CURRENT_PROFILE" != "$DESIRED_PROFILE" ]; then
            log_message "Process associated with '$DESIRED_PROFILE' profile detected. Switching to '$DESIRED_PROFILE'."
            tuned-adm profile "$DESIRED_PROFILE"
        fi
    else
        # No configured processes are running
        if [ "$CURRENT_PROFILE" != "$DEFAULT_PROFILE" ]; then # Only switch if not already on default
            log_message "No configured processes detected. Switching back to '$DEFAULT_PROFILE' profile."
            tuned-adm profile "$DEFAULT_PROFILE"
        fi
    fi

    sleep "$POLL_INTERVAL"
done
