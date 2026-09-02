# Linux Fundamentals Homework

**Name:** Anushka Jain

All outputs below were generated on my machine by running [`generate_readme.sh`](./generate_readme.sh).

---

## Task 1: Soft Link vs Hard Link

### Difference

| | Hard link | Soft (symbolic) link |
|---|---|---|
| What it is | Another name pointing to the **same inode** (same data on disk) | A separate small file that stores the **path** to the target |
| Command | `ln target linkname` | `ln -s target linkname` |
| Inode number | Same as original | Different from original |
| If original is deleted | Link still works, data stays until all hard links are removed | Link becomes dangling / broken |
| Cross filesystem | Not allowed | Allowed |
| Link to directory | Not allowed (normally) | Allowed |
| Shown in `ls -l` | looks like a normal file, link count > 1 | starts with `l`, shows `-> target` |

### Interview answer (short)
A hard link is a second directory entry for the same inode, so both names are equally "the file". A soft link is a pointer file containing a path, like a Windows shortcut. Deleting the original breaks a soft link but not a hard link. Hard links cannot cross filesystems or point to directories; soft links can.

### Practice output

```text
$ echo "Hello Linux" > original.txt

$ ln original.txt hard_link.txt

$ ln -s original.txt soft_link.txt

$ ls -li
total 8
615661 -rw-r--r-- 2 root root 12 Sep  2 17:21 hard_link.txt
615661 -rw-r--r-- 2 root root 12 Sep  2 17:21 original.txt
615710 lrwxrwxrwx 1 root root 12 Sep  2 17:21 soft_link.txt -> original.txt

$ cat hard_link.txt
Hello Linux

$ cat soft_link.txt
Hello Linux

# Delete original and see what happens
$ rm original.txt

$ ls -li
total 4
615661 -rw-r--r-- 1 root root 12 Sep  2 17:21 hard_link.txt
615710 lrwxrwxrwx 1 root root 12 Sep  2 17:21 soft_link.txt -> original.txt

$ cat hard_link.txt
Hello Linux

$ cat soft_link.txt
cat: soft_link.txt: No such file or directory

# Cleanup
$ rm -f hard_link.txt soft_link.txt

$ ls -la
total 8
drwxr-xr-x 2 root root 4096 Sep  2 17:21 .
drwxrwxrwt 1 root root 4096 Sep  2 17:21 ..
```

Notice: `ls -li` shows the hard link has the **same inode number** as `original.txt` and link count `2`, while the soft link has a different inode and shows `-> original.txt`. After deleting the original, `cat hard_link.txt` still works but `cat soft_link.txt` fails with "No such file or directory".

---

## Task 2: adduser vs useradd

| | `useradd` | `adduser` |
|---|---|---|
| Type | Low-level binary (part of shadow-utils) | Perl script wrapper around `useradd` (Debian/Ubuntu) |
| Home directory | Not created unless `-m` is passed | Created automatically |
| Password / shell | Must set manually (`-s /bin/bash`, `passwd`) | Prompts interactively for password, full name, etc. |
| Skeleton files (`/etc/skel`) | Only with `-m` | Copied automatically |
| Availability | Every Linux distro | Debian-based (Ubuntu, Mint) |

**Preferred on Ubuntu: `adduser`**, because it is interactive, creates the home directory, sets the shell and copies skeleton files by default, so you don't forget any step. `useradd` is better for scripts where you want full control with flags.

### Creating a test user (recommended command on Ubuntu)

```bash
sudo adduser testuser
```

Output on my machine:

```text
$ sudo adduser --disabled-password --gecos "" testuser
info: Adding user `testuser' ...
info: Selecting UID/GID from range 1000 to 59999 ...
info: Adding new group `testuser' (1001) ...
info: Adding new user `testuser' (1001) with group `testuser (1001)' ...
info: Creating home directory `/home/testuser' ...
info: Copying files from `/etc/skel' ...
info: Adding new user `testuser' to supplemental / extra groups `users' ...
info: Adding user `testuser' to group `users' ...

