Here are your comprehensive, structured lecture notes based directly on the transcript.

---

# Lecture Notes: Active Reconnaissance & Network Scanning

## Module Overview

* **Topic:** Network Scanning & Active Information Gathering
* **Prerequisites:** Passive Information Gathering (OSINT, Search Engines, Google Dorking, Shodan, Censys, OSINT Framework).
* **Core Transition:** Moving from indirect, passive intelligence collection to direct, active packet interaction with target hosts.

---

## 1. Passive vs. Active Information Gathering

| Feature | Passive Reconnaissance | Active Reconnaissance (Scanning) |
| --- | --- | --- |
| **Direct Interaction** | None. Interacts with public third-party sources (e.g., Shodan, Google, WHOIS, BGP tables). | Direct. Sends crafted packets directly to the target system. |
| **Detectability** | Undetectable by the target. | Detectable. Generates log events, alerts Firewalls, IDSs, and SIEMs. |
| **Objective** | Gather high-level footprint, IP ranges, domains, and public exposure. | Identify live hosts, open ports, running services, OS versions, and vulnerabilities. |

> **Analogy:**
> * **Passive:** Asking neighbors, checking social media, and reading public business directories to learn about someone.
> * **Active:** Walking up to the person's house, knocking on the front door, and checking if the windows are unlocked.
> 
> 

---

## 2. The 5-Step Active Scanning Methodology

Active network reconnaissance must be executed in a strict logical order:

```
[ 1. Host Discovery ] 
          ↓
[ 2. Port Scanning ]
          ↓
[ 3. Service Enumeration ]
          ↓
[ 4. OS Fingerprinting ]
          ↓
[ 5. Vulnerability Scanning ]

```

1. **Host Discovery (Ping Sweeps / Live Checking):**
* Identify which machines on the target network are online (`UP`) vs. offline (`DOWN`).


2. **Port Scanning:**
* Scan logical network ports (0 to 65,535 for TCP and UDP) to see which ones are accessible (`open`).
* *Analogy:* Ports act like specific windows or doors into the host through which particular services communicate (e.g., Port 80 for HTTP).


3. **Service Enumeration (Banner Grabbing & Version Detection):**
* Probe open ports to determine the exact software and version handling that port (e.g., FileZilla FTP Server v3.5, Apache HTTPD 2.4.41).


4. **Operating System (OS) Fingerprinting:**
* Determine the underlying OS (Linux kernel version, Windows Server version) by examining TCP/IP stack behavior, TTL values, and packet responses.


5. **Vulnerability Scanning:**
* Correlate identified software, versions, and OS signatures against known CVEs, exploits, or default configurations to find attack vectors.



### The Attack Equation

$$\text{Attack} = \text{Goal (Motivation)} + \text{Vulnerability (Weakness)} + \text{Exploit (Method)}$$

---

## 3. Networking Fundamentals: Transport Layer & Packet Flow

### OSI Model Context (Layer 4 Focus)

* **Layer 2 (Data Link):** Uses **MAC addresses** for local, physical node-to-node delivery on the local area network (LAN).
* **Layer 3 (Network):** Uses **IP addresses** for global routing across disparate networks/the Internet.
* **Layer 4 (Transport):** Uses **Ports** and protocols (TCP/UDP) to deliver data to the intended application/service.

#### Local Addressing Evolution

* **Hub:** Broadcasts incoming data out of every single physical port; creates security risks (trivial packet sniffing) and collisions.
* **Switch:** Inspects Layer 2 frames, builds a **MAC Address Table**, and directs frames only to the designated switch port.
* **Router:** Connects separate networks, inspects Layer 3 IP headers, and routes packets toward remote destinations.

---

### TCP vs. UDP

| Metric | TCP (Transmission Control Protocol) | UDP (User Datagram Protocol) |
| --- | --- | --- |
| **Connection Model** | Connection-oriented (guaranteed delivery via acknowledgments). | Connectionless ("fire and forget", stateless). |
| **Speed vs. Reliability** | Prioritizes reliability over raw speed. | Prioritizes low latency/speed over delivery guarantees. |
| **Control Flags** | Extensive header control flags (SYN, ACK, RST, FIN, PSH, URG). | No control flags or connection handshakes. |
| **Common Use Cases** | Web (HTTP/HTTPS), File transfers (FTP, SSH), Email (SMTP). | Real-time voice/video streaming, VoIP, Online gaming, DNS queries. |

