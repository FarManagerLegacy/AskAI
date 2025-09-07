import base64
import hashlib
import http.client
import json
import secrets
import sys
import time
import uuid
import webbrowser
from pathlib import Path
from urllib.parse import urlencode

CLIENT_ID = "f0304373b74a44d2b584a3fb70ca9e56"
TIMEOUT = 10
POLLING_INTERVAL = 1
CREDENTIALS_FILE = Path.home() / ".qwen" / "oauth_creds.json"


def generate_pkce_pair():
    """Generate PKCE code verifier and challenge."""
    code_verifier = base64.urlsafe_b64encode(secrets.token_bytes(64)).decode().rstrip("=")
    sha256 = hashlib.sha256()
    sha256.update(code_verifier.encode())
    code_challenge = base64.urlsafe_b64encode(sha256.digest()).decode().rstrip("=")
    return code_verifier, code_challenge


def oauth():
    """Perform OAuth2 device flow and return access token."""
    conn = http.client.HTTPSConnection("chat.qwen.ai", timeout=TIMEOUT)
    headers = {
        "Accept": "application/json",
        "Content-Type": "application/x-www-form-urlencoded",
        "x-request-id": str(uuid.uuid4()),
    }
    code_verifier, code_challenge = generate_pkce_pair()
    payload = {
        "client_id": CLIENT_ID,
        "scope": "openid profile email model.completion",
        "code_challenge_method": "S256",
        "code_challenge": code_challenge,
    }
    conn.request("POST", "/api/v1/oauth2/device/code", urlencode(payload), headers)
    resp = conn.getresponse()
    if resp.status != 200:
        raise Exception(f"Request failed with status {resp.status}: {resp.reason}")
    login_info = json.loads(resp.read().decode())
    try:
        webbrowser.open(login_info['verification_uri_complete'])
        print("⏳ Waiting for browser login...")
    except:
        print(f"Please open {login_info['verification_uri_complete']} in browser to login.")
    
    del headers["x-request-id"]
    start_time = time.time()
    payload = {
        "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
        "client_id": CLIENT_ID,
        "device_code": login_info['device_code'],
        "code_verifier": code_verifier,
    }
    while True:  # poll auth
        conn.request("POST", "/api/v1/oauth2/token", urlencode(payload), headers)
        resp = conn.getresponse()
        if resp.status != 200 and resp.status != 400:
            raise Exception(f"Request failed with status {resp.status}: {resp.reason}")
        data = json.loads(resp.read().decode())
        if 'access_token' in data:
            data['expiry_date'] = int((time.time() + data['expires_in']) * 1000)
            del data['expires_in']
            del data['scope']
            del data['status']
            return data
        elif data.get('error') == "authorization_pending":
            minutes, seconds = divmod(login_info['expires_in'] - int(time.time()-start_time), 60)
            print(f"\r{minutes}:{seconds:02d}", end="")
            time.sleep(POLLING_INTERVAL)
        else:
            raise Exception(data['error_description'] if 'error_description' in data else "Unexpected error")


def save_token(data: dict):
    """Save token to credentials file."""
    CREDENTIALS_FILE.parent.mkdir(parents=True, exist_ok=True)
    try:
        token_str =json.dumps(data, indent=2)
        CREDENTIALS_FILE.write_text(token_str)
        print(f"\r✅ Token saved to: {CREDENTIALS_FILE}")
        return
    except PermissionError:
        print(f"\r❌ Permission denied: {CREDENTIALS_FILE}")
    except Exception as e:
        print(f"\r❌ Error saving token: {e}")

    print(token_str)


def main():
    try:
        token_data = oauth()
        save_token(token_data)
    except KeyboardInterrupt:
        print("\r🛑 Authentication cancelled.")
    except Exception as e:
        print(f"\r❌ Authentication failed: {type(e).__name__}: {e}")

if __name__ == "__main__":
    if CREDENTIALS_FILE.exists():
        print(f"⚠️  Credentials file already exists: {CREDENTIALS_FILE}")
        sys.exit(1)
    main()
