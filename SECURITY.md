# Security Policy

## Supported versions

| Version | Supported |
|---|---|
| 1.0.x | ✅ |
| < 1.0 | ❌ |

## Reporting a vulnerability

**Do not open a public issue for security problems**, and never paste a real Żappka secret or
user ID anywhere. Use **Security → Report a vulnerability** (private advisory) on this repository.

Please include what the issue is, the impact you expect, steps to reproduce and the affected
version or commit.

## Scope

In scope: the watch app (credential handling, storage, settings import, anything that could leak
the secret), the build and release tooling, and CI.

Out of scope: Żabka's own services and apps, Garmin's firmware and Garmin Connect.

## Known, intentional design decisions

- **No keystore.** Connect IQ has no secure enclave. The secret is stored in app-private
  `Application.Storage`, not encrypted by the app. Encrypting it with a key shipped in the app
  would only look secure, so it is not done.
- **One pass through Garmin Connect.** App settings travel phone → Garmin Connect → watch once;
  the app blanks the field first.
- **No network.** The app declares no permissions, so it cannot send the secret anywhere.

Threat model: [`THREAT_MODEL.md`](THREAT_MODEL.md).

## Automated checks

CI runs a **gitleaks** secret scan over the full history and repository guards
(`tools/check-secrets.py`: no permissions in the manifest, no secret-like values outside the public
example; `tools/check-build.py --properties`: no default values in the app settings) on every push
and pull request. Release builds are checked by `tools/check-build.py` before and after compiling.
