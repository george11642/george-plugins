#!/usr/bin/env python3
"""Minimal VNC screenshot capture tool using raw protocol."""
import socket, struct, sys, zlib
from PIL import Image

def capture_vnc(host='localhost', port=5999, output='/tmp/vnc_screenshot.png'):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(15)
    sock.connect((host, port))

    # Version handshake
    version = sock.recv(12)
    sock.send(b'RFB 003.008\n')

    # Security
    num_types = struct.unpack('!B', sock.recv(1))[0]
    types = sock.recv(num_types)
    sock.send(b'\x01')  # No auth
    result = struct.unpack('!I', sock.recv(4))[0]
    if result != 0:
        print(f"Auth failed: {result}")
        return False

    # ClientInit (shared=1)
    sock.send(b'\x01')

    # ServerInit
    header = sock.recv(4)
    width, height = struct.unpack('!HH', header)
    pixel_format = sock.recv(16)
    name_len = struct.unpack('!I', sock.recv(4))[0]
    name = sock.recv(name_len)
    print(f"Screen: {width}x{height}, name: {name.decode('utf-8', errors='replace')}")

    # Set pixel format to 32-bit RGBA
    # SetPixelFormat message (type 0)
    fmt = struct.pack('!BBBBHHHBBBxxx',
        32,   # bits-per-pixel
        24,   # depth
        0,    # big-endian-flag
        1,    # true-colour-flag
        255,  # red-max
        255,  # green-max
        255,  # blue-max
        16,   # red-shift
        8,    # green-shift
        0,    # blue-shift
    )
    sock.send(struct.pack('!Bxxx', 0) + fmt)

    # Set encodings (Raw=0, Zlib=6, CopyRect=1)
    sock.send(struct.pack('!BxH', 2, 3))
    sock.send(struct.pack('!iii', 6, 1, 0))

    zlib_decompressor = zlib.decompressobj()

    # Request full framebuffer update
    sock.send(struct.pack('!BxHHHH', 3, 0, 0, width, height))

    # Read framebuffer update
    img = Image.new('RGB', (width, height), (0, 0, 0))
    pixels = img.load()

    def recv_exact(n):
        data = b''
        while len(data) < n:
            chunk = sock.recv(min(n - len(data), 65536))
            if not chunk:
                raise ConnectionError("Connection closed")
            data += chunk
        return data

    timeout_counter = 0
    while timeout_counter < 50:
        try:
            msg_type = struct.unpack('!B', recv_exact(1))[0]
        except socket.timeout:
            timeout_counter += 1
            continue

        if msg_type == 0:  # FramebufferUpdate
            _padding = recv_exact(1)
            num_rects = struct.unpack('!H', recv_exact(2))[0]
            print(f"Receiving {num_rects} rectangles...")

            for i in range(num_rects):
                x, y, w, h, encoding = struct.unpack('!HHHHi', recv_exact(12))

                if encoding == 0:  # Raw
                    data = recv_exact(w * h * 4)
                    for py in range(h):
                        for px in range(w):
                            offset = (py * w + px) * 4
                            b, g, r, a = data[offset:offset+4]
                            if x + px < width and y + py < height:
                                pixels[x + px, y + py] = (r, g, b)

                elif encoding == 6:  # Zlib
                    zlen = struct.unpack('!I', recv_exact(4))[0]
                    zdata = recv_exact(zlen)
                    data = zlib_decompressor.decompress(zdata)
                    for py in range(h):
                        for px in range(w):
                            offset = (py * w + px) * 4
                            b, g, r, a = data[offset:offset+4]
                            if x + px < width and y + py < height:
                                pixels[x + px, y + py] = (r, g, b)

                elif encoding == 1:  # CopyRect
                    src_x, src_y = struct.unpack('!HH', recv_exact(4))
                    # Skip copy rect handling for screenshot
                else:
                    print(f"Unknown encoding: {encoding}")
                    break

            break  # Got our framebuffer update
        else:
            # Skip other message types
            recv_exact(1)  # Read and discard

    img.save(output)
    print(f"Screenshot saved to {output}")
    sock.close()
    return True

if __name__ == '__main__':
    host = sys.argv[1] if len(sys.argv) > 1 else 'localhost'
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 5999
    output = sys.argv[3] if len(sys.argv) > 3 else '/tmp/vnc_screenshot.png'
    capture_vnc(host=host, port=port, output=output)
