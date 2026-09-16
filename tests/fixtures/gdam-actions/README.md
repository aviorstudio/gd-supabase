# Immutable upstream publication contract

These unmodified files are from `aviorstudio/gdam-actions` commit
`d735444eb470194585def44521d5d91df2260e63` (v0.0.2):

- https://github.com/aviorstudio/gdam-actions/blob/d735444eb470194585def44521d5d91df2260e63/install/action.yml
- https://github.com/aviorstudio/gdam-actions/blob/d735444eb470194585def44521d5d91df2260e63/publish/action.yml
- https://github.com/aviorstudio/gdam-actions/blob/d735444eb470194585def44521d5d91df2260e63/publish/publish.sh

`node scripts/check_publish_contract.mjs` verifies their SHA-256 identities and
checks all release GDAM action inputs against this metadata. Action upgrades
must update the fixtures, hashes, and tests together. The stub tests execute the
unaltered script with a disposable fake key and stub CLI on an isolated PATH;
they cannot publish or contact the registry. The CLI probe must receive no key,
legacy/unknown CLI shapes must fail closed, and the exact-tag path must pass
only addon, tag, and the explicit ZIP asset.

The release pins GDAM v0.0.8 (commit
`ac84c9c5b5d6845e0de8335c9d0c46552ad8b7db`). Its Linux x86_64 archive SHA-256 is
`7ef2a325ad1416ce850a332f4380b1b290bd7a56e2a20f544536386cf64abb92`, verified
against the release checksums and GitHub asset digest. The extracted executable
SHA-256, enforced after installation and before publication, is
`bf5d03baa94da905ca128a55c4acd6b0552c60127d53fc4d01ecaa8a377b0b53`.
This executable pin is intentionally Linux x86_64-specific (`ubuntu-latest`).
