

# Combined Pentest Holy Grail — Phase 1: Enumeration

This is a **combined, cross-write-up Phase 1 reference** built from the uploaded HTB write-ups.  
It is organized **strictly by port and service**, with:
- exact tools / commands
- what to look for
- notable findings / patterns
- reusable enumeration logic

---

# 1. Nmap Baseline Scanning

Use a fast full-port sweep first, then targeted service detection.

## Common full TCP scan patterns

### Linux targets
```bash
nmap -p- --min-rate 10000 <IP>
sudo nmap -p- --reason --min-rate 10000 <IP>
```

### Windows / AD targets
```bash
nmap -p- --min-rate 10000 <IP>
nmap -sT -p- --min-rate 5000 -oA nmap/alltcp <IP>
```

### Focused service/version scan
```bash
nmap -p <ports> -sCV <IP>
nmap -p <ports> -sC -sV -oA scans/tcpscripts <IP>
```

## Common things extracted from nmap across write-ups
- OS family guess from service versions:
  - Ubuntu / Debian from OpenSSH + Apache/NGINX versions
  - Windows version family from IIS / HTTPAPI / LDAP / Kerberos / SMB
- Redirect targets:
  - `academy.htb`
  - `superpass.htb`
  - `alert.htb`
  - `apocalyst.htb`
- Domain / hostname leaks:
  - from certificates
  - from LDAP banners
  - from HTTP redirects
  - from SMB / NetBIOS / CME / NetExec output
- Security controls:
  - SMB signing enabled / required
  - SMBv1 disabled
  - clock skew on AD hosts
- Unexpected / filtered / localhost-likely services:
  - `33060`, `3000`, filtered high ports, UDP-only exposure

---

# 2. FTP / 21

## Tools
- `nmap`
- `ftp`
- `netexec ftp`

## Common commands

```bash
nmap -p 21,22,80 -sC -sV <IP>
ftp <IP>
netexec ftp <IP> -u <user> -p <pass>
```

---

## FTP Enumeration Checklist

| Check | Command | What to learn |
|---|---|---|
| Version | `nmap -sCV -p 21 <IP>` | vsftpd / Microsoft ftpd / banners |
| Anonymous access | `ftp <IP>` then username `anonymous` | read-only share, loot, backups |
| Authenticated access | `netexec ftp <IP> -u <u> -p <p>` | whether creds are valid for FTP |
| Directory listing | `ls`, `cd`, `get` | files, backups, password stores |

---

## Findings from write-ups

### Admirer
```bash
nmap -p 21,22,80 -sC -sV -oA scans/nmap-tcpscripts 10.10.10.187
```

**Findings**
- `21/tcp open ftp vsftpd 3.0.3`
- No anonymous access shown by nmap
- FTP deferred until creds found elsewhere

---

### Access
```bash
ftp 10.10.10.98
```

**Anonymous FTP worked**
```text
220 Microsoft FTP Service
331 Anonymous access allowed
230 User logged in.
```

**Loot**
- `Backups/backup.mdb`
- `Engineer/Access Control.zip`

**Takeaway**
- Anonymous FTP on Windows can be the full intended initial enumeration path
- Pull files immediately in binary mode:
```bash
bin
get backup.mdb
get "Access Control.zip"
```

---

### Administrator
```bash
netexec ftp 10.10.11.42 -u olivia -p ichliebedich
```

**Finding**
- Valid domain creds did **not** work for FTP:
```text
530 User cannot log in, home directory inaccessible.
```

**Takeaway**
- Test supplied credentials across protocols, but don’t assume cross-service validity

---

# 3. SSH / 22

## Tools
- `nmap`
- `ssh`
- `sshpass`

## Common commands

```bash
nmap -p 22 -sCV <IP>
nmap -p 22,80 -sCV <IP>
ssh <user>@<IP>
sshpass -p '<pass>' ssh <user>@<IP>
```

