# Shell Scripting Homework - System Information Script

**Name:** Anushka Jain
**Script:** [`sysinfo.sh`](./sysinfo.sh)

## What the script does

| Requirement | How it is done |
|---|---|
| Print current date | `date` stored in `CURRENT_DATE` |
| Print hostname | `hostname` stored in `HOST_NAME` |
| Print username | `whoami` stored in `USER_NAME` |
| Print disk usage | `df -h` stored in `DISK_USAGE` |
| Print running processes | `ps aux` stored in `PROCESSES` |
| Use variables | all values above are stored in variables and reused |
| Take user input | `read -p` for directory name and file name |
| Create a directory | `mkdir -p "$DIR_NAME"` |
| Create a file | `touch "$DIR_NAME/$FILE_NAME"` |
| Store processes in file | `echo "$PROCESSES" > "$DIR_NAME/$FILE_NAME"` |

## Script

```bash
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
```

## How to run

```bash
chmod +x sysinfo.sh
./sysinfo.sh
```

## Output

Input given: directory `demo_dir`, file `processes.txt`

```text
===== SYSTEM INFORMATION =====
Date       : Wed Sep  2 21:49:46 IST 2026
Hostname   : Anushkas-MacBook-Air-2.local
Username   : anushka

===== DISK USAGE =====
Filesystem                                         Size    Used   Avail Capacity iused ifree %iused  Mounted on
/dev/disk3s1s1                                    228Gi    12Gi    13Gi    47%    459k  139M    0%   /
devfs                                             203Ki   203Ki     0Bi   100%     702     0  100%   /dev
/dev/disk3s6                                      228Gi   3.0Gi    13Gi    19%       3  139M    0%   /System/Volumes/VM
/dev/disk3s2                                      228Gi   8.5Gi    13Gi    39%    1.5k  139M    0%   /System/Volumes/Preboot
/dev/disk3s4                                      228Gi   3.1Mi    13Gi     1%      64  139M    0%   /System/Volumes/Update
/dev/disk1s2                                      500Mi   6.0Mi   482Mi     2%       1  4.9M    0%   /System/Volumes/xarts
/dev/disk1s1                                      500Mi   6.0Mi   482Mi     2%      32  4.9M    0%   /System/Volumes/iSCPreboot
/dev/disk1s3                                      500Mi   1.4Mi   482Mi     1%      94  4.9M    0%   /System/Volumes/Hardware
/dev/disk3s5                                      228Gi   190Gi    13Gi    94%    2.0M  139M    1%   /System/Volumes/Data
map auto_home                                       0Bi     0Bi     0Bi   100%       0     0     -   /System/Volumes/Data/home
/Users/anushka/Downloads/Visual Studio Code.app   228Gi   190Gi    14Gi    94%    2.0M  144M    1%   /private/var/folders/c5/zg2s2lhx2hjf6tsqny99s68w0000gn/T/AppTranslocation/21956C0D-8B6A-49A6-B3C7-12523C15C3D2

===== RUNNING PROCESSES (top 10) =====
USER               PID  %CPU %MEM      VSZ    RSS   TT  STAT STARTED      TIME COMMAND
root             10375  39.1  0.2 435358592  36448   ??  Ss   11:48AM   0:00.39 /System/Library/PrivateFrameworks/XprotectFramework.framework/Versions/A/XPCServices/XprotectService.xpc/Contents/MacOS/XprotectService
_windowserver      400   4.7  0.6 436679968  95936   ??  Ss    8:36AM  81:54.12 /System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer -daemon
root               449   3.8  0.1 435459584  19104   ??  Ss    8:36AM   0:49.20 /usr/libexec/syspolicyd
anushka           2169   3.4  1.3 441021920 218512   ??  S     9:03AM  15:20.32 /Users/anushka/Library/Application Support/Claude/claude-code/2.1.247/claude.app/Contents/MacOS/claude --output-format stream-json --verbose --input-format stream-json --effort high --model claude-sonnet-5 --permission-prompt-tool stdio --resume=be200a86-84e3-4418-88f1-e6d137993a82 --allowedTools mcp__computer-use,mcp__ccd_session__spawn_task,mcp__ccd_session__dismiss_task,mcp__ccd_session__mark_chapter,mcp__ccd_session_mgmt__list_sessions,mcp__ccd_session_mgmt__get_session,mcp__ccd_session_mgmt__set_session_title,mcp__ccd_session_mgmt__send_message,mcp__ccd_session_mgmt__search_session_transcripts,mcp__ccd_session_mgmt__list_events,mcp__ccd_session__read_widget_context,mcp__claude-in-chrome__request_credentials,mcp__claude-in-chrome__list_granted_credentials,mcp__claude-in-chrome__autofill_credential,mcp__claude-in-chrome__release_credentials,mcp__claude-in-chrome__enter_verification_code --setting-sources=user,project,local --permission-mode auto --include-partial-messages --plugin-dir /Users/anushka/Library/Application Support/Claude/local-agent-mode-sessions/1ee3f45f-bf8a-456a-a4a9-b2393f3f08b9/fb5f9af3-af2f-4f97-82c7-c50c7fa5e30b/rpm/plugin_014WxCYbLf7f3uw2isHFR9US --plugin-dir /Users/anushka/Library/Application Support/Claude/local-agent-mode-sessions/1ee3f45f-bf8a-456a-a4a9-b2393f3f08b9/fb5f9af3-af2f-4f97-82c7-c50c7fa5e30b/rpm/plugin_01Eeb9y5m4iFuY3yRtytYfdc --plugin-dir /Users/anushka/Library/Application Support/Claude/local-agent-mode-sessions/1ee3f45f-bf8a-456a-a4a9-b2393f3f08b9/fb5f9af3-af2f-4f97-82c7-c50c7fa5e30b/rpm/plugin_01FTLa86dhbVJ3HB1LdHdhN7 --plugin-dir /Users/anushka/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin/fb5f9af3-af2f-4f97-82c7-c50c7fa5e30b/1ee3f45f-bf8a-456a-a4a9-b2393f3f08b9 --thinking-display omitted --replay-user-messages --settings {}
anushka           1297   1.3  1.0 486910560 163328   ??  S     8:41AM   4:01.44 /Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Versions/152.0.7977.64/Helpers/Google Chrome Helper.app/Contents/MacOS/Google Chrome Helper --type=utility --utility-sub-type=network.mojom.NetworkService --lang=en-GB --service-sandbox-type=network --metrics-client-id=0e6749ac-e2ba-4b29-a78c-683200e7d62d --shared-files --metrics-shmem-handle=1752395122,r,15370385979725046606,4309569405869997183,524288 --field-trial-handle=1718379636,r,6106430361258405496,10073011264616045684,262144 --variations-seed-version=20260901-010028.732000-production --pseudonymization-salt-handle=1935764596,r,1487169044525358186,9428115348189638450,4 --trace-process-track-uuid=3190708989122997041 --seatbelt-client=30
anushka           1211   1.2  2.3 437225872 378400   ??  S     8:38AM  16:57.12 /Applications/WhatsApp.app/Contents/MacOS/WhatsApp
anushka           7583   1.0  0.3 1949338832  49488   ??  S    10:03AM   8:10.92 /Applications/Claude.app/Contents/Frameworks/Claude Helper (Renderer).app/Contents/MacOS/Claude Helper (Renderer) --type=renderer --user-data-dir=/Users/anushka/Library/Application Support/Claude --standard-schemes=cowork-artifact,cowork-file,claude-media,claude-simulator,app --secure-schemes=cowork-artifact,cowork-file,claude-media,claude-simulator,app,sentry-ipc --bypasscsp-schemes=claude-media,claude-simulator,sentry-ipc --cors-schemes=claude-simulator,sentry-ipc --fetch-schemes=cowork-artifact,cowork-file,claude-simulator,app,sentry-ipc --service-worker-schemes=app --streaming-schemes=cowork-file,claude-media,claude-simulator --app-path=/Applications/Claude.app/Contents/Resources/app.asar --enable-sandbox --lang=en-GB --num-raster-threads=4 --enable-zero-copy --enable-gpu-memory-buffer-compositor-resources --enable-main-frame-before-activation --renderer-client-id=17 --time-ticks-at-unix-epoch=-1788318357767431 --launch-time-ticks=5172135469 --shared-files --field-trial-handle=1718379636,r,11951362510521127651,14463997264899890326,262144 --enable-features=DocumentPolicyIncludeJSCallStacksInCrashReports,IsolatesPriorityUseProcessPriority,PdfUseShowSaveFilePicker,ScreenCaptureKitPickerScreen,ScreenCaptureKitStreamPickerSonoma --disable-features=DropInputEventsWhilePaintHolding,LocalNetworkAccessChecks,ScreenAIOCREnabled,SpareRendererForSitePerProcess,TimeoutHangingVideoCaptureStarts,TraceSiteInstanceGetProcessCreation --variations-seed-version --pseudonymization-salt-handle=1935764596,r,14614719602869083708,5900124124638853152,4 --trace-process-track-uuid=3190709002241582927 --seatbelt-client=135
anushka          15257   0.9  0.5 1892199200  78336   ??  S     9:46PM   0:00.83 /private/var/folders/c5/zg2s2lhx2hjf6tsqny99s68w0000gn/T/AppTranslocation/21956C0D-8B6A-49A6-B3C7-12523C15C3D2/d/Visual Studio Code.app/Contents/Frameworks/Code Helper.app/Contents/MacOS/Code Helper --type=utility --utility-sub-type=node.mojom.NodeService --lang=en-GB --service-sandbox-type=none --user-data-dir=/Users/anushka/Library/Application Support/Code --standard-schemes=vscode-webview,vscode-file --enable-sandbox --secure-schemes=vscode-webview,vscode-file --cors-schemes=vscode-webview,vscode-file --fetch-schemes=vscode-webview,vscode-file --service-worker-schemes=vscode-webview --code-cache-schemes=vscode-webview,vscode-file --shared-files --field-trial-handle=1718379636,r,16454131410183554806,13490650154090571374,262144 --enable-features=DocumentPolicyIncludeJSCallStacksInCrashReports,EarlyEstablishGpuChannel,EstablishGpuChannelAsync,ScreenCaptureKitPickerScreen,ScreenCaptureKitStreamPickerSonoma --disable-features=CalculateNativeWinOcclusion,FontationsLinuxSystemFonts,MacWebContentsOcclusion,ScreenAIOCREnabled,SpareRendererForSitePerProcess,TimeoutHangingVideoCaptureStarts --variations-seed-version
anushka          14885   0.9  1.4 1892649760 227376   ??  S     9:46PM   0:05.60 /private/var/folders/c5/zg2s2lhx2hjf6tsqny99s68w0000gn/T/AppTranslocation/21956C0D-8B6A-49A6-B3C7-12523C15C3D2/d/Visual Studio Code.app/Contents/MacOS/Electron


Directory 'demo_dir' created.
File 'demo_dir/processes.txt' created.
Running process info saved to demo_dir/processes.txt
Lines written:      590
```

