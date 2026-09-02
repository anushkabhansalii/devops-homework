#!/bin/bash
# Runs all Linux homework tasks and writes README.md with real command output.
# Run on Ubuntu/WSL/Mac. Task 2 (user creation) and Task 3 (journalctl) need Linux + sudo.
# Usage: sudo ./generate_readme.sh   (sudo needed for adduser / journalctl)
cd "$(dirname "$0")"

run() {           # run <command> -> prints "$ command" then output
  echo "\$ $*"
  eval "$@" 2>&1
  echo
}

T1=$(
  cd /tmp && rm -rf linktest && mkdir linktest && cd linktest
  run 'echo "Hello Linux" > original.txt'
  run 'ln original.txt hard_link.txt'
  run 'ln -s original.txt soft_link.txt'
  run 'ls -li'
  run 'cat hard_link.txt'
  run 'cat soft_link.txt'
  echo "# Delete original and see what happens"
  run 'rm original.txt'
  run 'ls -li'
  run 'cat hard_link.txt'
  run 'cat soft_link.txt'
  echo "# Cleanup"
  run 'rm -f hard_link.txt soft_link.txt'
  run 'ls -la'
)

T2=$(
  if command -v adduser >/dev/null 2>&1; then
    run 'sudo adduser --disabled-password --gecos "" testuser'
    run 'id testuser'
    run 'ls -ld /home/testuser'
    run 'tail -n 1 /etc/passwd'
    run 'sudo userdel -r testuser'
  else
    echo "adduser not available on this OS (run on Ubuntu)."
  fi
)

T3=$(
  if command -v journalctl >/dev/null 2>&1; then
    run 'journalctl --no-pager -n 10'
    run 'journalctl --no-pager -p err -n 5'
    run 'journalctl --no-pager -u ssh -n 10 || journalctl --no-pager -u sshd -n 10'
    run 'journalctl --no-pager -b -n 5'
    run 'journalctl --no-pager --since "1 hour ago" -n 5'
    run 'journalctl --disk-usage'
  else
    echo "journalctl not available on this OS (run on Ubuntu)."
  fi
)

T4=$(
  cd /tmp && rm -rf cheat && mkdir cheat && cd cheat
  run 'pwd'
  run 'whoami'
  run 'hostname'
  run 'uname -a'
  run 'mkdir -p projects/demo'
  run 'touch projects/demo/notes.txt'
  run 'echo "line one" > projects/demo/notes.txt'
  run 'echo "line two" >> projects/demo/notes.txt'
  run 'cat projects/demo/notes.txt'
  run 'cp projects/demo/notes.txt copy.txt'
  run 'mv copy.txt renamed.txt'
  run 'ls -la'
  run 'find . -name "*.txt"'
  run 'grep -n "two" projects/demo/notes.txt'
  run 'wc -l projects/demo/notes.txt'
  run 'head -n 1 projects/demo/notes.txt'
  run 'tail -n 1 projects/demo/notes.txt'
  run 'chmod 644 renamed.txt && ls -l renamed.txt'
  run 'df -h | head -n 5'
  run 'free -h 2>/dev/null || vm_stat | head -n 5'
  run 'ps aux | head -n 5'
  run 'top -b -n 1 2>/dev/null | head -n 8 || top -l 1 | head -n 8'
  run 'history | tail -n 3'
  run 'rm -rf projects renamed.txt && ls -la'
)

cat > README.md <<EOF
# Linux Fundamentals Homework

**Name:** Anushka Jain

