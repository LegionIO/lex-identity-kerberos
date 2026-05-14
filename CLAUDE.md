# lex-identity-kerberos

LegionIO identity provider that resolves the authenticated Kerberos principal from `legion-crypt` into the unified identity provider contract. Does **not** duplicate GSSAPI or LDAP logic — those live in `lex-kerberos`. This gem reads the already-resolved principal and provides the contract interface.

## Key Design Decisions

- Reads `Legion::Crypt.kerberos_principal` (set by `KerberosAuth` at boot). No `gssapi` gem, no LDAP.
- `provide_token` delegates to `lex-kerberos` `Helpers::Spnego.obtain_spnego_token` — guarded with `defined?` + `respond_to?`.
- `canonical_name` regex: `^[a-z0-9][a-z0-9_-]*$` — no dots (AMQP word separator).
- `vault_auth` returns nil — Phase 5 stub.
- Group lookup is `lex-identity-ldap`'s responsibility, not this gem's.

## Provider Contract

```ruby
{ canonical_name: 'user', kind: :human, source: :kerberos, principal: 'user@REALM', realm: 'REALM', groups: [] }
```

`provide_token` returns `Legion::Identity::Lease` (or plain Hash fallback if Lease not defined).
