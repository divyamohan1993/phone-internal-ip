#!/data/data/com.termux/files/usr/bin/bash

SERVICE_URL="https://phoneip.your-domain.com/update"
SECRET="MyPhoneKey123"
INTERVAL=300
LOG="$HOME/update_ip.log"
PIDFILE="$HOME/.update_ip.pid"

# kill old loop if running
if [ -f "$PIDFILE" ]; then
  kill "$(cat "$PIDFILE")" 2>/dev/null && rm -f "$PIDFILE"
fi

push_ip() {
  IP=$(ifconfig 2>/dev/null \
       | grep -A1 '^wlan0:' \
       | grep -oE 'inet ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)' \
       | awk '{print $2}')
  if [ -z "$IP" ]; then
    echo "$(date) ⚠ no IP found" >> "$LOG"
    return
  fi
  echo "$(date) → posting IP $IP" >> "$LOG"
  wget -qO- --header="Content-Type: application/json" \
    --post-data "{\"key\":\"$SECRET\",\"ip\":\"$IP\"}" \
    "$SERVICE_URL" >> "$LOG" 2>&1
}

# keep executable
ochmod +x "$HOME/.termux/boot/update_ip.sh"

# run now
push_ip

# start loop
(
  while sleep "$INTERVAL"; do
    push_ip
  done
)&

# record PID & log
echo $! > "$PIDFILE"
echo "$(date) ▶ started new loop (PID $!)" >> "$LOG"