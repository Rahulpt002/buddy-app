"""Pairing identity (agent id + token), TLS certificate and the pairing QR code."""
from __future__ import annotations

import datetime as dt
import hashlib
import hmac
import ipaddress
import json
import os
import secrets
import socket
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlencode

import psutil

from . import PROTO_VERSION
from .config import home_dir


@dataclass
class Identity:
    agent_id: str
    token: str

    def check(self, presented: str | None) -> bool:
        if not presented:
            return False
        return hmac.compare_digest(presented.encode(), self.token.encode())


def _write_private(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "wb") as f:
        f.write(data)


def load_identity(reset_token: bool = False) -> Identity:
    path = home_dir() / "pairing.json"
    data: dict = {}
    if path.exists():
        try:
            data = json.loads(path.read_text())
        except json.JSONDecodeError:
            data = {}
    changed = False
    if not data.get("agent_id"):
        data["agent_id"] = secrets.token_hex(4)
        changed = True
    if reset_token or not data.get("token"):
        data["token"] = secrets.token_urlsafe(32)
        changed = True
    if changed:
        _write_private(path, json.dumps(data, indent=2).encode())
    return Identity(agent_id=data["agent_id"], token=data["token"])


def lan_ipv4s() -> list[str]:
    """Non-loopback, non-link-local IPv4 addresses on interfaces that are up. en0 first."""
    stats = psutil.net_if_stats()
    found: list[tuple[int, str]] = []
    for name, addrs in psutil.net_if_addrs().items():
        st = stats.get(name)
        if not st or not st.isup:
            continue
        for a in addrs:
            if a.family != socket.AF_INET:
                continue
            ip = ipaddress.ip_address(a.address)
            if ip.is_loopback or ip.is_link_local:
                continue
            rank = 0 if name == "en0" else 1 if name.startswith("en") else 2
            found.append((rank, a.address))
    return [ip for _, ip in sorted(found)]


# ---------------------------------------------------------------- TLS


def ensure_cert(agent_id: str) -> tuple[Path, Path, str]:
    """Return (cert_path, key_path, sha256_fingerprint_hex). Generates a long-lived
    self-signed cert on first run. The phone pins the fingerprint from the QR, so the
    cert's names/IPs don't matter for validation and IP changes don't require re-pairing."""
    from cryptography import x509
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import ec
    from cryptography.x509.oid import NameOID

    d = home_dir()
    cert_p, key_p = d / "tls_cert.pem", d / "tls_key.pem"
    if not (cert_p.exists() and key_p.exists()):
        key = ec.generate_private_key(ec.SECP256R1())
        name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, f"deskpanel-{agent_id}")])
        now = dt.datetime.now(dt.timezone.utc)
        cert = (
            x509.CertificateBuilder()
            .subject_name(name)
            .issuer_name(name)
            .public_key(key.public_key())
            .serial_number(x509.random_serial_number())
            .not_valid_before(now - dt.timedelta(days=1))
            .not_valid_after(now + dt.timedelta(days=3650))
            .add_extension(
                x509.SubjectAlternativeName(
                    [x509.DNSName("localhost"), x509.IPAddress(ipaddress.ip_address("127.0.0.1"))]
                ),
                critical=False,
            )
            .sign(key, hashes.SHA256())
        )
        _write_private(
            key_p,
            key.private_bytes(
                serialization.Encoding.PEM,
                serialization.PrivateFormat.PKCS8,
                serialization.NoEncryption(),
            ),
        )
        _write_private(cert_p, cert.public_bytes(serialization.Encoding.PEM))
    return cert_p, key_p, cert_fingerprint(cert_p)


def cert_fingerprint(cert_path: Path) -> str:
    from cryptography import x509
    from cryptography.hazmat.primitives import serialization

    cert = x509.load_pem_x509_certificate(cert_path.read_bytes())
    return hashlib.sha256(cert.public_bytes(serialization.Encoding.DER)).hexdigest()


# ---------------------------------------------------------------- QR


def pair_uri(ident: Identity, port: int, fingerprint: str | None) -> str:
    q = {
        "v": PROTO_VERSION,
        "id": ident.agent_id,
        "n": socket.gethostname().removesuffix(".local"),
        "h": ",".join(lan_ipv4s()),
        "p": port,
        "t": ident.token,
    }
    if fingerprint:
        q["fp"] = fingerprint
    return "deskpanel://pair?" + urlencode(q, safe=",")


def print_qr(uri: str) -> None:
    import qrcode

    qr = qrcode.QRCode(border=2, error_correction=qrcode.constants.ERROR_CORRECT_L)
    qr.add_data(uri)
    qr.make(fit=True)
    qr.print_ascii(invert=True)


def save_qr_png(uri: str) -> Path:
    import qrcode

    img = qrcode.make(uri, box_size=10, border=3)
    path = home_dir() / "pair.png"
    img.save(path)
    os.chmod(path, 0o600)
    return path
