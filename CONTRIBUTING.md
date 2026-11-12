# Contributing

Thanks for working on Zappka QR. The goal of these notes is to keep changes small, safe and
consistent with the rest of the app.

## Before you start

- Read [`README.md`](README.md) and [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
- For anything touching credentials or settings, also read [`THREAT_MODEL.md`](THREAT_MODEL.md).

## Local setup

- Connect IQ SDK (developed with 9.1.0) and a developer key (see README → Build).
- Start the simulator (`connectiq`) before running tests or `monkeydo`.

## Branching & commits

- Branch off `main` with a prefix: `fix/`, `feature/`, `ui/`, `docs/`.
- Keep commits focused. Imperative subjects ("Keep working pair on bad input").
- Open a pull request against `main` using the PR template.

## Required checks

```bash
monkeyc -f monkey.jungle -d instinct3solar45mm -o bin/test.prg -y developer_key.der -t
monkeydo bin/test.prg instinct3solar45mm /t            # all PASS
monkeyc -f monkey.jungle -d <each device> -o bin/z.prg -y developer_key.der -r
python -I tools/check-secrets.py                       # also runs in CI
```

Run the tests on Solar 45 at least: it has the smallest memory and the tightest watchdog.

## Guidelines

- **No permissions in the main build.** `manifest.xml` keeps `<iq:permissions/>` empty; CI fails
  otherwise. Network features go into a separate build (see `docs/ON_WATCH_LINKING.md`).
- **Never commit account data.** Only the public example account (`123456789012` / `2db764…`) may
  appear in tests, tools and docs. `secrets*.json`, `bin/` and `*.der` are ignored.
- **Watchdog first.** Anything in `onUpdate` must stay cheap on Solar 45. Encode once per 30 s step.
- **Test helpers are not tests.** Annotate test *functions* and test-only *constants* with
  `(:test)`; never annotate helper functions, or the runner calls them as tests.
- **Protocol constants live in `ZappkaProtocol.mc`** only.

## Reporting bugs / requesting features

Use the issue templates. For anything security-sensitive follow [`SECURITY.md`](SECURITY.md).