## What to note
- OpenSSH version for OS fingerprinting
- Host keys if needed
- Whether SSH is just post-exploitation or immediately usable with reused creds
- TTL hints for Linux / containers

---

## Representative findings

### Abducted
```bash
sudo nmap -p 22,139,445 -sCV 10.129.244.177
```
- `OpenSSH 9.6p1 Ubuntu 3ubuntu13.16`
- likely Ubuntu 24.04
- TTL 63 consistent with Linux

### Agile
```bash
nmap -p 22,80 -sCV 10.10.11.203
```
- `OpenSSH 8.9p1 Ubuntu 3ubuntu0.1`

### Academy
```bash
nmap -p 22,80,33060 -sC -sV -oA scans/tcpscripts 10.10.10.215
```
- `OpenSSH 8.2p1 Ubuntu 4ubuntu0.1`

### AI
```bash
nmap -sC -sV -p 22,80 -oA scans/nmap-tcpscripts 10.10.10.163
```
- `OpenSSH 7.6p1 Ubuntu 4ubuntu0.3`

### AirTouch
```bash
sudo nmap -p- -vvv --min-rate 10000 10.129.244.98
sudo nmap -p 22 -sCV 10.129.244.98
```
- `OpenSSH 8.2p1 Ubuntu 4ubuntu0.11`
- TTL `62` instead of expected `63` suggested container / VM layer

---

# 4. Telnet / 23

## Tools
- `nmap`
- `telnet`

## Commands
```bash
nmap -p 23 -sCV <IP>
telnet <IP>
```

---

## Antique
```bash
nmap -p 23 -sCV -oA scans/nmap-tcpscripts 10.10.11.107
telnet 10.10.11.107
```

**Findings**
- Banner leaked `HP JetDirect`
- Prompted for `Password:`
- Manual password guess `admin` failed

**Takeaway**
- Telnet service banners on appliance/printer-like targets often identify vendor stack directly
- If TCP gives almost nothing, switch to **UDP scan** immediately

---

## Access
```bash
nmap -sV -sC -p 21,23,80 -oA nmap/scripts 10.10.10.98
```

**Finding**
- `23/tcp open telnet?`

**Takeaway**
- Even when banner detection is weak, telnet can still become the operative access method later after credential recovery

---

# 5. HTTP / 80

## Tools
- `nmap`
- browser
- `curl`
- `gobuster`
- `feroxbuster`
- `ffuf`
- `wfuzz`
- `wpscan`

## Core commands

### Simple inspection
```bash
curl http://<IP>/
curl -I http://<IP>/
```

### Directory brute force
```bash
gobuster dir -u http://<host> -w /usr/share/wordlists/dirbuster/directory-list-2.3-small.txt -x php
gobuster dir -u http://<host> -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -x asp,aspx,txt
feroxbuster -u http://<host> -x php
feroxbuster -u http://<host> --dont-extract-links
```

### VHost / subdomain fuzzing
```bash
ffuf -u http://<IP> -H "Host: FUZZ.<domain>" -w /opt/SecLists/Discovery/DNS/subdomains-top1million-20000.txt -mc all -ac
wfuzz -u https://<IP> -H "Host: FUZZ.<domain>" -w /usr/share/seclists/Discovery/DNS/bitquark-subdomains-top100000.txt --hh <size>
```

### WordPress enumeration
```bash
wpscan --url http://<host>/ -e ap,t,tt,u --api-token $WPSCAN_API
```

---

## Common HTTP Enumeration Patterns

| Pattern | Indicator | Action |
|---|---|---|
| Redirect to hostname | `Did not follow redirect to http://host/` | Add to `/etc/hosts` |
| Default framework 404 | Flask, Laravel, Apache, IIS, ASP.NET | Infer stack |
| Source leaks hostname/domain | image refs, links, forms, comments | add hosts entry |
| URL patterns leak language/framework | `.php`, `.asp`, `.aspx`, `/login`, `/reset`, `index.php?page=` | tailor attacks |
| Header leaks | `Apache`, `nginx`, `IIS`, `HTTPAPI`, `ARR/3.0`, `ASP.NET` | infer stack/load balancer |
| VHost behavior | Host-header dependent redirects | fuzz subdomains |
| Error size patterns | multiple 200s same size | use `wfuzz --hh`, `--hc` |

