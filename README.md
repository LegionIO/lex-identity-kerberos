# lex-identity-kerberos

LegionIO identity provider extension for Kerberos. Implements the unified identity provider contract
by reading the authenticated Kerberos principal from `legion-crypt` and resolving it into a
canonical identity hash.

## Overview

This gem does **not** duplicate GSSAPI or LDAP logic. It reads the principal that was already
resolved by `legion-crypt`'s `KerberosAuth` at boot time. For outbound SPNEGO token acquisition,
it delegates to `lex-kerberos`'s `Helpers::Spnego#obtain_spnego_token` when that gem is loaded.

## Provider Contract

```ruby
Legion::Extensions::Identity::Kerberos::Identity.provider_name   # => :kerberos
Legion::Extensions::Identity::Kerberos::Identity.provider_type   # => :auth
Legion::Extensions::Identity::Kerberos::Identity.facing          # => :human
Legion::Extensions::Identity::Kerberos::Identity.priority        # => 100
Legion::Extensions::Identity::Kerberos::Identity.trust_weight    # => 50
Legion::Extensions::Identity::Kerberos::Identity.capabilities
# => [:authenticate, :profile, :vault_auth, :outbound_auth]
```

### `resolve`

Returns an identity hash or `nil`:

```ruby
{
  canonical_name: 'miverso2',          # ^[a-z0-9][a-z0-9_-]*$ — no dots (AMQP word separator)
  kind:           :human,
  source:         :kerberos,
  principal:      'miverso2@MS.DS.UHC.COM',
  realm:          'MS.DS.UHC.COM',
  groups:         []                   # group lookup is lex-identity-ldap's responsibility
}
```

Returns `nil` when no Kerberos principal is available.

### `normalize(val)`

Strips `@REALM`, downcases, trims whitespace, and removes characters outside `[a-z0-9_-]`:

```ruby
Identity.normalize('User.Name@REALM.COM')  # => 'username'
Identity.normalize('miverso2@MS.DS.UHC.COM')  # => 'miverso2'
```

### `provide_token`

Returns a Lease-like hash with a SPNEGO token (10-hour validity), or `nil` on failure:

```ruby
{
  provider:   :kerberos,
  credential: '<base64-spnego-token>',
  lease_id:   nil,
  expires_at: <Time 10h from now>,
  renewable:  true,
  issued_at:  <Time.now>,
  metadata:   { realm: 'MS.DS.UHC.COM' }
}
```

Requires `lex-kerberos` to be loaded and `Legion::Settings[:kerberos][:service_principal]` to be set.

### `vault_auth`

Stub returning `nil`. Phase 5 implementation pending.

## Dependencies

Required:
- `legion-json` (>= 1.2.1)
- `legion-settings` (>= 1.3.14)

Optional (guarded with `defined?`):
- `legion-crypt` — for `Legion::Crypt.kerberos_principal`
- `lex-kerberos` — for `Legion::Extensions::Kerberos::Helpers::Spnego#obtain_spnego_token`

## Installation

Add to your `Gemfile`:

```ruby
gem 'lex-identity-kerberos'
```

## License

MIT
