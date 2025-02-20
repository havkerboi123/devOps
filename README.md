
# Git File Monitor (DevOps assignment)

 Bash-based file monitoring script that detects changes in a specified file, commits the changes to a Git repository, pushes them to a remote branch, and notifies collaborators via email.

📌 Features

Monitors a specific file for changes.
Automatically commits and pushes changes to a Git repository.
Sends email notifications using Apple Mail (for macOS).
Prevents multiple script instances from running simultaneously.
🚀 Setup Instructions

1️⃣ Clone the Repository

git clone https://github.com/your-username/your-repo.git
cd your-repo

2️⃣ Configure config.cfg
Edit config.cfg and update the following values:

REPO_PATH="/path/to/your/repo"
MONITOR_PATH="/path/to/file/you/want/to/monitor"

# Git settings
GIT_REMOTE="origin"
GIT_BRANCH="main"

# Gmail settings (for macOS Apple Mail)
GMAIL_USER="your-email@gmail.com"
GMAIL_PASSWORD="your-app-password"
COLLABORATORS="collaborator@example.com"
💡 Note: If you're using Gmail, make sure to generate an App Password for authentication.
3️⃣ Make main.sh Executable
chmod +x main.sh
4️⃣ Run the Script
./main.sh
🛠️ Troubleshooting

If you see "Error: Git operations failed!":
Run git status to check if there are unstaged changes.
Make sure GIT_BRANCH is correct and up to date.
If emails aren’t being sent:
Ensure Apple Mail is configured properly.
Check the email settings in config.cfg.
Try running osascript commands separately to debug.
📜 License

This project is licensed under the MIT License.

