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

Status: 17/17 simulator tests on all three devices.

## v1.0.0

Same code and binaries as `v1.0.0-rc1`. In daily use at Zabka checkouts on Instinct 3 AMOLED 45.

## v1.1.0-rc1

commit `2b873a4`, SDK `connectiq-sdk-win-9.1.0-2026-03-09-6a872a80b`

| device | sha256 | bytes |
|---|---|---|
| instinct3solar45mm | `122506fc4925365dcb6f6549809a51abcc6c98a724a2e078049aac8939301710` | 22668 |
| instinct3amoled45mm | `a96a326c2c68de0d874130ba16271cf9f25cbabbce1dd6fa875621676baeae06` | 28876 |
| instinct3amoled50mm | `a96a326c2c68de0d874130ba16271cf9f25cbabbce1dd6fa875621676baeae06` | 28876 |

Status: 26/26 simulator tests on all three devices. Superseded by rc2.

## v1.1.0-rc2

commit `7de345e`, SDK `connectiq-sdk-win-9.1.0-2026-03-09-6a872a80b`. Every build passed `tools/check-build.py`.

| device | sha256 | bytes |
|---|---|---|
| instinct3solar45mm | `1affae90c2c2d33021c52455670da8bae8f603ffd97fbc9b815a22ccc6f79058` | 23852 |
| instinct3amoled45mm | `90f44f0eb686751b06d371eb08d7d66030b1df43f43083fb486034928da34ef6` | 30060 |
| instinct3amoled50mm | `90f44f0eb686751b06d371eb08d7d66030b1df43f43083fb486034928da34ef6` | 30060 |

Status: 33/33 simulator tests on all three devices. Menu and account-change confirmation to be checked on the watch before `v1.1.0`.
