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