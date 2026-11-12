"""Repository guards (CI and local): no permissions in the main manifest, no secret-like values.

Fails on any run of 64+ hex characters except the public example secret, outside build-hash logs.
usage: python -I tools/check-secrets.py
"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXAMPLE = b"2db76449a55d59f1f9420b809edb1beb19dfa434ddb5dbf331f01aec35956e35"  # public, not an account
HASH_LOGS = {"RELEASES.md", "RELEASE.md"}
SKIP_DIRS = {".git", "bin"}
fail = 0

manifest = open(os.path.join(ROOT, "manifest.xml"), encoding="utf-8").read()
if not re.search(r"<iq:permissions\s*/>", manifest):
    print("FAIL manifest.xml declares permissions; the main build must have none")
    fail += 1

for dirpath, dirs, files in os.walk(ROOT):
    dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
    for name in files:
        if name in HASH_LOGS:
            continue
        path = os.path.join(dirpath, name)
        data = open(path, "rb").read()
        for run in set(re.findall(rb"[0-9a-fA-F]{64,}", data)):
            if EXAMPLE in run.lower():
                continue
            print("FAIL secret-like value in", os.path.relpath(path, ROOT), "len", len(run))
            fail += 1

print("OK: no permissions, no secret-like values" if fail == 0 else "FAILED: %d" % fail)
sys.exit(1 if fail else 0)
