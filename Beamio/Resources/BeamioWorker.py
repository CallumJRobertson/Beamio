import os
import tempfile
import threading
from urllib.parse import urljoin

import requests
from bs4 import BeautifulSoup
from adb_shell.adb_device import AdbDeviceTcp
from adb_shell.auth.keygen import keygen
from adb_shell.auth.sign_pythonrsa import PythonRSASigner

_LOCK = threading.Lock()
_DEVICE = None


def _resolve_key_path(key_path: str) -> str:
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


def scan_url(url: str):
    response = requests.get(url, timeout=15)
    response.raise_for_status()

    soup = BeautifulSoup(response.text, "html.parser")
    results = []

    for link in soup.find_all("a"):
        href = link.get("href")
        if not href:
            continue
        if not href.lower().endswith(".apk"):
            continue

        full_url = urljoin(url, href)
        name = link.text.strip() or os.path.basename(href)
        results.append({"name": name, "url": full_url})

    return results


def install_apk(url: str):
    with _LOCK:
        if _DEVICE is None:
            yield "No device connected."
            return
        device = _DEVICE

    yield "Downloading APK..."
    response = requests.get(url, stream=True, timeout=30)
    response.raise_for_status()

    temp_dir = tempfile.mkdtemp(prefix="beamio_")
    apk_path = os.path.join(temp_dir, "payload.apk")

    with open(apk_path, "wb") as apk_file:
        for chunk in response.iter_content(chunk_size=1024 * 1024):
            if chunk:
                apk_file.write(chunk)

    yield "Installing APK..."
    device.install(apk_path)
    yield "Install complete."

    try:
        os.remove(apk_path)
        os.rmdir(temp_dir)
    except OSError:
        pass
