import json
import urllib.request
import urllib.error

for url in [
    'https://iptv-subscription-api.tvkora56.workers.dev/v1/config?t=live',
    'https://iptv-subscription-api.tvkora56.workers.dev/v1/login',
]:
    print('URL', url)
    try:
        if url.endswith('/login'):
            body = json.dumps({'code': '55669977', 'device_id': 'diagnostic-device-293', 'version_code': 293}).encode()
            req = urllib.request.Request(url, data=body, headers={'Content-Type': 'application/json'}, method='POST')
        else:
            req = urllib.request.Request(url, headers={'Accept': 'application/json'})
        with urllib.request.urlopen(req, timeout=20) as response:
            raw = response.read()
            print('STATUS', response.status, 'BYTES', len(raw))
            try:
                payload = json.loads(raw)
                if url.endswith('/login'):
                    server = payload.get('server') or {}
                    print(json.dumps({
                        'ok': payload.get('ok'),
                        'message': payload.get('message'),
                        'server_type': server.get('server_type'),
                        'host': bool(server.get('host')),
                        'username': bool(server.get('username')),
                        'password': bool(server.get('password')),
                        'content_mode': server.get('content_mode'),
                    }, ensure_ascii=False))
                else:
                    print(json.dumps(payload, ensure_ascii=False)[:1200])
            except Exception:
                print(raw[:300])
    except urllib.error.HTTPError as exc:
        print('HTTP_ERROR', exc.code, exc.read()[:500])
    except Exception as exc:
        print(type(exc).__name__, str(exc))
