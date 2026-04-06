# frozen_string_literal: true

require 'legion/extensions/identity/kerberos/helpers/resolver'

module Legion
  module Extensions
    module Identity
      module Kerberos
        module Identity
          extend self

          def provider_name  = :kerberos
          def provider_type  = :auth
          def facing         = :human
          def priority       = 100
          def trust_weight   = 50
          def capabilities   = %i[authenticate profile vault_auth outbound_auth]

          # Returns a resolved identity hash or nil when no Kerberos principal is available.
          #
          # Hash shape:
          #   { canonical_name:, kind: :human, source: :kerberos, principal:, realm:, groups: [] }
          #
          # canonical_name regex: ^[a-z0-9][a-z0-9_-]*$ (no dots — AMQP word separator)
          def resolve
            Helpers::Resolver.resolve_identity
          end

          # Returns a Lease-like hash carrying the SPNEGO outbound token, or nil on failure.
          #
          # Delegates to lex-kerberos Helpers::Spnego#obtain_spnego_token when available.
          # Returns nil when lex-kerberos is not loaded or token acquisition fails.
          def provide_token
            return nil unless spnego_available?

            service_principal = spnego_service_principal
            return nil if service_principal.nil? || service_principal.empty?

            result = Legion::Extensions::Kerberos::Helpers::Spnego.obtain_spnego_token(
              service_principal: service_principal
            )
            return nil unless result.is_a?(Hash) && result[:success]

            realm = Helpers::Resolver.extract_realm(Helpers::Resolver.principal.to_s)

            {
              provider:    :kerberos,
              credential:  result[:token],
              lease_id:    nil,
              expires_at:  Time.now + (10 * 3600),
              renewable:   true,
              issued_at:   Time.now,
              metadata:    { realm: realm }
            }
          rescue StandardError
            nil
          end

          # Strips @REALM, downcases, strips whitespace, removes non-word chars (no dots).
          def normalize(val)
            val.to_s.split('@', 2).first.downcase.strip.gsub(/[^a-z0-9_-]/, '')
          end

          # Stub for Phase 5 Vault auth delegation. Returns nil.
          def vault_auth
            nil
          end

          private

          def spnego_available?
            defined?(Legion::Extensions::Kerberos::Helpers::Spnego) &&
              Legion::Extensions::Kerberos::Helpers::Spnego.respond_to?(:obtain_spnego_token)
          end

          def spnego_service_principal
            return nil unless defined?(Legion::Settings)

            Legion::Settings[:kerberos]&.dig(:service_principal)
          rescue StandardError
            nil
          end
        end
      end
    end
  end
end
