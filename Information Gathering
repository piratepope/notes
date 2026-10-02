Here are structured study notes based on the lecture transcript:

---

# Lecture Notes: Passive Information Gathering (OSINT) & Reconnaissance

## 1. Introduction & Core Mindset

* **Reconnaissance Principle:** In penetration testing and security assessments, up to 70% of the effort is spent during the information-gathering phase. Thorough reconnaissance reveals attack surfaces, misconfigurations, and entry points before active testing begins.
* **Passive vs. Active Reconnaissance:**
* **Passive Reconnaissance:** Gathering information from publicly available, third-party sources without directly sending intrusive traffic to the target infrastructure (e.g., search engines, public registries, threat intelligence databases).
* **Active Reconnaissance:** Directly interacting with the target's network or systems (e.g., port scanning, vulnerability scanning, active crawling).



---

## 2. Infrastructure & Device Discovery

### **Censys**

* **Overview:** A search engine that indexes Internet-connected devices, certificates, and networks, similar to Shodan.
* **Key Features:**
* Displays open ports, active services (HTTP, HTTPS, SSH, NTP), and software versions.
* Supports **IPv6 address scanning** alongside IPv4.
* Maps IP addresses to geographical coordinates and Autonomous System Numbers (ASNs).
* Integrates with the **National Vulnerability Database (NVD)** / NIST to highlight known CVEs associated with identified software versions.


* **Search Syntax:** Supports structured queries using filters (e.g., `services.service_name: "HTTP"`, filtering by location, vendor, or port).

### **Shodan**

* **Overview:** A specialized search engine indexing publicly accessible Internet-connected devices, banners, and open services.
* **Features:**
* Banner analysis, open port detection, and identifying exposed devices (routers, servers, IoT devices).
* Professional/Enterprise features include full automated vulnerability scanning against identified IP ranges and domains.



---

## 3. Business Intelligence & Web Analytics

### **Crunchbase**

* **Purpose:** Corporate and organizational intelligence.
* **Recon Value:**
* Company structure, office locations, and employee count.
* Funding rounds, acquisitions, investments, and key executives/founders.
* Understanding the size and corporate hierarchy helps identify potential social engineering targets or third-party supply chain risks.



### **SEMrush**

* **Purpose:** Digital marketing, traffic analytics, and SEO intelligence.
* **Recon Value:**
* Estimates monthly web traffic volume and unique visitor metrics.
* Identifies top organic search keywords and competitor domains.
* Reveals popular landing pages and sub-assets that may warrant security review.



---

## 4. Email Enumeration & Credential Intelligence

### **Hunter.io**

* **Function:** Domain-based email search and pattern identification.
* **Use in Recon:** Identifies corporate email naming conventions (e.g., `first.last@company.com`) and lists associated employee names and departments found across public web pages.

### **theHarvester**

* **Function:** A command-line Python tool included in security distributions (Kali Linux).
* **Usage:** Collects emails, subdomains, employee names, open ports, and banners from various public sources (e.g., search engines, LinkedIn, DNS databases).
* **Command Syntax:**
```bash
theHarvester -d <target-domain> -l 500 -b <source>

```


*(Note: Invoked as `theHarvester` in modern distributions).*

### **Email Validation**

* Using online mail-server validation tools to verify if an email mailbox exists before relying on it during threat modeling or authorized phishing simulations.

---

## 5. Breach Monitoring & Threat Intelligence

* **Have I Been Pwned (HIBP):**
* Created by Troy Hunt. Checks if email addresses or domains appear in publicly known, verified historical data breaches.


* **Intelligence X & DeHashed:**
* Search engines and archives for leaked data, pastes, WHOIS history, and breached records.
* Highlights exposure risks caused by password reuse, infostealer malware, and third-party data compromises.


* **SOCRadar (Dark Web / Threat Intelligence):**
* Provides dark web monitoring, Indicators of Compromise (IoCs), and reports on mentions of corporate assets, leaked credentials, or infected employee devices across underground forums.



---

## 6. Frameworks & Structured Methodologies

### **OSINT Framework (`osintframework.com`)**

* A categorized directory of open-source intelligence tools organized into a decision tree:
* **Usernames & People Search:** Namechk, Spokeo, ZabaSearch.
* **Email Addresses:** Hunter.io, EmailHippo, Harvester.
* **Domain & Network:** WHOIS, DNS records, public records.
* **Dark Web & Archives:** Tor proxies, Wayback Machine (`archive.org`), onion search directories.



### **Methodology Checklists**

* Relying on established security frameworks (e.g., **OWASP Web Security Testing Guide / OWASP Top 10 Recon Checklist**):
1. Search engine discovery and Google Dorking.
2. Web server fingerprinting (e.g., using browser extensions like Wappalyzer or BuiltWith to inspect server headers and tech stacks).
3. Reviewing server metadata (`robots.txt`, `sitemap.xml`, source code comments).
4. Adapting the methodology based on target technology (e.g., cloud storage such as AWS S3 vs. on-premise infrastructure).



---

## 7. Practical Reconnaissance Workflow (Case Study: Megacorp One)

When assessing a target organization passively, follow a structured sequence:

1. **Website Examination:**
* Review copyright dates (e.g., an outdated copyright year like 2019 often hints at legacy frameworks, unpatched CMS installations, or older server software).
* Inspect page source (`Ctrl + U`) for hidden comments, commented-out links, staging paths, or API endpoints.
* Check footer links for official social media handles (LinkedIn, Twitter/X, GitHub).


2. **Technology Fingerprinting:**
* Use tools like **Wappalyzer** to identify the web server (Apache, Nginx), operating system (Linux, Windows Server), and scripting languages/frameworks in use.


3. **Personnel & Organization Mapping:**
* Map executive leadership, IT administration, and engineering staff via LinkedIn and public corporate directories.
* Search GitHub/Git repositories for employees contributing to open or company-related code repositories.


4. **Deliverable / Reporting:**
* Document all findings with clear descriptions, dates, and evidence (screenshots).
* Categorize by asset type: Network/IPs, Personnel/Emails, Technology Stack, and Identified Exposures.
