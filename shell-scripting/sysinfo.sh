#!/bin/bash
# sysinfo.sh - System Information Script
# Prints date, hostname, username, disk usage and running processes,
# takes user input, creates a directory + file, and saves the process list.

# ---- Variables ----
CURRENT_DATE=$(date)
HOST_NAME=$(hostname)
USER_NAME=$(whoami)
DISK_USAGE=$(df -h)
PROCESSES=$(ps aux)

# ---- Print system info ----
echo "===== SYSTEM INFORMATION ====="
echo "Date       : $CURRENT_DATE"
echo "Hostname   : $HOST_NAME"
echo "Username   : $USER_NAME"
echo ""
echo "===== DISK USAGE ====="
echo "$DISK_USAGE"
echo ""
echo "===== RUNNING PROCESSES (top 10) ====="
echo "$PROCESSES" | head -n 10
echo ""

# ---- Take user input ----
read -p "Enter a directory name to create: " DIR_NAME
read -p "Enter a file name to store process info: " FILE_NAME

# ---- Create directory and file ----
mkdir -p "$DIR_NAME"
touch "$DIR_NAME/$FILE_NAME"

# ---- Store running processes in the file using > redirection ----
echo "$PROCESSES" > "$DIR_NAME/$FILE_NAME"

echo ""
echo "Directory '$DIR_NAME' created."
echo "File '$DIR_NAME/$FILE_NAME' created."
echo "Running process info saved to $DIR_NAME/$FILE_NAME"
echo "Lines written: $(wc -l < "$DIR_NAME/$FILE_NAME")"
