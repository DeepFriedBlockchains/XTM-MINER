#!/usr/bin/env python3
"""Local-only TLS checks for the XMRig patch; this is not a pool/mining test."""
import json
import os
import socket
import ssl
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path


class TestServer:
    def __init__(self, cert: Path, key: Path):
        self.cert, self.key = cert, key
        self.ready = threading.Event()
        self.errors = []
        self.sock = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.sock.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
        self.sock.bind(("::", 0))
        self.sock.listen(1)
        self.port = self.sock.getsockname()[1]
        self.sock.settimeout(4)
        self.thread = threading.Thread(target=self._serve, daemon=True)

    def _serve(self):
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(str(self.cert), str(self.key))
        try:
            raw, _ = self.sock.accept()
            with raw:
                raw.settimeout(2)
                with context.wrap_socket(raw, server_side=True) as conn:
                    self.ready.set()
                    try:
                        conn.recv(4096)
                    except (TimeoutError, OSError):
                        pass
        except (TimeoutError, OSError, ssl.SSLError) as exc:
            self.errors.append(str(exc))
        finally:
            self.sock.close()

    def start(self):
        self.thread.start()


def make_certificates(tmp: Path):
    ca_key, ca_cert = tmp / "ca.key", tmp / "ca.pem"
    subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
                    "-keyout", str(ca_key), "-out", str(ca_cert), "-days", "2",
                    "-subj", "/CN=XTM-Miner Test CA"], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for name, dns in (("valid", "localhost"), ("wrong-host", "wrong.example")):
        key, csr, cert, ext = (tmp / f"{name}.key", tmp / f"{name}.csr",
                               tmp / f"{name}.pem", tmp / f"{name}.ext")
        ext.write_text(f"subjectAltName=DNS:{dns}\nextendedKeyUsage=serverAuth\n")
        subprocess.run(["openssl", "req", "-newkey", "rsa:2048", "-nodes",
                        "-keyout", str(key), "-out", str(csr), "-subj", f"/CN={dns}"],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(["openssl", "x509", "-req", "-in", str(csr), "-CA", str(ca_cert),
                        "-CAkey", str(ca_key), "-CAcreateserial", "-out", str(cert),
                        "-days", "2", "-extfile", str(ext)], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return ca_cert


def run_miner(binary: str, ca: Path, port: int):
    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as config:
        os.chmod(config.name, 0o600)
        json.dump({
            "colors": False,
            "cpu": {"enabled": True, "huge-pages": False},
            "donate-level": 1,
            "randomx": {"mode": "light", "1gb-pages": False},
            "pools": [{"algo": "rx/0", "url": f"localhost:{port}",
                       "user": "TARI_TEST_ADDRESS/ci", "pass": "x",
                       "tls": True, "sni": True, "keepalive": True}],
        }, config)
        config_path = config.name
    env = os.environ.copy()
    env["SSL_CERT_FILE"] = str(ca)
    process = subprocess.Popen([binary, f"--config={config_path}", "--threads=1"],
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               text=True, env=env)
    try:
        time.sleep(2.0)
        process.send_signal(2)
        try:
            output, _ = process.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            output, _ = process.communicate()
            raise AssertionError("XMRig did not stop promptly after SIGINT")
    finally:
        Path(config_path).unlink(missing_ok=True)
    return output


def main():
    if len(sys.argv) != 2:
        raise SystemExit("Usage: tests/test_tls_verification.py /path/to/patched/xmrig")
    binary = str(Path(sys.argv[1]).resolve())
    with tempfile.TemporaryDirectory(prefix="xtm-tls-test-") as td:
        tmp = Path(td)
        ca = make_certificates(tmp)

        valid_server = TestServer(tmp / "valid.pem", tmp / "valid.key")
        valid_server.start()
        valid_log = run_miner(binary, ca, valid_server.port)
        if not valid_server.ready.wait(0.1):
            raise AssertionError("A CA-signed certificate for localhost was not accepted\n" + valid_log)
        print("PASS valid CA chain + matching hostname accepted")

        # A validly signed certificate for the wrong name must fail host validation.
        wrong_server = TestServer(tmp / "wrong-host.pem", tmp / "wrong-host.key")
        wrong_server.start()
        wrong_log = run_miner(binary, ca, wrong_server.port)
        if wrong_server.ready.is_set():
            raise AssertionError("Certificate with a wrong hostname was accepted\n" + wrong_log)
        print("PASS wrong hostname rejected")

        # A self-signed certificate not present in the configured CA bundle must fail.
        untrusted_key, untrusted_cert = tmp / "untrusted.key", tmp / "untrusted.pem"
        subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
                        "-keyout", str(untrusted_key), "-out", str(untrusted_cert),
                        "-days", "2", "-subj", "/CN=localhost",
                        "-addext", "subjectAltName=DNS:localhost"], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        untrusted_server = TestServer(untrusted_cert, untrusted_key)
        untrusted_server.start()
        untrusted_log = run_miner(binary, ca, untrusted_server.port)
        if untrusted_server.ready.is_set():
            raise AssertionError("Untrusted certificate was accepted\n" + untrusted_log)
        print("PASS untrusted certificate rejected")

    print("NOTE: This local TLS regression test does not demonstrate Tari pool authentication or accepted shares.")


if __name__ == "__main__":
    main()