---

## Box-specific HTTP enumeration highlights

### Agile / 80
```bash
nmap -p 22,80 -sCV 10.10.11.203
feroxbuster -u http://superpass.htb --dont-extract-links
```

**Findings**
- Redirect to `superpass.htb`
- `nginx 1.18.0`
- Flask-like default 404 behavior
- Site is a password manager
- `feroxbuster` found nothing beyond visible routes

**Takeaways**
- Response behavior can identify Flask even without explicit header disclosure
- Export/download workflows should be watched in Burp, even if not visible in browser bar

---

### Academy / 80
```bash
gobuster dir -u http://academy.htb -w /usr/share/wordlists/dirbuster/directory-list-2.3-small.txt -x php -t 40
```

**Findings**
- Redirect to `academy.htb`
- `Apache 2.4.41`
- Interesting paths:
  - `/index.php`
  - `/register.php`
  - `/admin.php`
  - `/login.php`
  - `/config.php`
  - `/home.php`
- `/admin.php` was especially important

**Takeaways**
- PHP extension brute forcing was necessary
- Registration + admin portal split is a common web-app logic flaw pattern

---

### AI / 80
```bash
gobuster -u http://10.10.10.163 -w /usr/share/wordlists/dirbuster/directory-list-lowercase-2.3-small.txt -x php,txt
```

**Findings**
- `Apache 2.4.29`
- Paths:
  - `/about.php`
  - `/contact.php`
  - `/db.php`
  - `/intelligence.php`
  - `/ai.php`
  - `/uploads`
- `/intelligence.php` explained input method
- `/ai.php` accepted WAV files
- `/db.php` blank page likely include-only

**Takeaway**
- Functional workflow pages are often revealed by brute force even when the main page is barren

---

### Aero / 80
```bash
feroxbuster -u http://10.10.11.237 -w /opt/SecLists/Discovery/Web-Content/raft-medium-directories-lowercase.txt
```

**Findings**
- `Microsoft-IIS/10.0`
- `X-Powered-By: ARR/3.0`
- Upload form accepted `.theme` / `.themepack`
- `/home` existed and mapped to main page
- blank 404s
- no obvious extension leakage

**Takeaways**
- ARR indicates IIS Application Request Routing / proxying
- Case-insensitive wordlists are smart against IIS

---

### Alert / 80
```bash
ffuf -u http://10.10.11.44 -H "Host: FUZZ.alert.htb" -w /opt/SecLists/Discovery/DNS/subdomains-top1million-20000.txt -mc all -ac
feroxbuster -u http://alert.htb -x php
```

**Findings**
- Redirect to `alert.htb`
- filtered port `12227/tcp`
- discovered subdomain: `statistics.alert.htb`
- PHP URL style:
  - `/index.php?page=alert`
  - `/index.php?page=contact`
  - `/visualizer.php`
- Markdown viewer workflow
- admin reviews contact messages implied by content

**Takeaways**
- Host-header fuzzing was essential
- Content on “About Us” page can reveal operational behavior for later phishing / XSS

---

### Admirer / 80
```bash
curl http://10.10.10.187/robots.txt
gobuster dir -u http://10.10.10.187 -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -x php -t 20
gobuster dir -u http://10.10.10.187/admin-dir -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -x php,txt,zip,html -t 20
```

**Findings**
- `Apache 2.4.25`
- `robots.txt` disclosed:
  - `/admin-dir`
  - username hint `waldo`
- brute force on `/admin-dir` found:
  - `/contacts.txt`
  - `/credentials.txt`

**Takeaways**
- Never ignore `robots.txt`
- Brute force nested paths discovered from hints
- Add multiple extensions when the hint strongly suggests files rather than directories

