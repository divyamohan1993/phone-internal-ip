# phone-internal-ip

This repository contains all the steps and scripts needed to create a dynamic DNS-like service that reports your Android device's LAN IP address to a Cloudflare Worker with KV storage. The Worker persists the last-reported IP and timestamp, which can be fetched at any time with no caching.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Cloudflare Setup](#cloudflare-setup)

   * [Create KV Namespace](#create-kv-namespace)
   * [Configure Worker](#configure-worker)
   * [Bind KV & Secret](#bind-kv--secret)
   * [Define Route](#define-route)
3. [Worker Code](#worker-code)
4. [Termux Setup](#termux-setup)

   * [Install Termux & Plugins](#install-termux--plugins)
   * [Install Dependencies](#install-dependencies)
   * [Install Boot Script](#install-boot-script)
5. [Boot Script (`update_ip.sh`)](#boot-script-update_ipsh)
6. [Usage](#usage)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

* A domain managed in Cloudflare (e.g. `dmj.one`).
* Cloudflare account with access to Workers & KV.
* Android device with Termux and wireless ADB/scrcpy setup.

---

## Cloudflare Setup

### Create KV Namespace

1. In the Cloudflare dashboard, navigate to **Workers → KV**.
2. Click **Create namespace** and name it `PHONE_IP_STORE`.
3. Copy the **Namespace ID** for later.

### Configure Worker

1. Go to **Workers → Create a Service**, name it `phone-ip`.
2. In the Worker editor, replace `index.js` with the code in [Worker Code](#worker-code).

### Bind KV & Secret

1. In **Workers → phone-ip → Settings**, scroll to **KV Namespaces** and click **Add binding**:

   * **Variable name**: `IP_KV`
   * **Namespace**: `PHONE_IP_STORE`
2. Under **Variables and Secrets**, click **Add secret**:

   * **Name**: `UPDATE_SECRET`
   * **Value**: a strong secret (e.g. `MyPhoneKey123`).

### Define Route

1. In **Workers → phone-ip → Routes**, click **Add route**.
2. Enter `phoneip.your-domain.com/*` and select the `phone-ip` Worker.
3. Save and **Deploy** the Worker.

---

## Worker Code

```js
addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request))
})

async function handleRequest(request) {
  const url = new URL(request.url)

  // POST /update
  if (request.method === 'POST' && url.pathname === '/update') {
    let data
    try {
      data = await request.json()
    } catch {
      return new Response('Bad JSON', { status: 400 })
    }
    if (data.key !== UPDATE_SECRET || !data.ip) {
      return new Response('Unauthorized or missing ip', { status: 401 })
    }
    const now = new Date().toISOString()
    await IP_KV.put('latest', JSON.stringify({ ip: data.ip, ts: now }))
    return new Response('OK', { status: 200 })
  }

  // GET /
  if (request.method === 'GET' && url.pathname === '/') {
    const raw = await IP_KV.get('latest')
    if (!raw) {
      return new Response('IP not set', {
        status: 404,
        headers: {
          'Content-Type': 'text/plain; charset=utf-8',
          'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0'
        }
      })
    }
    const { ip, ts } = JSON.parse(raw)
    const d = new Date(ts)
    const datePart = d.toLocaleDateString('en-US', {
      timeZone: 'Asia/Kolkata', year: 'numeric', month: 'long', day: 'numeric'
    })
    const timePart = d.toLocaleTimeString('en-US', {
      timeZone: 'Asia/Kolkata', hour12: false,
      hour: '2-digit', minute: '2-digit', second: '2-digit'
    })
    const body = `IP: ${ip}\nUpdated: ${datePart} ${timePart}`

    return new Response(body, {
      status: 200,
      headers: {
        'Content-Type': 'text/plain; charset=utf-8',
        'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0'
      }
    })
  }


  return new Response('Not found', { status: 404 })
}
```

---

## Termux Setup

### Install Termux & Plugins

1. Install **Termux** (from Google Play Store) and **Termux\:Boot** from [F-Droid](https://f-droid.org).
2. **Pair** your device for wireless debugging (using scrcpy or `adb` pairing):

   ```bash
   cd path/to/scrcpy
   ./adb pair <device-ip>:<pairing-port>
   # enter the PIN shown on-screen
   ```
3. **Enable TCP mode** on port 5555:

   ```bash
   ./adb tcpip 5555
   ```
4. **Connect** ADB over TCP:

   ```bash
   ./adb connect <device-ip>:5555
   ```
5. **Install** the Termux\:Boot APK over this ADB connection:

   ```bash
   ./adb install ~/Downloads/com.termux.boot_1000.apk
   ```
6. Open the Termux app on your device and **grant storage access**:

   ```bash
   termux-setup-storage
   ```

### Install Dependencies

```bash
pkg update && pkg install dos2unix wget
```

### Install Boot Script

Run this one‑liner in Termux to fetch and install the script:

```bash
mkdir -p ~/.termux/boot \
&& curl -fsSL https://raw.githubusercontent.com/your-user-name/repo-name/main/update_ip.sh \
   -o ~/.termux/boot/update_ip.sh \
&& dos2unix ~/.termux/boot/update_ip.sh \
&& chmod +x ~/.termux/boot/update_ip.sh
```

---

## Boot Script (`update_ip.sh`)

```bash
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
```

---

## Usage

* **Reboot** your device, or manually run: `~/.termux/boot/update_ip.sh`.
* Retrieve your current IP:

  ```bash
  curl https://phoneip.your-domain.com/
  ```

  Output:

  ```
  IP: 10.10.9.50
  Updated: May 5, 2025 15:12:22
  ```

---

## Troubleshooting

* **No IP found** in log: ensure `wlan0` is the correct interface (check `ifconfig`).
* **401 Unauthorized** on POST: verify `UPDATE_SECRET` matches exactly between Worker and script.
* **No persistence**: confirm KV is bound to `IP_KV` in Worker settings.
* **Multiple loops**: kill old loops with `pkill -f update_ip.sh` or remove stray PID files.

---

Made by Divya Mohan | [dmj.one](https://dmj.one)
