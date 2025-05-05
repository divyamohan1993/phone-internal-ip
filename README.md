# Phone Mirror

Broken Screen? Fetch the Phone Internal IP and mirror using scrcpy!

Prerequisites:
Cloud Run - Always free
Terux (Play Store)

## Cloud Run 

## Termux 

Below is a simplified end-to-end setup that:

1. Runs a tiny Cloud Run service that **stores** and **exposes** your phone’s latest internal IP
2. Uses a Termux boot script that **pushes** your IP on startup and then **every 5 minutes** thereafter

---

## 1️⃣ Cloud Run “IP Mirror” Service

1. **main.py**:

```python
# main.py
import os
from flask import Flask, request, abort, jsonify

app = Flask(__name__)

# a simple in-memory store
latest_ip = None

# shared secret so only your phone can update
SECRET = os.environ['UPDATE_SECRET']  # e.g. "MyPhoneKey123"

@app.route('/update', methods=['POST'])
def update():
    global latest_ip
    data = request.get_json(silent=True)
    if not data or data.get('key') != SECRET:
        abort(401)
    ip = data.get('ip')
    if not ip:
        abort(400, 'no ip')
    latest_ip = ip
    return jsonify(status="ok", ip=ip)

@app.route('/', methods=['GET'])
def get_ip():
    if not latest_ip:
        return "IP not set", 404
    return latest_ip, 200, {'Content-Type': 'text/plain; charset=utf-8'}

# if __name__ == '__main__':
#     app.run(host='0.0.0.0', port=8080)
```

2. **requirements.txt**:

   ```
   Flask>=2.0
   requests   # if you ever need it in future
   gunicorn
   ```

3. Add a **Procfile** (no file extension):

   ```
   web: gunicorn main:app
   ```

4. In the Cloud Run UI:
   * **Leave** the “Function entry point” blank or set it back to “Use buildpack default.”
   * Deploy.

The buildpack will detect your `Procfile` and spin up Gunicorn on `$PORT`.

### Why this works

* **Procfile/Buildpack**: The `web:` directive tells the Google Python buildpack exactly how to start your web server, again on the right port.

1. In your Cloud Run service settings, set the env var:

   ```
   UPDATE_SECRET=MyPhoneKey123
   ```
3. **Allow unauthenticated** invocations.

Your service URL will be something like:

```
https://<random-id>-<region>.run.app
```

* **POST** to `…/update` with `{ "key":"MyPhoneKey123","ip":"192.168.x.y" }`
* **GET** `…/` will return the last reported IP in plain text.

---

## 2️⃣ Phone-side: Termux + Boot-time + Interval

1. **Install** Termux and Termux\:Boot.

2. In Termux:

   ```bash
   pkg install iproute2 curl
   ```

3. Create `~/.termux/boot/update_ip.sh` with:

```bash
#!/data/data/com.termux/files/usr/bin/bash

SERVICE_URL="https://<your-service>.run.app/update"
SECRET="MyPhoneKey123"
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
```

4. Make it executable:

```bash
chmod +x ~/.termux/boot/update_ip.sh
```

5. **Reboot** your phone. Termux\:Boot will run this script, which:

   * Immediately posts your `wlan0` IP
   * Then re-posts every 5 minutes

---

## 3️⃣ Usage

* Whenever you need your phone’s LAN IP, simply:

  ```bash
  curl https://<your-service>.run.app
  ```

  → returns something like `192.168.1.42`.