---

### Altered / 80
```bash
feroxbuster -u http://10.10.11.159 -x php
```

**Findings**
- `nginx 1.18.0`
- login page
- username enumeration via error message differences
- Laravel indicators:
  - `laravel_session`
  - `XSRF-TOKEN`
- paths:
  - `/login`
  - `/reset`
  - `/index.php/login`
  - `/test`

**Takeaways**
- Cookies and redirect patterns can identify Laravel
- Login/reset flow is often more valuable than blind brute forcing

---

### AdmirerToo / 80
```bash
feroxbuster -u http://10.10.11.137 -x php
```

**Findings**
- `Apache 2.4.38`
- main page `index.php`
- 404 page leaked `webmaster@admirer-gallery.htb`
- many `/manual/*` hits from Apache docs
- domain inferred: `admirer-gallery.htb`

**Takeaways**
- 404 pages can leak domains/emails
- Filter out noisy default/manual directories mentally

---

### Access / 80
```bash
gobuster -u http://10.10.10.98 -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -t 20 -x asp,aspx,txt
```

**Findings**
- `Microsoft IIS 7.5`
- no interesting web content
- just an image page

**Takeaway**
- If web enum is dead, pivot early to other services

---

### Ambassador / 80
```bash
nmap -p 22,80,3000,3306 -sCV 10.10.11.183
```

**Findings**
- `Apache 2.4.41`
- `http-generator: Hugo 0.94.2`
- title: `Ambassador Development Server`

**Takeaway**
- HTTP/80 may just be a landing page while the real app is on another port (here, `3000`)

---

### Apocalyst / 80
```bash
wpscan --url http://apocalyst.htb/ -e ap,t,tt,u --api-token $WPSCAN_API
gobuster dir -u http://apocalyst.htb -w /usr/share/wordlists/dirbuster/directory-list-2.3-small.txt -x php
wfuzz -u http://apocalyst.htb/FUZZ/ -w /usr/share/wordlists/dirbuster/directory-list-2.3-small.txt
wfuzz -u http://apocalyst.htb/FUZZ/ -w /usr/share/wordlists/dirbuster/directory-list-2.3-small.txt --hh 157 --hc 404 -t 40
```

**Findings**
- `WordPress 4.8`
- domain required: `apocalyst.htb`
- author: `falaraki`
- many 301s; brute force required response-size filtering
- non-obvious content directories hidden behind same-sized responses

**Takeaways**
- WordPress almost always deserves `wpscan`
- When directory brute force is noisy, use response length filtering with `wfuzz`

---

# 6. HTTPS / 443

## Tools
- `nmap`
- browser
- `wfuzz`
- certificate inspection

## Commands
```bash
nmap -p 443 -sCV <IP>
wfuzz -u https://<IP> -H "Host: FUZZ.<domain>" -w <wordlist> --hh <size>
```

## What to extract
- CN / SAN from cert
- clock skew
- HTTPAPI vs IIS vs reverse-proxy behavior
- VHosts

---

## Anubis / 443
```bash
nmap -p 135,443,445,593 -sCV -oA scans/nmap-tcpscripts 10.10.11.102
crackmapexec smb 10.10.11.102
wfuzz -u https://10.10.11.102 -H "Host: FUZZ.windcorp.htb" -w /usr/share/seclists/Discovery/DNS/bitquark-subdomains-top100000.txt --hh 315
```

**Findings**
- `Microsoft HTTPAPI httpd 2.0`
- TLS cert CN/SAN: `www.windcorp.htb`
- clock skew ~ `+1h03m`
- SMB hostname/domain:
  - host `EARTH`
  - domain `windcorp.htb`
- VHost fuzz only found `www`

**Takeaways**
- TLS certs are often the first clean domain leak on Windows
- Record clock skew early if Kerberos/cert abuse may matter later

---