---

### Core TCP Control Flags

* **`SYN` (Synchronize):** Initiates a TCP connection.
* **`ACK` (Acknowledge):** Confirms receipt of previously transmitted packets.
* **`RST` (Reset):** Closes an abnormal connection or indicates that a port is closed / unwilling to communicate.
* **`FIN` (Finish):** Gracefully terminates an established TCP session.
* **`PSH` (Push):** Directs the receiver to push all buffered data immediately to the application layer.
* **`URG` (Urgent):** Marks the data payload as urgent, prioritizing immediate processing.

---

### The TCP Three-Way Handshake & Teardown

#### Connection Establishment

1. **Client $\to$ Server:** `SYN` (Request to synchronize/connect).
2. **Server $\to$ Client:** `SYN-ACK` (Acknowledgment of request + synchronization response).
3. **Client $\to$ Server:** `ACK` (Connection established, data transmission starts).

#### Connection Termination (Graceful Teardown)

1. **Sender $\to$ Receiver:** `FIN`
2. **Receiver $\to$ Sender:** `ACK`
3. **Receiver $\to$ Sender:** `FIN`
4. **Sender $\to$ Receiver:** `ACK`

---

## 4. Host Discovery Techniques

Techniques to check if a remote or local system is online before scanning all ports:

1. **ARP Ping Scan (Local Subnets Only):**
* Uses Address Resolution Protocol broadcast requests: *"Who has IP `x.x.x.x`? Tell `y.y.y.y`."*
* If a system replies with its hardware MAC address, the host is live.
* *Limitation:* Does not route across subnets/routers.


2. **ICMP Echo Request (Ping Sweep):**
* Sends an ICMP Type 8 (Echo Request). A live host typically returns ICMP Type 0 (Echo Reply).
* *Limitation:* Frequently blocked by modern firewalls and Windows Defender default settings.


3. **TCP SYN / ACK Ping:**
* Sends TCP control packets to common ports. If a host sends back a `SYN-ACK` (port open) or `RST` (port closed), the host is verified as live regardless of whether ICMP is blocked.



---

## 5. Port Scanning Techniques & Nmap Reference

```
                             [ Port Scanning ]
        _____________________________|_____________________________
       |                             |                             |
[ TCP Scanning ]              [ UDP Scanning ]             [ Other Scans ]
   - TCP Connect (-sT)           - UDP Scan (-sU)             - SCTP INIT (-sY)
   - TCP SYN / Stealth (-sS)                                  - SCTP COOKIE-ECHO (-sZ)
   - Xmas Scan (-sX)                                          - IPv6 Scan (-6)
   - Maimon Scan (-sM)                                        - List Scan (-sL)
   - ACK Scan (-sA)
   - Idle / Zombie (-sI)

```

---

### Detailed TCP Scan Types

#### 1. TCP Connect Scan (Full Open Scan) — `nmap -sT <target>`

* **Mechanism:** Completes the entire 3-way handshake (`SYN` $\to$ `SYN-ACK` $\to$ `ACK`), followed by an immediate `RST` to terminate.
* **Privileges:** Does **not** require raw socket/root privileges (can run as standard user).
* **Detection:** Leaves clear connection records in target application/system logs. Easily detected by Defenders/SIEMs.
* **Port States:**
* **Open:** Target replies with `SYN-ACK`.
* **Closed:** Target replies with `RST`.



#### 2. TCP SYN Scan (Stealth / Half-Open Scan) — `nmap -sS <target>`

* **Mechanism:** Sends a `SYN`. If the target responds with `SYN-ACK`, Nmap immediately sends an `RST` **without** sending the final `ACK`. The connection is never completed.
* **Privileges:** Requires **root/administrator privileges** to craft raw TCP packets.
* **Detection:** Stealthier on endpoints (often not logged by user-space applications), though network IDS/IPS can still detect the half-open pattern.
* **Port States:**
* **Open:** Target replies with `SYN-ACK`.
* **Closed:** Target replies with `RST`.



#### 3. TCP ACK Scan — `nmap -sA <target>`

* **Purpose:** **Firewall filtering detection** (maps rulesets), rather than discovering open ports.
* **Mechanism:** Sends pure `ACK` packets.
* **Port States:**
* **Unfiltered:** Target returns `RST` (indicates the packet traversed the firewall and reached the host).
* **Filtered:** No response, or an ICMP error code returned (indicates a stateful firewall blocked the packet).



