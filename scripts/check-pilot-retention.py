#!/usr/bin/env python3
"""External monitor probe. Exit 0 only for a fresh, authenticated worker health.

The hosting monitor must run this on a schedule and alert on nonzero exit or a
missing execution. This script does not install a monitor or send notifications.
Credentials must be injected by the monitor's secret store, never CLI arguments.
"""
import argparse
import json
import os
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--allow-loopback-http', action='store_true', help='Synthetic local tests only')
    args = parser.parse_args()
    raw_url = os.environ.get('OPENNOISENET_PILOT_HEALTH_URL', '')
    token = os.environ.get('OPENNOISENET_PILOT_HEALTH_TOKEN', '')
    try:
        url = urlsplit(raw_url)
        local_http = args.allow_loopback_http and url.scheme == 'http' and url.hostname in ('127.0.0.1', '::1', 'localhost')
        if (not token or not url.hostname or (url.scheme != 'https' and not local_http)
                or url.username or url.password or url.query or url.fragment
                or url.path != '/api/v1/map-pilot/admin/retention-health'):
            raise ValueError('invalid configuration')
        request = Request(raw_url, headers={'Authorization': 'Bearer ' + token, 'Accept': 'application/json', 'Cache-Control': 'no-store'})
        with build_opener(NoRedirect).open(request, timeout=10) as response:
            if response.status != 200 or 'no-store' not in response.headers.get('Cache-Control', '').lower():
                raise ValueError('invalid response')
            payload = json.loads(response.read(4097))
        if not isinstance(payload, dict) or payload.get('status') != 'ok':
            raise ValueError('worker unhealthy')
    except (ValueError, TypeError, UnicodeDecodeError, OSError, URLError, HTTPError):
        print('CRITICAL: pilot retention health unavailable or unhealthy')
        return 2
    print('OK: pilot retention health')
    return 0


if __name__ == '__main__':
    sys.exit(main())
