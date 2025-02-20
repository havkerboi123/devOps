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
    "IMAP_SERVER"
    "IMAP_PORT"
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

# Convert paths to Windows format for Git
REPO_PATH_GIT=$(echo "$REPO_PATH" | sed 's/\//\\/g')
MONITOR_PATH_GIT=$(echo "$MONITOR_PATH" | sed 's/\//\\/g')

# Check if repository exists
if [[ ! -d "${REPO_PATH}/.git" ]]; then
    echo "Error: ${REPO_PATH} is not a Git repository!"
    rm -f "$LOCK_FILE"
    exit 1
fi

# Function to send email notification using PowerShell (Gmail IMAP)
send_email() {
    local email_body="Changes were detected in ${MONITOR_PATH} and have been committed to Git."
    local email_subject="File Monitor: Changes Detected"
    
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "
    try {
        # Load required assemblies
        Add-Type -AssemblyName System.Net.Mail
        
        # Create mail message
        \$mail = New-Object System.Net.Mail.MailMessage
        \$mail.From = '$GMAIL_USER'
        foreach(\$recipient in ('$COLLABORATORS' -split ',')) {
            \$mail.To.Add(\$recipient.Trim())
        }
        \$mail.Subject = '$email_subject'
        \$mail.Body = '$email_body'
        
        # Create IMAP client
        \$client = New-Object System.Net.Mail.SmtpClient('$IMAP_SERVER', $IMAP_PORT)
        \$client.EnableSsl = \$true
        \$client.Credentials = New-Object System.Net.NetworkCredential('$GMAIL_USER', '$GMAIL_PASSWORD')
        
        # Send mail
        \$client.Send(\$mail)
        Write-Output 'Email sent successfully'
        
    } catch {
        Write-Output \"Error sending email: \$_\"
        exit 1
    }
    "
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

    NEW_HASH=$(sha256sum "${MONITOR_PATH}" | awk '{print $1}')
    
    if [[ "$NEW_HASH" != "$LAST_HASH" ]]; then
        echo "Change detected in ${MONITOR_PATH}..."
        
        if ! cd "${REPO_PATH}"; then
            echo "Error: Unable to change to repository directory!"
            rm -f "$LOCK_FILE"
            exit 1
        fi
        
        # Changed file using relative path
        RELATIVE_PATH=$(realpath --relative-to="${REPO_PATH}" "${MONITOR_PATH}")
        
        if git add "${RELATIVE_PATH}" && \
           git add "config.cfg" && \
           git add "monitor_and_push.sh" && \
           git commit -m "Auto-commit: Changes detected in ${MONITOR_PATH}" && \
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