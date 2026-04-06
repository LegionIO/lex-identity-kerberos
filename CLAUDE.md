# lex-identity-kerberos: Kerberos Identity Provider for LegionIO

**Repository Level 3 Documentation**
- **Parent (Level 2)**: `/Users/miverso2/rubymine/legion/extensions/CLAUDE.md`
- **Parent (Level 1)**: `/Users/miverso2/rubymine/legion/CLAUDE.md`

## Purpose

LegionIO identity provider extension that resolves the authenticated Kerberos principal from
`legion-crypt` into the unified identity provider contract. Does **not** duplicate GSSAPI or LDAP
logic — those live in `lex-kerberos`. This gem reads the already-resolved principal and provides
the contract interface for the identity pipeline.

**GitHub**: https://github.com/LegionIO/lex-identity-kerberos
**License**: MIT
**Version**: 0.1.0

## Architecture

```
Legion::Extensions::Identity::Kerberos
├── Identity                   # Provider contract implementation (resolve, provide_token, normalize, vault_auth)
└── Helpers/
    └── Resolver               # Principal extraction from Legion::Crypt.kerberos_principal
```

## File Map

| File | Purpose |
|------|---------|
| `lib/legion/extensions/identity/kerberos.rb` | Entry point; extends Core, declares identity_provider?/remote_invocable?/crypt_required? |
| `lib/legion/extensions/identity/kerberos/identity.rb` | Provider contract — resolve, provide_token, normalize, vault_auth, capabilities |
| `lib/legion/extensions/identity/kerberos/helpers/resolver.rb` | principal, extract_username, extract_realm, resolve_identity |
| `lib/legion/extensions/identity/kerberos/version.rb` | VERSION = '0.1.0' |

## Key Design Decisions

- Reads `Legion::Crypt.kerberos_principal` (set by `KerberosAuth` at boot in legion-crypt).
  No `gssapi` gem, no LDAP. Those stay in `lex-kerberos`.
- `provide_token` calls `Legion::Extensions::Kerberos::Helpers::Spnego.obtain_spnego_token`
  only when lex-kerberos is loaded — guarded with `defined?` + `respond_to?`.
- `canonical_name` regex: `^[a-z0-9][a-z0-9_-]*$` — no dots (AMQP word separator).
- All framework constants guarded with `defined?` checks (never hard-require optional gems).
- `vault_auth` returns nil — Phase 5 stub.

## Provider Contract Return Values

### `resolve` identity hash
```ruby
{
  canonical_name: 'miverso2',
  kind:           :human,
  source:         :kerberos,
  principal:      'miverso2@MS.DS.UHC.COM',
  realm:          'MS.DS.UHC.COM',
  groups:         []
}
```

Group lookup is `lex-identity-ldap`'s responsibility, not this gem's.

### `provide_token` Lease-like hash
```ruby
{
  provider:   :kerberos,
  credential: '<base64-spnego-token>',
  lease_id:   nil,
  expires_at: Time.now + (10 * 3600),
  renewable:  true,
  issued_at:  Time.now,
  metadata:   { realm: 'MS.DS.UHC.COM' }
}
```

## Dependencies

Hard (in gemspec):
- `legion-json` (>= 1.2.1)
- `legion-settings` (>= 1.3.14)

Optional (guarded, not in gemspec):
- `legion-crypt` — `Legion::Crypt.kerberos_principal`
- `lex-kerberos` — `Legion::Extensions::Kerberos::Helpers::Spnego#obtain_spnego_token`

## Testing

```bash
bundle install
bundle exec rspec     # specs across identity_spec.rb and helpers/resolver_spec.rb
bundle exec rubocop   # clean
```

---

**Maintained By**: Matthew Iverson (@Esity)
