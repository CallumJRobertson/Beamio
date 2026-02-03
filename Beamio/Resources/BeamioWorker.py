import os
import tempfile
import threading
from html.parser import HTMLParser
from urllib.parse import urljoin
from urllib.request import urlopen, Request

_LOCK = threading.Lock()
_DEVICE = None
_LAST_ERROR = ""


def _set_error(message: str) -> None:
    global _LAST_ERROR
    _LAST_ERROR = message


def last_error() -> str:
    return _LAST_ERROR


def _resolve_key_path(key_path: str) -> str:
    from adb_shell.auth.keygen import keygen

    if os.path.isdir(key_path):
        resolved_path = os.path.join(key_path, "adbkey")
    else:
        resolved_path = key_path
    os.makedirs(os.path.dirname(resolved_path) or ".", exist_ok=True)
    if not os.path.exists(resolved_path):
        keygen(resolved_path)
    return resolved_path


def connect(ip_address: str, key_path: str) -> str:
    global _DEVICE
    if ip_address == "127.0.0.1":
        return "Connected (Simulation)"

    _set_error("")
    try:
        from adb_shell.adb_device import AdbDeviceTcp
        from adb_shell.auth.sign_pythonrsa import PythonRSASigner

        with _LOCK:
            resolved_key_path = _resolve_key_path(key_path)
            with open(resolved_key_path, "r", encoding="utf-8") as key_file:
                private_key = key_file.read()
            with open(f"{resolved_key_path}.pub", "r", encoding="utf-8") as pub_file:
                public_key = pub_file.read()

            signer = PythonRSASigner(public_key, private_key)
            device = AdbDeviceTcp(ip_address, 5555, default_transport_timeout_s=9.0)
            device.connect(rsa_keys=[signer], auth_timeout_s=0.1)
            _DEVICE = device
            return "Connected"
    except Exception as exc:
        _set_error(str(exc))
        return f"Connection failed: {exc}"


def scan_url(url: str):
    _set_error("")
    try:
        class _ApkLinkParser(HTMLParser):
            def __init__(self):
                super().__init__()
                self._current_href = None
                self._current_text = []
                self.items = []

            def handle_starttag(self, tag, attrs):
                if tag.lower() != "a":
                    return
                href = dict(attrs).get("href")
                if href and href.lower().endswith(".apk"):
                    self._current_href = href
                    self._current_text = []

            def handle_data(self, data):
                if self._current_href is not None:
                    self._current_text.append(data)

            def handle_endtag(self, tag):
                if tag.lower() != "a":
                    return
                if self._current_href is None:
                    return
                name = "".join(self._current_text).strip()
                href = self._current_href
                full_url = urljoin(url, href)
                self.items.append({
                    "name": name or os.path.basename(href),
                    "url": full_url,
                })
                self._current_href = None
                self._current_text = []

        request = Request(url, headers={"User-Agent": "Beamio/1.0"})
        with urlopen(request, timeout=15) as response:
            html = response.read().decode("utf-8", errors="replace")

        parser = _ApkLinkParser()
        parser.feed(html)
        return parser.items
    except Exception as exc:
        _set_error(str(exc))
        return []


def install_apk(url: str):
    _set_error("")
    try:
        with _LOCK:
            if _DEVICE is None:
                yield "No device connected."
                return
            device = _DEVICE

        yield "Downloading APK..."
        temp_dir = tempfile.mkdtemp(prefix="beamio_")
        apk_path = os.path.join(temp_dir, "payload.apk")

        request = Request(url, headers={"User-Agent": "Beamio/1.0"})
        with urlopen(request, timeout=30) as response, open(apk_path, "wb") as apk_file:
            while True:
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                apk_file.write(chunk)

        yield "Installing APK..."
        device.install(apk_path)
        yield "Install complete."

        try:
            os.remove(apk_path)
            os.rmdir(temp_dir)
        except OSError:
            pass
    except Exception as exc:
        _set_error(str(exc))
        yield f"Install failed: {exc}"