All outputs below were generated on my machine by running [\`generate_readme.sh\`](./generate_readme.sh).

---

## Task 1: Soft Link vs Hard Link

### Difference

| | Hard link | Soft (symbolic) link |
|---|---|---|
| What it is | Another name pointing to the **same inode** (same data on disk) | A separate small file that stores the **path** to the target |
| Command | \`ln target linkname\` | \`ln -s target linkname\` |
| Inode number | Same as original | Different from original |
| If original is deleted | Link still works, data stays until all hard links are removed | Link becomes dangling / broken |
| Cross filesystem | Not allowed | Allowed |
| Link to directory | Not allowed (normally) | Allowed |
| Shown in \`ls -l\` | looks like a normal file, link count > 1 | starts with \`l\`, shows \`-> target\` |

### Interview answer (short)
A hard link is a second directory entry for the same inode, so both names are equally "the file". A soft link is a pointer file containing a path, like a Windows shortcut. Deleting the original breaks a soft link but not a hard link. Hard links cannot cross filesystems or point to directories; soft links can.

### Practice output

\`\`\`text
$T1
\`\`\`

Notice: \`ls -li\` shows the hard link has the **same inode number** as \`original.txt\` and link count \`2\`, while the soft link has a different inode and shows \`-> original.txt\`. After deleting the original, \`cat hard_link.txt\` still works but \`cat soft_link.txt\` fails with "No such file or directory".

---

## Task 2: adduser vs useradd

| | \`useradd\` | \`adduser\` |
|---|---|---|
| Type | Low-level binary (part of shadow-utils) | Perl script wrapper around \`useradd\` (Debian/Ubuntu) |
| Home directory | Not created unless \`-m\` is passed | Created automatically |
| Password / shell | Must set manually (\`-s /bin/bash\`, \`passwd\`) | Prompts interactively for password, full name, etc. |
| Skeleton files (\`/etc/skel\`) | Only with \`-m\` | Copied automatically |
| Availability | Every Linux distro | Debian-based (Ubuntu, Mint) |

**Preferred on Ubuntu: \`adduser\`**, because it is interactive, creates the home directory, sets the shell and copies skeleton files by default, so you don't forget any step. \`useradd\` is better for scripts where you want full control with flags.

### Creating a test user (recommended command on Ubuntu)

\`\`\`bash
sudo adduser testuser
\`\`\`

Output on my machine:

\`\`\`text
$T2
\`\`\`

---

## Task 3: journalctl

\`journalctl\` is the command to read logs collected by **systemd-journald**. It stores logs from the kernel, system services and applications in a binary journal, and lets you filter by service, time, priority or boot.

Useful commands:

| Command | Purpose |
|---|---|
| \`journalctl\` | show all logs (oldest first) |
| \`journalctl -n 20\` | last 20 lines |
| \`journalctl -f\` | follow live, like \`tail -f\` |
| \`journalctl -u ssh\` | logs for one service (unit) |
| \`journalctl -b\` | logs since current boot |
| \`journalctl -p err\` | only priority error and above |
| \`journalctl --since "1 hour ago"\` | time filter |
| \`journalctl -k\` | kernel messages |
| \`journalctl --disk-usage\` | size of the journal |

### Practice output (checking logs for the ssh service)

\`\`\`text
$T3
\`\`\`

---

## Task 4: Linux Command Cheat Sheet

| Command | Purpose | Example |
|---|---|---|
| \`pwd\` | print current directory | \`pwd\` |
| \`ls\` | list files | \`ls -la\` |
| \`cd\` | change directory | \`cd /var/log\` |
| \`mkdir\` | make directory | \`mkdir -p a/b\` |
| \`touch\` | create empty file / update timestamp | \`touch file.txt\` |
| \`cp\` | copy | \`cp a.txt b.txt\` |
| \`mv\` | move / rename | \`mv a.txt c.txt\` |
| \`rm\` | remove | \`rm -rf dir\` |
| \`cat\` | print file | \`cat file.txt\` |
| \`head\` / \`tail\` | first / last lines | \`tail -n 20 log\` |
| \`grep\` | search text | \`grep -rn "error" .\` |
| \`find\` | search files | \`find . -name "*.log"\` |
| \`wc\` | count lines/words | \`wc -l file\` |
| \`chmod\` | change permissions | \`chmod 755 script.sh\` |
| \`chown\` | change owner | \`chown user:group file\` |
| \`ps\` | list processes | \`ps aux\` |
| \`top\` / \`htop\` | live process monitor | \`top\` |
| \`kill\` | send signal to process | \`kill -9 PID\` |
| \`df\` | disk space | \`df -h\` |
| \`du\` | directory size | \`du -sh folder\` |
| \`free\` | memory usage | \`free -h\` |
| \`uname\` | system info | \`uname -a\` |
| \`whoami\` | current user | \`whoami\` |
| \`hostname\` | machine name | \`hostname\` |
| \`history\` | command history | \`history\` |
| \`ln\` | create links | \`ln -s target link\` |
| \`sudo\` | run as root | \`sudo apt update\` |
| \`apt\` | package manager (Ubuntu) | \`sudo apt install nginx\` |
| \`systemctl\` | manage services | \`systemctl status nginx\` |
| \`journalctl\` | read system logs | \`journalctl -u nginx\` |
| \`ssh\` | remote login | \`ssh user@host\` |
| \`scp\` | copy over ssh | \`scp file user@host:/tmp\` |
| \`tar\` | archive | \`tar -czvf a.tar.gz dir\` |
| \`>\` / \`>>\` | redirect (overwrite / append) | \`echo hi > f.txt\` |
| \`\|\` | pipe output to next command | \`ps aux \| grep nginx\` |

### Practice output

\`\`\`text
$T4
\`\`\`
EOF

echo "README.md generated in linux-fundamentals/. Review it and push."