$ id testuser
uid=1001(testuser) gid=1001(testuser) groups=1001(testuser),100(users)

$ ls -ld /home/testuser
drwxr-x--- 2 testuser testuser 4096 Sep  2 17:21 /home/testuser

$ tail -n 1 /etc/passwd
testuser:x:1001:1001:,,,:/home/testuser:/bin/bash

$ sudo userdel -r testuser
userdel: testuser mail spool (/var/mail/testuser) not found
```

---

## Task 3: journalctl

`journalctl` is the command to read logs collected by **systemd-journald**. It stores logs from the kernel, system services and applications in a binary journal, and lets you filter by service, time, priority or boot.

Useful commands:

| Command | Purpose |
|---|---|
| `journalctl` | show all logs (oldest first) |
| `journalctl -n 20` | last 20 lines |
| `journalctl -f` | follow live, like `tail -f` |
| `journalctl -u ssh` | logs for one service (unit) |
| `journalctl -b` | logs since current boot |
| `journalctl -p err` | only priority error and above |
| `journalctl --since "1 hour ago"` | time filter |
| `journalctl -k` | kernel messages |
| `journalctl --disk-usage` | size of the journal |

### Practice output (checking logs for the ssh service)

Note: I ran this inside an Ubuntu 24.04 Docker container on my Mac. Containers do not run systemd-journald, so the journal is empty; on a real Ubuntu machine the same commands print the actual log lines.

```text
$ journalctl --no-pager -n 10
No journal files were found.
-- No entries --

$ journalctl --no-pager -p err -n 5
No journal files were found.
-- No entries --

$ journalctl --no-pager -u ssh -n 10 || journalctl --no-pager -u sshd -n 10
No journal files were found.
-- No entries --

$ journalctl --no-pager -b -n 5
No journal files were found.
-- No entries --

$ journalctl --no-pager --since "1 hour ago" -n 5
No journal files were found.
-- No entries --

$ journalctl --disk-usage
No journal files were found.
Archived and active journals take up 0B in the file system.
```

---

## Task 4: Linux Command Cheat Sheet

| Command | Purpose | Example |
|---|---|---|
| `pwd` | print current directory | `pwd` |
| `ls` | list files | `ls -la` |
| `cd` | change directory | `cd /var/log` |
| `mkdir` | make directory | `mkdir -p a/b` |
| `touch` | create empty file / update timestamp | `touch file.txt` |
| `cp` | copy | `cp a.txt b.txt` |
| `mv` | move / rename | `mv a.txt c.txt` |
| `rm` | remove | `rm -rf dir` |
| `cat` | print file | `cat file.txt` |
| `head` / `tail` | first / last lines | `tail -n 20 log` |
| `grep` | search text | `grep -rn "error" .` |
| `find` | search files | `find . -name "*.log"` |
| `wc` | count lines/words | `wc -l file` |
| `chmod` | change permissions | `chmod 755 script.sh` |
| `chown` | change owner | `chown user:group file` |
| `ps` | list processes | `ps aux` |
| `top` / `htop` | live process monitor | `top` |
| `kill` | send signal to process | `kill -9 PID` |
| `df` | disk space | `df -h` |
| `du` | directory size | `du -sh folder` |
| `free` | memory usage | `free -h` |
| `uname` | system info | `uname -a` |
| `whoami` | current user | `whoami` |
| `hostname` | machine name | `hostname` |
| `history` | command history | `history` |
| `ln` | create links | `ln -s target link` |
| `sudo` | run as root | `sudo apt update` |
| `apt` | package manager (Ubuntu) | `sudo apt install nginx` |
| `systemctl` | manage services | `systemctl status nginx` |
| `journalctl` | read system logs | `journalctl -u nginx` |
| `ssh` | remote login | `ssh user@host` |
| `scp` | copy over ssh | `scp file user@host:/tmp` |
| `tar` | archive | `tar -czvf a.tar.gz dir` |
| `>` / `>>` | redirect (overwrite / append) | `echo hi > f.txt` |
| `\|` | pipe output to next command | `ps aux \| grep nginx` |

### Practice output

```text
$ pwd
/tmp/cheat

