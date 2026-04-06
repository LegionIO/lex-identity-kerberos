# frozen_string_literal: true

module Legion
  module Extensions
    module Identity
      module Kerberos
        module Helpers
          module Resolver
            module_function

            # Returns the raw Kerberos principal string (e.g. "miverso2@MS.DS.UHC.COM")
            # from Legion::Crypt if available, or nil.
            def principal
              return nil unless defined?(Legion::Crypt)
              return nil unless Legion::Crypt.respond_to?(:kerberos_principal)

              Legion::Crypt.kerberos_principal
            end

            # Extracts the username portion (before @REALM) from a principal string.
            def extract_username(principal_str)
              str = principal_str.to_s
              return str if str.empty?

              str.split('@', 2).first || str
            end

            # Extracts the realm portion (after @) from a principal string, or nil.
            def extract_realm(principal_str)
              parts = principal_str.to_s.split('@', 2)
              parts.length > 1 ? parts.last : nil
            end

            # Returns a resolved identity hash or nil when no principal is available.
            def resolve_identity
              raw = principal
              return nil if raw.nil? || raw.empty?

              username = extract_username(raw)
              realm    = extract_realm(raw)

              canonical = username.downcase.strip.gsub(/[^a-z0-9_-]/, '')
              return nil if canonical.empty?

              {
                canonical_name: canonical,
                kind:           :human,
                source:         :kerberos,
                principal:      raw,
                realm:          realm,
                groups:         []
              }
            end
          end
        end
      end
    end
  end
end