## Contents of the created file (first 15 lines)

```bash
head -n 15 demo_dir/processes.txt
```

```text
USER               PID  %CPU %MEM      VSZ    RSS   TT  STAT STARTED      TIME COMMAND
root             10375  39.1  0.2 435358592  36448   ??  Ss   11:48AM   0:00.39 /System/Library/PrivateFrameworks/XprotectFramework.framework/Versions/A/XPCServices/XprotectService.xpc/Contents/MacOS/XprotectService
_windowserver      400   4.7  0.6 436679968  95936   ??  Ss    8:36AM  81:54.12 /System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer -daemon
root               449   3.8  0.1 435459584  19104   ??  Ss    8:36AM   0:49.20 /usr/libexec/syspolicyd
anushka           2169   3.4  1.3 441021920 218512   ??  S     9:03AM  15:20.32 /Users/anushka/Library/Application Support/Claude/claude-code/2.1.247/claude.app/Contents/MacOS/claude --output-format stream-json --verbose --input-format stream-json --effort high --model claude-sonnet-5 --permission-prompt-tool stdio --resume=be200a86-84e3-4418-88f1-e6d137993a82 --allowedTools mcp__computer-use,mcp__ccd_session__spawn_task,mcp__ccd_session__dismiss_task,mcp__ccd_session__mark_chapter,mcp__ccd_session_mgmt__list_sessions,mcp__ccd_session_mgmt__get_session,mcp__ccd_session_mgmt__set_session_title,mcp__ccd_session_mgmt__send_message,mcp__ccd_session_mgmt__search_session_transcripts,mcp__ccd_session_mgmt__list_events,mcp__ccd_session__read_widget_context,mcp__claude-in-chrome__request_credentials,mcp__claude-in-chrome__list_granted_credentials,mcp__claude-in-chrome__autofill_credential,mcp__claude-in-chrome__release_credentials,mcp__claude-in-chrome__enter_verification_code --setting-sources=user,project,local --permission-mode auto --include-partial-messages --plugin-dir /Users/anushka/Library/Application Support/Claude/local-agent-mode-sessions/1ee3f45f-bf8a-456a-a4a9-b2393f3f08b9/fb5f9af3-af2f-4f97-82c7-c50c7fa5e30b/rpm/plugin_014WxCYbLf7f3uw2isHFR9US --plugin-dir /Users/anushka/Library/Application Support/Claude/local-agent-mode-sessions/1ee3f45f-bf8a-456a-a4a9-b2393f3f08b9/fb5f9af3-af2f-4f97-82c7-c50c7fa5e30b/rpm/plugin_01Eeb9y5m4iFuY3yRtytYfdc --plugin-dir /Users/anushka/Library/Application Support/Claude/local-agent-mode-sessions/1ee3f45f-bf8a-456a-a4a9-b2393f3f08b9/fb5f9af3-af2f-4f97-82c7-c50c7fa5e30b/rpm/plugin_01FTLa86dhbVJ3HB1LdHdhN7 --plugin-dir /Users/anushka/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin/fb5f9af3-af2f-4f97-82c7-c50c7fa5e30b/1ee3f45f-bf8a-456a-a4a9-b2393f3f08b9 --thinking-display omitted --replay-user-messages --settings {}
anushka           1297   1.3  1.0 486910560 163328   ??  S     8:41AM   4:01.44 /Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Versions/152.0.7977.64/Helpers/Google Chrome Helper.app/Contents/MacOS/Google Chrome Helper --type=utility --utility-sub-type=network.mojom.NetworkService --lang=en-GB --service-sandbox-type=network --metrics-client-id=0e6749ac-e2ba-4b29-a78c-683200e7d62d --shared-files --metrics-shmem-handle=1752395122,r,15370385979725046606,4309569405869997183,524288 --field-trial-handle=1718379636,r,6106430361258405496,10073011264616045684,262144 --variations-seed-version=20260901-010028.732000-production --pseudonymization-salt-handle=1935764596,r,1487169044525358186,9428115348189638450,4 --trace-process-track-uuid=3190708989122997041 --seatbelt-client=30
anushka           1211   1.2  2.3 437225872 378400   ??  S     8:38AM  16:57.12 /Applications/WhatsApp.app/Contents/MacOS/WhatsApp
anushka           7583   1.0  0.3 1949338832  49488   ??  S    10:03AM   8:10.92 /Applications/Claude.app/Contents/Frameworks/Claude Helper (Renderer).app/Contents/MacOS/Claude Helper (Renderer) --type=renderer --user-data-dir=/Users/anushka/Library/Application Support/Claude --standard-schemes=cowork-artifact,cowork-file,claude-media,claude-simulator,app --secure-schemes=cowork-artifact,cowork-file,claude-media,claude-simulator,app,sentry-ipc --bypasscsp-schemes=claude-media,claude-simulator,sentry-ipc --cors-schemes=claude-simulator,sentry-ipc --fetch-schemes=cowork-artifact,cowork-file,claude-simulator,app,sentry-ipc --service-worker-schemes=app --streaming-schemes=cowork-file,claude-media,claude-simulator --app-path=/Applications/Claude.app/Contents/Resources/app.asar --enable-sandbox --lang=en-GB --num-raster-threads=4 --enable-zero-copy --enable-gpu-memory-buffer-compositor-resources --enable-main-frame-before-activation --renderer-client-id=17 --time-ticks-at-unix-epoch=-1788318357767431 --launch-time-ticks=5172135469 --shared-files --field-trial-handle=1718379636,r,11951362510521127651,14463997264899890326,262144 --enable-features=DocumentPolicyIncludeJSCallStacksInCrashReports,IsolatesPriorityUseProcessPriority,PdfUseShowSaveFilePicker,ScreenCaptureKitPickerScreen,ScreenCaptureKitStreamPickerSonoma --disable-features=DropInputEventsWhilePaintHolding,LocalNetworkAccessChecks,ScreenAIOCREnabled,SpareRendererForSitePerProcess,TimeoutHangingVideoCaptureStarts,TraceSiteInstanceGetProcessCreation --variations-seed-version --pseudonymization-salt-handle=1935764596,r,14614719602869083708,5900124124638853152,4 --trace-process-track-uuid=3190709002241582927 --seatbelt-client=135
anushka          15257   0.9  0.5 1892199200  78336   ??  S     9:46PM   0:00.83 /private/var/folders/c5/zg2s2lhx2hjf6tsqny99s68w0000gn/T/AppTranslocation/21956C0D-8B6A-49A6-B3C7-12523C15C3D2/d/Visual Studio Code.app/Contents/Frameworks/Code Helper.app/Contents/MacOS/Code Helper --type=utility --utility-sub-type=node.mojom.NodeService --lang=en-GB --service-sandbox-type=none --user-data-dir=/Users/anushka/Library/Application Support/Code --standard-schemes=vscode-webview,vscode-file --enable-sandbox --secure-schemes=vscode-webview,vscode-file --cors-schemes=vscode-webview,vscode-file --fetch-schemes=vscode-webview,vscode-file --service-worker-schemes=vscode-webview --code-cache-schemes=vscode-webview,vscode-file --shared-files --field-trial-handle=1718379636,r,16454131410183554806,13490650154090571374,262144 --enable-features=DocumentPolicyIncludeJSCallStacksInCrashReports,EarlyEstablishGpuChannel,EstablishGpuChannelAsync,ScreenCaptureKitPickerScreen,ScreenCaptureKitStreamPickerSonoma --disable-features=CalculateNativeWinOcclusion,FontationsLinuxSystemFonts,MacWebContentsOcclusion,ScreenAIOCREnabled,SpareRendererForSitePerProcess,TimeoutHangingVideoCaptureStarts --variations-seed-version
anushka          14885   0.9  1.4 1892649760 227376   ??  S     9:46PM   0:05.60 /private/var/folders/c5/zg2s2lhx2hjf6tsqny99s68w0000gn/T/AppTranslocation/21956C0D-8B6A-49A6-B3C7-12523C15C3D2/d/Visual Studio Code.app/Contents/MacOS/Electron
_trustd            412   0.8  0.1 435369808   9056   ??  Ss    8:36AM   0:19.74 /usr/libexec/trustd
root               367   0.6  0.0 435370368   8112   ??  Ss    8:36AM   0:00.10 /usr/libexec/xprotectd
anushka           1289   0.5  2.7 537452720 454880   ??  S     8:41AM  11:06.74 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome
anushka          16864   0.4  2.0 1895739360 327440   ??  S     9:46PM   0:07.97 /private/var/folders/c5/zg2s2lhx2hjf6tsqny99s68w0000gn/T/AppTranslocation/21956C0D-8B6A-49A6-B3C7-12523C15C3D2/d/Visual Studio Code.app/Contents/Frameworks/Code Helper (Renderer).app/Contents/MacOS/Code Helper (Renderer) --type=renderer --user-data-dir=/Users/anushka/Library/Application Support/Code --standard-schemes=vscode-webview,vscode-file --enable-sandbox --secure-schemes=vscode-webview,vscode-file --cors-schemes=vscode-webview,vscode-file --fetch-schemes=vscode-webview,vscode-file --service-worker-schemes=vscode-webview --code-cache-schemes=vscode-webview,vscode-file --app-path=/private/var/folders/c5/zg2s2lhx2hjf6tsqny99s68w0000gn/T/AppTranslocation/21956C0D-8B6A-49A6-B3C7-12523C15C3D2/d/Visual Studio Code.app/Contents/Resources/app --enable-sandbox --enable-blink-features=HighlightAPI --disable-blink-features=FontMatchingCTMigration,StandardizedBrowserZoom, --lang=en-GB --num-raster-threads=4 --enable-zero-copy --enable-gpu-memory-buffer-compositor-resources --enable-main-frame-before-activation --renderer-client-id=9 --time-ticks-at-unix-epoch=-1788331332555721 --launch-time-ticks=34457202638 --shared-files --field-trial-handle=1718379636,r,16454131410183554806,13490650154090571374,262144 --enable-features=DocumentPolicyIncludeJSCallStacksInCrashReports,EarlyEstablishGpuChannel,EstablishGpuChannelAsync,ScreenCaptureKitPickerScreen,ScreenCaptureKitStreamPickerSonoma --disable-features=CalculateNativeWinOcclusion,FontationsLinuxSystemFonts,MacWebContentsOcclusion,ScreenAIOCREnabled,SpareRendererForSitePerProcess,TimeoutHangingVideoCaptureStarts --variations-seed-version --vscode-window-config=vscode:21d2dedf-3e05-4479-ae0f-ceb8ee7b55c8 --seatbelt-client=96
anushka          17793   0.4  0.0 435300272   2016 s005  S+    9:49PM   0:00.01 /bin/bash ./generate_readme.sh
```

## Commands used

- `mkdir` - create directory
- `touch` - create empty file
- `echo` - print text / variables
- `df -h` - disk usage in human readable form
- `ps aux` - list running processes
- `read -p` - prompt for user input
- Variables (`VAR=$(command)`) - store command output
- `>` - redirect output to a file (overwrites)
