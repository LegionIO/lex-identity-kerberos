# Changelog

## [Unreleased]

## [0.2.0] - 2026-04-24

### Added
- `trust_level` method returning `:verified` on provider contract
- Self-registration with `Legion::Identity::Resolver` at load time (with pending_registrations fallback)

### Changed
- `trust_weight` changed from 50 to 30 (wins tiebreak over Entra at same priority)

## [0.1.1] - 2026-04-06

### Fixed
- `provide_token` now returns `Legion::Identity::Lease` instead of plain Hash, fixing `NoMethodError` in `LeaseRenewer#renew`

## [0.1.0] - 2026-04-06

### Added
- Initial release of lex-identity-kerberos
- `Identity` module implementing the unified LegionIO identity provider contract
- `Helpers::Resolver` for principal extraction from `Legion::Crypt.kerberos_principal`
- `resolve` returns canonical identity hash `{ canonical_name:, kind:, source:, principal:, realm:, groups: }`
- `normalize` strips `@REALM`, downcases, removes non-word characters (no dots)
- `provide_token` delegates to `lex-kerberos` SPNEGO helper when available, returns Lease-like hash
- `vault_auth` stub for Phase 5
- All framework dependencies guarded with `defined?` checks
- No `gssapi` or `net-ldap` dependency — reads already-resolved principal from `legion-crypt`
