#!/usr/bin/env bash
# recon-orchestrator.sh - Parallel recon with load balancing + MD report
# Usage: ./recon-orchestrator.sh example.com [output_dir]

set -u
TARGET="${1:?Usage: $0 <domain> [outdir]}"
OUT="${2:-recon_${TARGET}_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$OUT/logs"

# ---- Load balancing knobs ---------------------------------------------------
MAX_CONCURRENT=3        # max tasks hitting the target simultaneously
NMAP_RATE="T2"          # timed template: T2 = polite (0.3s between packets)
NIKTO_DELAY="1"         # seconds between nikto requests
GOBUSTER_DELAY="100ms"  # gobuster per-request delay
SUBENUM_DELAY="2"       # passive subdomain tools are light; keep low

LOG() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$OUT/orchestrator.log"; }

# ---- Task definitions -------------------------------------------------------
# Each task: name -> command writing to $OUT/logs/<name>.raw and a summary to .md
declare -A TASK_CMDS=(
  [whois]="whois $TARGET"
  [dns]="dig ANY $TARGET +noall +answer; dig MX $TARGET +short; dig NS $TARGET +short; dig TXT $TARGET +short"
  [subdomains]="subfinder -d $TARGET -all -silent -timeout $SUBENUM_DELAY"
  [nmap_top1000]="nmap -$NMAP_RATE -sV --top-ports 1000 -oN - $TARGET"
  [nmap_full_slow]="nmap -$NMAP_RATE -sV -p- --max-rate 200 -oN - $TARGET"
  [web_discovery]="httpx -l $OUT/logs/subdomains.raw -title -tech-detect -status-code -rate-limit 10 -silent"
  [waf_detect]="wafw00f -a $TARGET"
  [whatweb]="whatweb -a 1 --no-errors $TARGET"
  [dir_brute]="gobuster dir -u http://$TARGET -w /usr/share/wordlists/dirb/common.txt -q -delay $GOBUSTER_DELAY -t 5"
  [osint_email]="theharvester -d $TARGET -b all -l 200"
)
# nikto is heavy: keep it out of the default batch, run manually or uncomment:
# [nikto]="nikto -h $TARGET -Delay $NIKTO_DELAY -Format htm -output $OUT/logs/nikto.html"

NAMES=(whois dns subdomains nmap_top1000 web_discovery waf_detect whatweb dir_brute osint_email nmap_full_slow)

# ---- Concurrency-balanced launcher in tmux ----------------------------------
command -v tmux >/dev/null || { echo "tmux required"; exit 1; }
SESS="recon_${TARGET//./_}"
tmux kill-session -t "$SESS" 2>/dev/null
tmux new-session -d -s "$SESS" -n orchestrator "watch -n5 'cat $OUT/orchestrator.log'"

LOG "Starting recon of $TARGET (max $MAX_CONCURRENT concurrent tasks)"

running_file="$OUT/.running"; : > "$running_file"
declare -A WINDOW_PID

launch_task() {
  local name="$1" i="$2"
  local cmd="${TASK_CMDS[$name]}"
  local win="t$(printf '%02d' $i)"
  # wrapper: wait until a slot is free, then run and record timing
  local script="while [ \$(wc -l < $running_file) -ge $MAX_CONCURRENT ]; do sleep 3; done;
    echo \$\$ >> $running_file;
    START=\$(date +%s); echo \"[$name] started \$(date)\" >> $OUT/orchestrator.log;
    { $cmd ; } > $OUT/logs/${name}.raw 2>&1; RC=\$?;
    END=\$(date +%s);
    grep -v \"^\$\$\$\" $running_file > ${running_file}.tmp && mv ${running_file}.tmp $running_file;
    echo \"[$name] finished rc=\$RC duration=\$((END-START))s\" >> $OUT/orchestrator.log;
    read -p 'Task $name done. Close window? [y]' _"
  tmux new-window -d -t "$SESS" -n "$win" "bash -c '$script'"
}

i=1
for name in "${NAMES[@]}"; do launch_task "$name" $((i++)); done

LOG "All tasks queued in tmux session '$SESS'. Attach: tmux attach -t $SESS"
LOG "Waiting for completion to build report..."

# ---- Wait for all tasks to finish -------------------------------------------
TOTAL=${#NAMES[@]}
while true; do
  done_count=$(grep -c "finished" "$OUT/orchestrator.log" 2>/dev/null || echo 0)
  LOG "progress: $done_count/$TOTAL"
  [ "$done_count" -ge "$TOTAL" ] && break
  sleep 30
done

# ---- Build Markdown report ---------------------------------------------------
REPORT="$OUT/REPORT.md"
{
  echo "# Recon Report: $TARGET"
  echo
  echo "**Generated:** $(date)  "
  echo "**Scope:** $TARGET (authorized engagement)  "
  echo "**Task count:** $TOTAL | **Concurrency cap:** $MAX_CONCURRENT"
  echo
  echo "## Task Summary"
  echo
  echo "| # | Task | Status | Duration | Output File |"
  echo "|---|------|--------|----------|-------------|"
  n=1
  for name in "${NAMES[@]}"; do
    line=$(grep "\[$name\] finished" "$OUT/orchestrator.log" | tail -1)
    dur=$(echo "$line" | grep -oP 'duration=\K[0-9]+' || echo "n/a")
    rc=$(echo "$line" | grep -oP 'rc=\K-?[0-9]+' || echo "?")
    status="OK"; [ "$rc" != "0" ] && [ "$rc" != "?" ] && status="RC=$rc"
    echo "| $n | \`$name\` | $status | ${dur}s | \`logs/${name}.raw\` |"
    n=$((n+1))
  done
  echo
  echo "## Task-wise Findings"
  echo
  for name in "${NAMES[@]}"; do
    echo "### $name"
    echo
    echo '```'
    # Truncate huge raw outputs: show first 100 + last 50 lines
    f="$OUT/logs/${name}.raw"
    if [ -s "$f" ]; then
      lines=$(wc -l < "$f")
      if [ "$lines" -gt 150 ]; then
        head -100 "$f"; echo "... [$((lines-150)) lines truncated] ..."; tail -50 "$f"
      else cat "$f"; fi
    else echo "(no output)"; fi
    echo '```'
    echo
  done
  echo "---"
  echo "*Report auto-generated by recon-orchestrator.sh. Verify findings manually before acting.*"
} > "$REPORT"

LOG "Report written: $REPORT"
echo "Done. Report: $REPORT"
