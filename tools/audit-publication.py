#!/usr/bin/env python3
"""Check indexed files and reachable history; print locations, never secrets.

This conservative check is not a guarantee that all personal data is detected.
Review the diff and license provenance as well before publishing.
"""
import re
import subprocess
import sys


def git(*args):
    return subprocess.check_output(["git", *args])


patterns = {
    "private key": rb"-----BEGIN (?:OPENSSH |RSA |EC |DSA |ENCRYPTED )?PRIVATE KEY-----",
    "GitHub token": rb"\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})\b",
    "cloud key": rb"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b",
    "provider token": rb"\bsk-(?:proj-|ant-)?[A-Za-z0-9_-]{40,}\b",
    "Slack token": rb"\bxox[baprs]-[A-Za-z0-9-]{25,}\b",
}
private_path = re.compile(
    r"(?:^|/)(?:\.env(?:\.[^/]+)?|\.hermes|\.ssh|credentials\.json|"
    r"secrets\.json)(?:/|$)|\.(?:kdbx|keyx|pem|p12|pfx|gguf|safetensors)$"
)
issues = []
objects = {}
for entry in git("ls-files", "--stage", "-z").split(b"\0"):
    if not entry:
        continue
    meta, path = entry.split(b"\t", 1)
    mode, oid, _ = meta.split()
    name = path.decode(errors="replace")
    if mode == b"160000":
        issues.append((name, "nested repository/gitlink"))
    else:
        objects[oid.decode()] = name

for line in git("rev-list", "--objects", "--all").decode().splitlines():
    oid, _, path = line.partition(" ")
    if path:
        objects.setdefault(oid, "history:" + path)

# Batch inspection avoids spawning a process per historical object.
proc = subprocess.Popen(["git", "cat-file", "--batch"], stdin=subprocess.PIPE,
                        stdout=subprocess.PIPE)
for oid, name in objects.items():
    path = name.removeprefix("history:")
    if private_path.search(path) and not path.endswith(".env.example"):
        issues.append((name, "sensitive filename"))
    proc.stdin.write((oid + "\n").encode())
    proc.stdin.flush()
    header = proc.stdout.readline().split()
    size = int(header[2])
    data = proc.stdout.read(size)
    proc.stdout.read(1)
    if header[1] != b"blob":
        continue
    if size > 20 * 1024 * 1024:
        issues.append((name, "file larger than 20 MiB"))
    for label, pattern in patterns.items():
        if re.search(pattern, data):
            issues.append((name, label))
proc.stdin.close()
proc.wait()
for name, reason in sorted(set(issues)):
    print(f"REVIEW {name}: {reason}")
print(f"Checked {len(objects)} indexed/historical objects; {len(set(issues))} findings.")
sys.exit(bool(issues))
