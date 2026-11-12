# Releases

Builds are signed with the developer key, which is never in the repository. Hashes are of the
`.prg` produced by `tools/release.sh`.

## v0.9-checkout-2026-10-08

Code accepted at a real Żabka checkout on Instinct 3 AMOLED 45 (2026-10-08) and in daily use since.
The binary used then was not recorded.

## v1.0.0-rc1

commit `0a57b52`, SDK `connectiq-sdk-win-9.1.0-2026-03-09-6a872a80b`

| device | sha256 | bytes |
|---|---|---|
| instinct3solar45mm | `4d1bd68ce06d3611b1af614cc1894f81b8ec98e5a430d6467df49fa7dd5c5e6e` | 19564 |
| instinct3amoled45mm | `a8649a39cad4e176461e96bde67523b2b381a7c511fd6819aeba43f34cf317d8` | 25772 |
| instinct3amoled50mm | `a8649a39cad4e176461e96bde67523b2b381a7c511fd6819aeba43f34cf317d8` | 25772 |

Status: 17/17 simulator tests on all three devices. To be re-checked at a checkout before `v1.0.0`.
