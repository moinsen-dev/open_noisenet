#!/usr/bin/env python3
"""Forward one selected LAN device over TLS to a loopback-only test backend."""

import argparse
import ipaddress
import select
import socket
import ssl
import threading


def relay(client, context, upstream):
    try:
        with client, context.wrap_socket(client, server_side=True) as secure:
            with socket.create_connection(upstream, timeout=5) as backend:
                secure.settimeout(None)
                backend.settimeout(None)
                while True:
                    readable, _, _ = select.select([secure, backend], [], [], 60)
                    if not readable:
                        return
                    for source in readable:
                        data = source.recv(65536)
                        if not data:
                            if source is backend:
                                try:
                                    secure.settimeout(1)
                                    secure.unwrap()
                                except (OSError, ssl.SSLError):
                                    pass
                            return
                        (backend if source is secure else secure).sendall(data)
    except (OSError, ssl.SSLError):
        # Never log request bodies, credentials or device identifiers.
        return


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--bind', required=True, help='Private IPv4 address of this host')
    parser.add_argument('--allow', required=True, help='IPv4 address of the test device')
    parser.add_argument('--port', type=int, default=18443)
    parser.add_argument('--backend-port', type=int, default=18190)
    parser.add_argument('--cert', required=True)
    parser.add_argument('--key', required=True)
    args = parser.parse_args()
    bind = ipaddress.IPv4Address(args.bind)
    peer = ipaddress.IPv4Address(args.allow)
    private_networks = [ipaddress.IPv4Network(cidr) for cidr in ('10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16')]
    if not all(any(address in net for net in private_networks) for address in (bind, peer)):
        parser.error('Bind and device addresses must be private IPv4 addresses')
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_3
    context.load_cert_chain(args.cert, args.key)
    with socket.create_server((str(bind), args.port), backlog=16) as listener:
        print(f'Private field-test TLS proxy listening on {bind}:{args.port}', flush=True)
        while True:
            connection, remote = listener.accept()
            if remote[0] != str(peer):
                connection.close()
                continue
            threading.Thread(target=relay, args=(connection, context, ('127.0.0.1', args.backend_port)), daemon=True).start()


if __name__ == '__main__':
    main()
