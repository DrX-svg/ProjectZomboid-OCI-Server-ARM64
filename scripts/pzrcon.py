import os
import socket
import struct
import sys

HOST = "127.0.0.1"
PORT = 27015
PASSWORD = os.environ["RCON_PASSWORD"]

def packet(req_id, pkt_type, text):
    body = text.encode("utf-8") + b"\x00\x00"
    size = len(body) + 8
    return struct.pack("<iii", size, req_id, pkt_type) + body

def recv_exact(sock, n):
    data = b""
    while len(data) < n:
        chunk = sock.recv(n - len(data))
        if not chunk:
            raise RuntimeError("RCON connection closed")
        data += chunk
    return data

def recv_packet(sock):
    size = struct.unpack("<i", recv_exact(sock, 4))[0]
    data = recv_exact(sock, size)
    req_id, pkt_type = struct.unpack("<ii", data[:8])
    text = data[8:-2].decode("utf-8", errors="replace")
    return req_id, pkt_type, text

command = " ".join(sys.argv[1:])

with socket.create_connection((HOST, PORT), timeout=5) as s:
    s.settimeout(5)

    s.sendall(packet(1, 3, PASSWORD))

    authenticated = False
    for _ in range(3):
        req_id, pkt_type, text = recv_packet(s)

        if req_id == -1:
            raise SystemExit("RCON authentication failed")

        if req_id == 1 and pkt_type == 2:
            authenticated = True
            break

    if not authenticated:
        raise SystemExit("No RCON authentication response")

    s.sendall(packet(2, 2, command))
    req_id, pkt_type, text = recv_packet(s)

    print(text)