## Acute / 443
```bash
nmap -p 443 -sCV 10.10.11.145
feroxbuster -u https://atsserver.acute.local/ -x aspx -k -w /usr/share/seclists/Discovery/Web-Content/raft-medium-directories-lowercase.txt
```

**Findings**
- `Microsoft HTTPAPI httpd 2.0`
- cert CN/SAN:
  - `atsserver.acute.local`
  - `atsserver`
- `acute.local` / `atsserver.acute.local` were key
- `Server: Microsoft-IIS/10.0`
- `X-Powered-By: ASP.NET`
- downloaded `New_Starter_CheckList_v7.docx`

**Takeaways**
- A single HTTPS service can still hide an entire Windows attack surface
- Docs/downloadables are prime loot sources

---

# 7. SMB / 139 / 445

## Tools
- `nmap`
- `netexec` / `crackmapexec`
- `smbclient`
- `smbmap`
- `enum4linux`
- `rpcclient`

## Core commands
```bash
netexec smb <IP>
netexec smb <IP> --shares
netexec smb <IP> -u <user> -p '<pass>' --shares
crackmapexec smb <IP>
smbclient -L //<IP>/ -N
smbclient //<IP>/<share> -U ""%""
smbmap -H <IP>
smbmap -H <IP> -R
enum4linux -a <IP>
rpcclient -N <IP> -U ""
```

---

## What to extract
- Hostname / domain
- SMB signing required/not required
- SMBv1 enabled/disabled
- Null / guest auth
- Share names and permissions
- RPC-enumerable users / printers / share paths

---

## Abducted SMB notes
```bash
netexec smb 10.129.244.177
smbclient -L //10.129.244.177/ -N
rpcclient -N 10.129.244.177 -U ""
```

**Findings**
- Workgroup host, not AD
- `Null Auth: True`
- `Guest Auth: True`
- guest share listing broken in `netexec`, but works in `smbclient`
- shares:
  - `HP-Reception`
  - `projects`
  - `transfer`
  - `IPC$`
- RPC gave:
  - user `scott`
  - share paths
  - printer presence

**Takeaways**
- If `netexec` fails weirdly, verify with `smbclient`
- Printer shares are exploitable attack surface, not just noise

---

## Anubis SMB notes
```bash
crackmapexec smb 10.10.11.102
smbclient -N -L //10.10.11.102
```

**Findings**
- Host: `EARTH`
- Domain: `windcorp.htb`
- SMB signing required
- null session technically possible but no shares visible

---

## Administrator SMB notes
```bash
netexec smb 10.10.11.42 --generate-hosts-file /etc/hosts
netexec smb 10.10.11.42 -u olivia -p ichliebedich
```

**Findings**
- Host: `DC`
- Domain: `administrator.htb`
- Windows Server 2022 Build 20348
- creds valid over SMB

---

## Active SMB notes
```bash
enum4linux -a 10.10.10.100
smbmap -H 10.10.10.100
smbclient //10.10.10.100/Replication -U ""%""
```

**Key Findings**
- accessible share without auth:
  - `Replication` = `READ ONLY`
- other interesting shares:
  - `NETLOGON`
  - `SYSVOL`
  - `Users`
- later path:
  - `Policies/.../Groups.xml`

**Takeaways**
- On AD boxes, unauthenticated share access to `Replication` / `SYSVOL` is highly valuable
- `smbmap` output is cleaner than `enum4linux` for permissions

---

# 8. RPC / MSRPC / ncacn_http

## Tools
- `nmap`
- `rpcclient`

## Commands
```bash
rpcclient -N <IP> -U ""
enumdomusers
querydispinfo
getdompwinfo
netshareenumall
enumprinters
srvinfo
```

## Where it mattered
- **Abducted**
  - user enumeration
  - share path discovery
  - printer existence
- **Windows DC boxes**
  - mostly identified by nmap as part of the AD service stack

**Takeaway**
- On Samba/non-AD SMB targets, `rpcclient` can reveal more than expected anonymously

---

# 9. SNMP / UDP 161

