# Session 4: Linux & Bash Scripting Fundamentals

### Course Context & Tools

* **Context:** Session 4 recap and continuation from basic command-line tools (`cut`, `sed`) to Bash scripting.
* **Target Platforms:** TryHackMe (AttackBox instance), Kali Linux, Linux terminals.
* **Languages in Cybersecurity:**
* **Bash & Python:** Industry standard for penetration testing, task automation, and exploit crafting.
* **C / C++:** Low-level development, exploit development, malware analysis.
* **C# / Java:** Application development, defensive engineering, hardening.



---

### 1. Script Architecture & Execution Lifecycle

#### The Shebang (`#!`)

Every executable Bash script begins with the shebang interpreter directive:

```bash
#!/bin/bash

```

* Instructs the kernel's program loader which interpreter binary to invoke to parse the script.
* Lines prefixed with `#` (after line 1) serve as comments and are ignored by the parser.

#### File Creation & Execution Flow

1. **Create the file:** Use a text editor (e.g., `nano hello_world.sh`).
2. **Add code:** Write the shebang line and commands (e.g., `echo "Hello World"`).
3. **Execution Methods:**
* **Direct interpreter invocation:**
```bash
bash hello_world.sh

```


*(Does not require execute permissions).*
* **Direct binary invocation:**
```bash
chmod +x hello_world.sh
./hello_world.sh

```


*(Requires execute mode `+x`; prevents `Permission denied` errors).*



---

### 2. Variables in Bash

Bash variables are loosely typed (untyped). Values are treated as strings or numbers depending on the context without explicit data type declarations.

#### Variable Types

* **Local Variables:** Accessible only within the current shell or script context.
```bash
my_var="Hesham"
echo "$my_var"

```


* **Global / Environment Variables:** Exported to child processes spawned by the current shell.
```bash
export GLOBAL_VAR="value"

```



#### Command Substitution

To store the standard output (`stdout`) of a command inside a variable, use `$()` syntax:

```bash
# Recommended standard syntax:
user=$(whoami)
echo "$user"   # Outputs current username

# Contrast with string literals:
user2='whoami'
echo "$user2"  # Outputs literal text "whoami"

```

---

### 3. Positional Parameters (Script Arguments)

Scripts accept command-line parameters dynamically at runtime:

* `$1`: First argument passed to the script.
* `$2`: Second argument passed to the script.
* `$0`: The name of the script itself.

#### Example: `args_demo.sh`

```bash
#!/bin/bash
echo "The first two arguments are: $1 and $2"

```

#### Execution:

```bash
chmod +x args_demo.sh
./args_demo.sh Joseph "Red Team"
# Output: The first two arguments are: Joseph and Red Team

```

---

### 4. Interactive User Input (`read`)

The `read` built-in accepts input from standard input (`stdin`) and assigns it to a variable dynamically.

#### Standard Prompting

```bash
#!/bin/bash
echo "Would you like to learn how to hack? (y/n)"
read answer
echo "Your answer was: $answer"

```

#### Silent Input & In-line Prompts

When capturing sensitive data (such as passwords or authentication tokens), hide the characters from the terminal display:

* `-p "prompt"`: Specifies an inline prompt string (eliminates the need for a separate `echo`).
* `-s`: Silent mode (disables terminal echo so input is not visible on screen).

```bash
#!/bin/bash
read -p "Enter username: " username
read -s -p "Enter password: " password
echo
echo "User $username authenticated."

```

---

### 5. Quick Reference & Command Cheatsheet

| Construct | Syntax | Purpose |
| --- | --- | --- |
| **Shebang** | `#!/bin/bash` | Defines the script interpreter path |
| **Make Executable** | `chmod +x <file>.sh` | Grants execution privileges to owner/group/others |
| **Direct Execution** | `./<file>.sh` | Runs script from current working directory |
| **Print Output** | `echo "text"` | Outputs text or variable evaluation to `stdout` |
| **Variable Assignment** | `VAR="value"` | Assigns value (*no spaces around `=*`) |
| **Variable Expansion** | `$VAR` or `${VAR}` | Evaluates and interpolates variable content |
| **Command Substitution** | `$(command)` | Runs command and captures its `stdout` |
| **Positional Parameters** | `$1`, `$2`, `$@` | Reads parameters passed to the script |
| **Standard Input** | `read <var>` | Captures input from user |
| **Silent Input Prompt** | `read -s -p "Prompt" <var>` | Prompts and masks input (passwords) |