$ whoami
root

$ hostname
a97340e59eaf

$ uname -a
Linux a97340e59eaf 6.12.76-linuxkit #1 SMP Wed May 13 14:27:36 UTC 2026 aarch64 aarch64 aarch64 GNU/Linux

$ mkdir -p projects/demo

$ touch projects/demo/notes.txt

$ echo "line one" > projects/demo/notes.txt

$ echo "line two" >> projects/demo/notes.txt

$ cat projects/demo/notes.txt
line one
line two

$ cp projects/demo/notes.txt copy.txt

$ mv copy.txt renamed.txt

$ ls -la
total 16
drwxr-xr-x 3 root root 4096 Sep  2 17:21 .
drwxrwxrwt 1 root root 4096 Sep  2 17:21 ..
drwxr-xr-x 3 root root 4096 Sep  2 17:21 projects
-rw-r--r-- 1 root root   18 Sep  2 17:21 renamed.txt

$ find . -name "*.txt"
./renamed.txt
./projects/demo/notes.txt

$ grep -n "two" projects/demo/notes.txt
2:line two

$ wc -l projects/demo/notes.txt
2 projects/demo/notes.txt

$ head -n 1 projects/demo/notes.txt
line one

$ tail -n 1 projects/demo/notes.txt
line two

$ chmod 644 renamed.txt && ls -l renamed.txt
-rw-r--r-- 1 root root 18 Sep  2 17:21 renamed.txt

$ df -h | head -n 5
Filesystem      Size  Used Avail Use% Mounted on
overlay         224G   27G  186G  13% /
tmpfs            64M     0   64M   0% /dev
shm              64M     0   64M   0% /dev/shm
/dev/vda1       224G   27G  186G  13% /etc/hosts

$ free -h 2>/dev/null || vm_stat | head -n 5
               total        used        free      shared  buff/cache   available
Mem:           7.8Gi       1.5Gi       2.8Gi       2.0Mi       3.6Gi       6.2Gi
Swap:          1.0Gi          0B       1.0Gi

$ ps aux | head -n 5
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         1  0.0  0.0   4036  3024 ?        Ss   17:20   0:00 bash -c apt-get update -qq && apt-get install -y -qq systemd sudo >/dev/null 2>&1; cd /root && bash -s
root      3016  0.0  0.0   4036  3072 ?        S    17:21   0:00 bash -s
root      3091  0.0  0.0   4036  2228 ?        S    17:21   0:00 bash -s
root      3113  0.0  0.0   7632  3648 ?        R    17:21   0:00 ps aux

$ top -b -n 1 2>/dev/null | head -n 8 || top -l 1 | head -n 8
top - 17:21:29 up 46 min,  0 user,  load average: 2.27, 2.03, 1.67
Tasks:   5 total,   1 running,   4 sleeping,   0 stopped,   0 zombie
%Cpu(s):  0.0 us,  1.0 sy,  0.0 ni, 99.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st 
MiB Mem :   7936.2 total,   2852.3 free,   1565.5 used,   3719.0 buff/cache     
MiB Swap:   1024.0 total,   1024.0 free,      0.0 used.   6370.7 avail Mem 

  PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND
    1 root      20   0    4036   3024   2780 S   0.0   0.0   0:00.00 bash

$ history | tail -n 3

$ rm -rf projects renamed.txt && ls -la
total 8
drwxr-xr-x 2 root root 4096 Sep  2 17:21 .
drwxrwxrwt 1 root root 4096 Sep  2 17:21 ..
```
