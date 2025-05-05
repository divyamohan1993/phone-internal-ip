# This is the file for ~/.termux/boot/update_ip.sh

#!/data/data/com.termux/files/usr/bin/bash

SERVICE_URL="https://phoneip-107722137045.asia-south1.run.app/update"
SECRET="0mBYWlzd2MClFt8FpAoJHO9RlvDmSHrtCATJfcZJ0Pc"
INTERVAL=300  # seconds between updates

push_ip(){
  IP=$(ip -4 addr show wlan0 2>/dev/null \
    | awk '/inet /{print $2}' | cut -d/ -f1)
  [ -z "$IP" ] && return
  curl -s -X POST "$SERVICE_URL" \
    -H "Content-Type: application/json" \
    -d "{\"key\":\"$SECRET\",\"ip\":\"$IP\"}"
}

# on boot
push_ip

# then every $INTERVAL seconds
while sleep $INTERVAL; do
  push_ip
done &