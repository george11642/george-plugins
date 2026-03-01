#!/usr/bin/env python3
"""Minimal VNC interaction tool - click, type, and screenshot."""
import socket, struct, sys, zlib, time
from PIL import Image

class VNCClient:
    def __init__(self, host='localhost', port=5999):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.settimeout(15)
        self.sock.connect((host, port))
        self.width = 0
        self.height = 0
        self.zlib_decompressor = zlib.decompressobj()
        self._handshake()

    def _handshake(self):
        version = self.sock.recv(12)
        self.sock.send(b'RFB 003.008\n')
        num_types = struct.unpack('!B', self.sock.recv(1))[0]
        types = self.sock.recv(num_types)
        self.sock.send(b'\x01')
        result = struct.unpack('!I', self.sock.recv(4))[0]
        assert result == 0, f"Auth failed: {result}"
        self.sock.send(b'\x01')
        header = self.sock.recv(4)
        self.width, self.height = struct.unpack('!HH', header)
        pixel_format = self.sock.recv(16)
        name_len = struct.unpack('!I', self.sock.recv(4))[0]
        name = self.sock.recv(name_len)
        # Set pixel format to 32-bit
        fmt = struct.pack('!BBBBHHHBBBxxx', 32, 24, 0, 1, 255, 255, 255, 16, 8, 0)
        self.sock.send(struct.pack('!Bxxx', 0) + fmt)
        # Set encodings
        self.sock.send(struct.pack('!BxH', 2, 3))
        self.sock.send(struct.pack('!iii', 6, 1, 0))

    def _recv_exact(self, n):
        data = b''
        while len(data) < n:
            chunk = self.sock.recv(min(n - len(data), 65536))
            if not chunk:
                raise ConnectionError("Connection closed")
            data += chunk
        return data

    def click(self, x, y, button=1):
        """Send mouse click at (x, y). button: 1=left, 2=middle, 4=right."""
        # Move to position
        self.sock.send(struct.pack('!BxHH', 5, x, y))
        time.sleep(0.05)
        # Press
        self.sock.send(struct.pack('!BBHH', 5, button, x, y))
        time.sleep(0.1)
        # Release
        self.sock.send(struct.pack('!BBHH', 5, 0, x, y))
        time.sleep(0.05)

    def double_click(self, x, y):
        self.click(x, y)
        time.sleep(0.15)
        self.click(x, y)

    def key(self, keysym, down=True):
        """Send key event. keysym is X11 keysym value."""
        self.sock.send(struct.pack('!BBxxI', 4, 1 if down else 0, keysym))

    def key_press(self, keysym):
        """Press and release a key."""
        self.key(keysym, True)
        time.sleep(0.05)
        self.key(keysym, False)
        time.sleep(0.05)

    def type_text(self, text):
        """Type a string character by character."""
        for ch in text:
            keysym = ord(ch)
            self.key_press(keysym)
            time.sleep(0.05)

    def screenshot(self, output='/tmp/vnc_screenshot.png'):
        """Capture current screen."""
        self.sock.send(struct.pack('!BxHHHH', 3, 0, 0, self.width, self.height))
        img = Image.new('RGB', (self.width, self.height), (0, 0, 0))
        pixels = img.load()

        timeout_counter = 0
        while timeout_counter < 50:
            try:
                msg_type = struct.unpack('!B', self._recv_exact(1))[0]
            except socket.timeout:
                timeout_counter += 1
                continue

            if msg_type == 0:  # FramebufferUpdate
                self._recv_exact(1)
                num_rects = struct.unpack('!H', self._recv_exact(2))[0]
                for i in range(num_rects):
                    x, y, w, h, encoding = struct.unpack('!HHHHi', self._recv_exact(12))
                    if encoding == 0:  # Raw
                        data = self._recv_exact(w * h * 4)
                        for py in range(h):
                            for px in range(w):
                                offset = (py * w + px) * 4
                                b, g, r, a = data[offset:offset+4]
                                if x+px < self.width and y+py < self.height:
                                    pixels[x+px, y+py] = (r, g, b)
                    elif encoding == 6:  # Zlib
                        zlen = struct.unpack('!I', self._recv_exact(4))[0]
                        zdata = self._recv_exact(zlen)
                        data = self.zlib_decompressor.decompress(zdata)
                        for py in range(h):
                            for px in range(w):
                                offset = (py * w + px) * 4
                                b, g, r, a = data[offset:offset+4]
                                if x+px < self.width and y+py < self.height:
                                    pixels[x+px, y+py] = (r, g, b)
                    elif encoding == 1:  # CopyRect
                        self._recv_exact(4)
                break
            else:
                self._recv_exact(1)

        img.save(output)
        return output

    def close(self):
        self.sock.close()


if __name__ == '__main__':
    action = sys.argv[1] if len(sys.argv) > 1 else 'screenshot'
    client = VNCClient()

    if action == 'screenshot':
        out = sys.argv[2] if len(sys.argv) > 2 else '/tmp/vnc_screenshot.png'
        client.screenshot(out)
        print(f"Saved: {out}")
    elif action == 'click':
        x, y = int(sys.argv[2]), int(sys.argv[3])
        client.click(x, y)
        print(f"Clicked: ({x}, {y})")
        time.sleep(1)
        client.screenshot()
        print("Screenshot after click saved")
    elif action == 'dblclick':
        x, y = int(sys.argv[2]), int(sys.argv[3])
        client.double_click(x, y)
        print(f"Double-clicked: ({x}, {y})")
        time.sleep(1)
        client.screenshot()
    elif action == 'type':
        text = sys.argv[2]
        client.type_text(text)
        print(f"Typed: {text}")
        time.sleep(0.5)
        client.screenshot()
    elif action == 'key':
        keysym = int(sys.argv[2], 0)
        client.key_press(keysym)
        print(f"Key: {keysym}")
        time.sleep(0.5)
        client.screenshot()

    client.close()