## Tools
- `nmap -sU`
- `onesixtyone`
- `snmpwalk`
- Python for manual decoding
- `udpx`
- `masscan` (UDP comparison only)

## Commands
```bash
sudo nmap -sU --top-ports 10 -sV <IP>
sudo nmap -sU -sC --min-rate 10000 <IP>
onesixtyone -c /opt/SecLists/Discovery/SNMP/snmp.txt <IP>
snmpwalk -v 2c -c public <IP>
snmpwalk -v 2c -c public <IP> <OID>
udpx -t <IP>
```

---

## Antique SNMP notes
```bash
sudo nmap -sU --top-ports 10 -sV 10.10.11.107
snmpwalk -v 2c -c public 10.10.11.107
snmpwalk -v 2c -c public 10.10.11.107 .1.3.6.1.4.1.11.2.3.9.1.1.13.0
```

**Findings**
- SNMPv1 server with community `public`
- custom OID leaked encoded password bytes
- manual Python decoding suggested:
  - `P@ssw0rd@123!!123`

**Takeaways**
- Printer SNMP MIBs can directly leak credentials
- Vendor-specific OIDs matter

---

## AirTouch SNMP notes
```bash
sudo nmap -sU -sC --min-rate 10000 10.129.244.98
sudo masscan -pU:1-65535 --rate 1000 10.129.244.98
udpx -t 10.129.244.98
onesixtyone -c /opt/SecLists/Discovery/SNMP/snmp.txt 10.129.244.98
snmpwalk -v 2c -c public 10.129.244.98
```

**Findings**
- `snmp-sysdescr` disclosed:
  ```text
  The default consultant password is: RxBlZhLmOkacNWScmZ6D
  ```
- community string found as `public`
- SNMP was the only meaningful UDP service

**Takeaways**
- Nmap NSE on SNMP can hand you creds directly
- `udpx` can outperform generic UDP scanning for quick protocol-aware discovery

---

# 10. LDAP / Kerberos / AD Service Stack

## Tools
- `nmap`
- `netexec`
- later: `BloodHound`, `ldapsearch`, `kerbrute` etc. (not fully covered in this Phase 1 response unless visible in early recon)

## Ports
- `53`, `88`, `389`, `445`, `464`, `636`, `3268`, `3269`, `5985`, `9389`, `47001`

## Common indicators
- Domain from LDAP banner:
  - `absolute.htb`
  - `administrator.htb`
  - `active.htb`
  - `analysis.htb`
- Hostnames from certs / SMB:
  - `dc.absolute.htb`
  - `DC`
- Kerberos server time and clock skew
- LDAP + SMB + WinRM combination = DC / AD host

---

## Absolute
```bash
nmap -sCV -p 53,80,88,135,139,389,445,464,593,636,3268,3269,5985,9389 10.10.11.181
```

**Findings**
- Classic DC surface
- `Microsoft IIS 10.0`
- LDAP domain leak: `absolute.htb`
- cert CN: `dc.absolute.htb`
- risky method: `TRACE`
- huge clock skew: `+6h59m59s`

---

## Administrator
```bash
nmap -p 21,53,88,135,139,389,445,464,593,636,3268,3269,5985,9389 -sCV 10.10.11.42
netexec smb 10.10.11.42 --generate-hosts-file /etc/hosts
```

**Findings**
- DC service stack
- domain: `administrator.htb`
- SMB signing required
- WinRM open
- initial provided creds valid on SMB/WinRM

---

## Active
```bash
nmap -sV -sC -p 53,88,135,139,389,445,464,593,636,3268,3269,5722,9389,47001,49152-49158,49169,49170,49179 --min-rate 5000 -oA nmap/scripts 10.10.10.100
```

**Findings**
- Windows Server 2008 R2 DC
- domain: `active.htb`
- signing enabled and required
- NBSTAT leaked hostname `DC`

---

