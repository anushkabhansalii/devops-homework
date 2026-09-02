#!/bin/bash
# Runs sysinfo.sh with sample input and writes README.md with the real output.
# Usage: ./generate_readme.sh
cd "$(dirname "$0")"
chmod +x sysinfo.sh

OUTPUT=$(printf "demo_dir\nprocesses.txt\n" | ./sysinfo.sh 2>&1)
FILE_HEAD=$(head -n 15 demo_dir/processes.txt 2>/dev/null)

cat > README.md <<EOF
# Shell Scripting Homework - System Information Script

**Name:** Anushka Jain
**Script:** [\`sysinfo.sh\`](./sysinfo.sh)

## What the script does

| Requirement | How it is done |
|---|---|
| Print current date | \`date\` stored in \`CURRENT_DATE\` |
| Print hostname | \`hostname\` stored in \`HOST_NAME\` |
| Print username | \`whoami\` stored in \`USER_NAME\` |
| Print disk usage | \`df -h\` stored in \`DISK_USAGE\` |
| Print running processes | \`ps aux\` stored in \`PROCESSES\` |
| Use variables | all values above are stored in variables and reused |
| Take user input | \`read -p\` for directory name and file name |
| Create a directory | \`mkdir -p "\$DIR_NAME"\` |
| Create a file | \`touch "\$DIR_NAME/\$FILE_NAME"\` |
| Store processes in file | \`echo "\$PROCESSES" > "\$DIR_NAME/\$FILE_NAME"\` |

## Script

\`\`\`bash
$(cat sysinfo.sh)
\`\`\`

## How to run

\`\`\`bash
chmod +x sysinfo.sh
./sysinfo.sh
\`\`\`

## Output

Input given: directory \`demo_dir\`, file \`processes.txt\`

\`\`\`text
$OUTPUT
\`\`\`

## Contents of the created file (first 15 lines)

\`\`\`bash
head -n 15 demo_dir/processes.txt
\`\`\`

\`\`\`text
$FILE_HEAD
\`\`\`

## Commands used

- \`mkdir\` - create directory
- \`touch\` - create empty file
- \`echo\` - print text / variables
- \`df -h\` - disk usage in human readable form
- \`ps aux\` - list running processes
- \`read -p\` - prompt for user input
- Variables (\`VAR=\$(command)\`) - store command output
- \`>\` - redirect output to a file (overwrites)
EOF

echo "README.md generated. Check it and push."