#### 4. Xmas Tree Scan — `nmap -sX <target>`

* **Mechanism:** Sets the **FIN**, **PSH**, and **URG** flags simultaneously (lighting the packet up "like a Christmas tree").
* **Port States (RFC 793 compliance):**
* **Closed:** Returns an `RST`.
* **Open / Filtered:** No response received.


* *Note:* Microsoft Windows and certain network devices do not adhere to RFC 793 and may reply with `RST` even for open ports.

#### 5. Maimon Scan — `nmap -sM <target>`

* **Mechanism:** Sends combined **FIN/ACK** packets.
* **Port States:**
* **Closed:** Target returns `RST`.
* **Open / Filtered:** No response.



#### 6. TCP Idle Scan (Zombie Scan) — `nmap -sI <zombie_host> <target>`

* **Mechanism:** An advanced, blind scanning technique where the attacker spoofs packets using an idle third-party host's IP address.
* **Mechanism Detail:** Leverages predictable IP Identification (IP ID) sequence increments on an idle machine to discover open ports without revealing the attacker's true IP.

---

### UDP Scanning — `nmap -sU <target>`

* **Challenge:** UDP is connectionless and has no flags.
* **Port States:**
* **Open:** Valid service response received (or no response if service does not reply to probes).
* **Closed:** Target returns an **`ICMP Port Unreachable` (Type 3, Code 3)** packet.
* **Filtered:** Other ICMP unreachable errors (Type 3, Codes 1, 2, 9, 10, or 13).


* **Speed:** Extremely slow due to OS-level ICMP rate limiting.

---

### Specialized & Protocol-Specific Scans

* **SCTP INIT Scan (`-sY`):** Sends SCTP INIT chunks. Used for telecommunication and multimedia streaming infrastructure.
* Open = `INIT-ACK` received.
* Closed = `ABORT` chunk received.


* **SCTP COOKIE-ECHO Scan (`-sZ`):** Half-open/stealth variant for SCTP networks.
* **SSDP (Simple Service Discovery Protocol):** Used to detect Universal Plug and Play (UPnP) devices on local network segments.
* **IPv6 Scanning (`nmap -6 <target>`):** Enforces scanning against IPv6-configured hosts.

---

## 6. Nmap Syntax Reference Card

| Action | Nmap Command | Notes / Use Case |
| --- | --- | --- |
| **Host Discovery (Ping Sweep)** | `nmap -sn <target_subnet>` | Disables port scanning; checks host availability only. |
| **TCP Connect Scan** | `nmap -sT -p <ports> <target>` | Default for unprivileged users; completes full handshake. |
| **TCP SYN Scan (Stealth)** | `nmap -sS -p <ports> <target>` | Default for privileged users; sends `SYN` $\to$ receives `SYN-ACK` $\to$ sends `RST`. |
| **UDP Port Scan** | `nmap -sU -p <ports> <target>` | Scans for UDP services (e.g., DNS port 53, SNMP port 161). |
| **Firewall Mapping (ACK)** | `nmap -sA -p <ports> <target>` | Identifies filtered vs. unfiltered ports behind firewalls. |
| **Xmas Scan** | `nmap -sX -p <ports> <target>` | Sets FIN, PSH, URG flags; checks RFC 793 compliance. |
| **Maimon Scan** | `nmap -sM -p <ports> <target>` | Sets FIN, ACK flags. |
| **IPv6 Target Scan** | `nmap -6 <ipv6_address>` | Enforces IPv6 addressing mode. |
| **Port Range Definition** | `nmap -p 1-1000 <target>` | Restricts probe to specified port boundaries. |

---

## 7. Study & Practice Plan

1. **Review:**
* Revisit the TCP 3-way handshake packet flow and teardown sequence.
* Understand which responses (`SYN-ACK`, `RST`, or ICMP Port Unreachable) signify open vs. closed states for each scan type.


2. **Hands-On Practice (TryHackMe):**
* Complete the **Pre-Security Path: Network Fundamentals** module.
* Practice basic sweeps and flag setting in the dedicated **Nmap Room**.


3. **Coming Next Session:**
* Hands-on active scanning against live lab machines.
* Service version extraction (`-sV`), OS fingerprinting (`-O`), and script engine utilization (NSE).