## Analysis
```bash
nmap -p- --min-rate 10000 10.10.11.250
nmap -p 53,80,88,135,139,389,445,464,593,636,3268,3269,3306,5985,9389,33060,47001,... -sCV 10.10.11.250
```

**Findings**
- large AD/DC-like service stack
- domain leak: `analysis.htb`
- MySQL exposed too
- HTTPAPI on port 80

---

# 11. MySQL / MySQLX / 3306 / 33060

## Tools
- `nmap`
- later DB clients if creds found

## Commands
```bash
nmap -p 3306,33060 -sCV <IP>
```

## Where relevant

### Academy / 33060
- `33060/tcp open mysqlx?`
- weird but MySQL-related
- clue only, not immediate target

### Ambassador / 3306
- `3306/tcp open mysql`
- `mysql-info` script gave:
  - MySQL `8.0.30`
  - auth plugin `caching_sha2_password`

### Analysis / 3306 / 33060
- `3306/tcp open mysql MySQL (unauthorized)`
- `33060/tcp open mysqlx`

**Takeaway**
- Don’t ignore `33060`; it often implies MySQL X Protocol exposure

---

# 12. Grafana / 3000

## Ambassador / 3000
```bash
nmap -p 22,80,3000,3306 -sCV 10.10.11.183
```

**Findings**
- HTTP service redirecting to `/login`
- response characteristics strongly matched Grafana
- cookie `redirect_to`
- separate app from Apache/80 landing page

**Takeaway**
- Alternate HTTP ports often carry the real attack surface

---

# 13. DNS / 53

## Tools
- `nmap`
- sometimes `dnsenum` / future tooling

## Findings across write-ups
- On DCs, `53/tcp` exposed and often fingerprinted
- Example:
  - `Microsoft DNS 6.1.7600` on Active
  - `Simple DNS Plus` on Administrator
  - generic `domain?` on Absolute / Analysis

**Takeaway**
- DNS on Windows hosts often confirms DC role more than it provides direct attack path in early enum

---

# 14. WinRM / 5985 / 47001

## Tools
- `nmap`
- `netexec winrm`

## Commands
```bash
netexec winrm <IP> -u <user> -p <pass>
```

## Representative findings

### Administrator
```bash
netexec winrm 10.10.11.42 -u olivia -p ichliebedich
```

**Finding**
```text
administrator.htb\olivia:ichliebedich (Pwn3d!)
```

**Takeaway**
- Always spray supplied creds at WinRM on Windows hosts

---

# 15. NetBIOS / 139

## Tools
- `nmap`
- `nmblookup`

## Commands
```bash
nmblookup -A <IP>
```

## Abducted
- leaked `ABDUCTED`
- workgroup `WORKGROUP`
- file server service present

## Active
- NBSTAT in nmap revealed hostname `DC`

**Takeaway**
- NetBIOS still helps distinguish standalone SMB host vs AD/DC quickly

---

# 16. UDP Enumeration Strategy Notes

Several write-ups reinforced this:

## Use-case guidance
- `nmap -sU` is slow and noisy
- use top ports first:
```bash
sudo nmap -sU --top-ports 10 -sV <IP>
```
- use protocol-aware scanners when available:
```bash
udpx -t <IP>
onesixtyone -c <community_list> <IP>
```
- compare with masscan for speed, but masscan may miss application-layer UDP nuance:
```bash
sudo masscan -pU:1-65535 --rate 1000 <IP>
```

**Best examples**
- Antique → SNMP
- AirTouch → SNMP

---

# 17. Enumeration Heuristics Consolidated

## Domain / Hostname Discovery Sources
1. HTTP redirect
2. SSL certificate CN / SAN
3. LDAP banner
4. SMB / NetExec / CME hostname/domain
5. HTML source / email addresses / links
6. 404 pages / mailto leaks
7. robots.txt
8. downloadable documents

---

## When to add to `/etc/hosts`
Add hostnames immediately if found from:
- HTTP redirect
- cert
- page source
- mailto link
- LDAP
- SMB

