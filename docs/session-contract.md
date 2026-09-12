# Session boundary contract

Decision record for [fieldsofrevik#155](https://github.com/aviorstudio/fieldsofrevik/issues/155), selected 2026-09-12.

- Keep the Supabase and PocketBase adapters as independent implementations with matching externally tested behavior (D-06); no shared source dependency is introduced.
- Session operations return typed result classes so callers can distinguish success, non-persistent memory mode, invalid stored data, unavailable adapters, and failed migration/write/readback.
- Native persistence requires a caller-injected credential-store adapter. Without one, the safe default is memory-only and is reported as non-persistent; plaintext files are never a fallback.
- Web persistence defaults to memory. A caller may explicitly select `sessionStorage`, which is script-accessible browser storage and is not described as a secure keystore. `localStorage` is not used for sessions.
- Existing plaintext legacy files are read only for an explicit migration into an injected credential adapter. Source data is retained unless and until destination write and readback both succeed; this release does not destructively remove legacy data (D-08).
- Client IDs are not authentication. Native client IDs continue to use `OS.get_unique_id()` with documented platform/privacy limitations. Web client IDs use memory by default with explicit `sessionStorage` opt-in and safe JavaScript object calls.
- Decoded JWT claims are unverified hints only. They cannot establish identity, authorization, issuer/audience trust, or signature validity. Expiry has typed valid, expired, and invalid/unknown outcomes.

Concrete methods and statuses must preserve these decisions and are covered by native and Web contract tests in the behavior layer.
