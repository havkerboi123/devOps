#!/bin/bash

# Load Configuration
if [[ ! -f "config.cfg" ]]; then
    echo "Error: config.cfg not found!"
    exit 1
fi
source config.cfg

# Validate required variables
required_vars=(
    "REPO_PATH"
    "MONITOR_PATH"
    "GIT_REMOTE"
    "GIT_BRANCH"
    "GMAIL_USER"
    "GMAIL_PASSWORD"
    "COLLABORATORS"
)

for var in "${required_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
        echo "Error: $var is not set in config.cfg"
        exit 1
    fi
done

# Variables
LAST_HASH=""
LOCK_FILE="/tmp/file_monitor.lock"

# Cleanup function
cleanup() {
    rm -f "$LOCK_FILE"
    exit 0
}
trap cleanup SIGINT SIGTERM

# Ensure only one instance is running
if [[ -f "$LOCK_FILE" ]]; then
    echo "Error: Script is already running!"
    exit 1
fi
touch "$LOCK_FILE"

# Check if repository exists
if [[ ! -d "${REPO_PATH}/.git" ]]; then
    echo "Error: ${REPO_PATH} is not a Git repository!"
    rm -f "$LOCK_FILE"
    exit 1
fi

# Function to send email notification
send_email() {
    local email_body="Changes were detected in ${MONITOR_PATH} and have been committed to Git."
    local email_subject="File Monitor: Changes Detected"
    
    osascript <<EOT
        tell application "Mail"
            set newMessage to make new outgoing message with properties {subject:"$email_subject", content:"$email_body", visible:true}
            tell newMessage
                make new to recipient at end of to recipients with properties {address:"$COLLABORATORS"}
                set sender to "$GMAIL_USER"
                send
            end tell
        end tell
EOT
}

# Monitor path
if [[ ! -f "${MONITOR_PATH}" ]]; then
    echo "Error: ${MONITOR_PATH} does not exist!"
    rm -f "$LOCK_FILE"
    exit 1
fi

echo "Starting file monitor for ${MONITOR_PATH}..."

while true; do
    if [[ ! -f "${MONITOR_PATH}" ]]; then
        echo "Error: ${MONITOR_PATH} no longer exists!"
        rm -f "$LOCK_FILE"
        exit 1
    fi

    # Using shasum for macOS compatibility
    NEW_HASH=$(shasum -a 256 "${MONITOR_PATH}" | awk '{print $1}')
    
    if [[ "$NEW_HASH" != "$LAST_HASH" ]]; then
        echo "Change detected in ${MONITOR_PATH}..."
        
        # Change to repository directory
        cd "${REPO_PATH}" || {
            echo "Error: Unable to change to repository directory!"
            rm -f "$LOCK_FILE"
            exit 1
        }
        
        # Get the file name only for Git operations
        FILE_NAME=$(basename "${MONITOR_PATH}")
        
        # Perform Git operations
        if git add "${FILE_NAME}" && \
           git add config.cfg && \
           git add main.sh && \
           git commit -m "Auto-commit: Changes detected in ${FILE_NAME}" && \
           git push "${GIT_REMOTE}" "${GIT_BRANCH}"; then
            echo "Changes pushed successfully."
            send_email
        else
            echo "Error: Git operations failed!"
            rm -f "$LOCK_FILE"
            exit 1
        fi
        
        # Hash update
        LAST_HASH="$NEW_HASH"
    fi
    
    # Wait
    sleep 5
done