Examples from write-ups:
```text
academy.htb
superpass.htb
alert.htb
statistics.alert.htb
apocalyst.htb
atsserver.acute.local
acute.local
www.windcorp.htb
windcorp.htb
dc.absolute.htb
administrator.htb
```

---

## When to brute force subdomains / vhosts
Use when:
- IP redirects to a named domain
- Windows/IIS target likely hosting multiple apps
- certificate reveals one hostname but app seems incomplete

Commands used:
```bash
ffuf -u http://<IP> -H "Host: FUZZ.<domain>" -w <wordlist> -mc all -ac
wfuzz -u https://<IP> -H "Host: FUZZ.<domain>" -w <wordlist> --hh <size>
```

---

## When to use Gobuster vs Feroxbuster vs Wfuzz
- **Gobuster**
  - fast simple brute force
  - good for known extension attacks
- **Feroxbuster**
  - recursive, convenient, modern output
- **Wfuzz**
  - best when response filtering by size/lines/chars is needed

---

# 18. Fast Copy/Paste Enumeration Command Bank

## Baseline
```bash
nmap -p- --min-rate 10000 <IP>
nmap -p <interesting_ports> -sCV <IP>
```

## UDP
```bash
sudo nmap -sU --top-ports 10 -sV <IP>
sudo nmap -sU -sC --min-rate 10000 <IP>
udpx -t <IP>
onesixtyone -c /opt/SecLists/Discovery/SNMP/snmp.txt <IP>
snmpwalk -v 2c -c public <IP>
```

## SMB
```bash
netexec smb <IP>
netexec smb <IP> --shares
netexec smb <IP> -u guest -p '' --shares
smbclient -L //<IP>/ -N
smbmap -H <IP>
rpcclient -N <IP> -U ""
```

## Web
```bash
curl http://<IP>/
curl -I http://<IP>/
gobuster dir -u http://<host> -w /usr/share/wordlists/dirbuster/directory-list-2.3-small.txt -x php
feroxbuster -u http://<host> -x php
ffuf -u http://<IP> -H "Host: FUZZ.<domain>" -w /opt/SecLists/Discovery/DNS/subdomains-top1million-20000.txt -mc all -ac
wfuzz -u https://<IP> -H "Host: FUZZ.<domain>" -w /usr/share/seclists/Discovery/DNS/bitquark-subdomains-top100000.txt --hh <size>
wpscan --url http://<host>/ -e ap,t,tt,u --api-token $WPSCAN_API
```

## FTP / Telnet
```bash
ftp <IP>
telnet <IP>
netexec ftp <IP> -u <user> -p <pass>
```

---

# 19. Phase 1 Summary by Port

| Port | Service | High-Value Enumeration Outcomes Seen |
|---|---|---|
| 21 | FTP | anonymous access, backup files, zip/mdb loot |
| 22 | SSH | OS fingerprinting, later credential reuse |
| 23 | Telnet | printer appliance banner, password prompt |
| 53 | DNS | confirms DC role, domain service |
| 80 | HTTP | redirects, domains, stack ID, hidden dirs, WordPress, Laravel, upload apps |
| 88 | Kerberos | confirms AD/DC, server time |
| 135/593 | RPC | confirms Windows RPC stack |
| 139/445 | SMB | shares, host/domain, signing, null/guest auth, share perms |
| 161/udp | SNMP | direct credential leakage, printer info |
| 389/636 | LDAP | domain/hostname leak, AD confirmation |
| 443 | HTTPS | cert CN/SAN leaks, VHosts |
| 3000 | alt HTTP/Grafana | real app hidden off main site |
| 3306 | MySQL | version/auth plugin, unauthorized access clue |
| 33060 | MySQLX | auxiliary DB service clue |
| 5985/47001 | WinRM | credential validation / shell path |
| 9389 | ADWS | confirms AD environment |

---

If you want, next I can build:

# **Combined Pentest Holy Grail — Phase 2: Initial Access**

in the same style, merged across all uploaded write-ups.
