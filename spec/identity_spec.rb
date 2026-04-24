# frozen_string_literal: true

require 'spec_helper'

# Legion::Identity::Lease lives in the legionio gem (not a dependency of this extension).
# Require it if available, otherwise define a minimal version for spec assertions.
begin
  require 'legion/identity/lease'
rescue LoadError
  module Legion
    module Identity
      class Lease
        attr_reader :provider, :credential, :lease_id, :expires_at, :renewable, :issued_at, :metadata

        def initialize(provider:, credential:, lease_id: nil, expires_at: nil, renewable: false, issued_at: nil, metadata: {})
          @provider = provider
          @credential = credential
          @lease_id = lease_id
          @expires_at = expires_at
          @renewable = renewable
          @issued_at = issued_at || Time.now
          @metadata = metadata.freeze
        end

        def valid?
          !credential.nil? && !expired?
        end

        def expired?
          return false if expires_at.nil?

          Time.now >= expires_at
        end
      end
    end
  end
end

RSpec.describe Legion::Extensions::Identity::Kerberos::Identity do
  subject(:identity) { described_class }

  # ---- Provider contract interface ----

  describe '.provider_name' do
    it 'returns :kerberos' do
      expect(identity.provider_name).to eq(:kerberos)
    end
  end

  describe '.provider_type' do
    it 'returns :auth' do
      expect(identity.provider_type).to eq(:auth)
    end
  end

  describe '.facing' do
    it 'returns :human' do
      expect(identity.facing).to eq(:human)
    end
  end

  describe '.priority' do
    it 'returns 100' do
      expect(identity.priority).to eq(100)
    end
  end

  describe '.trust_weight' do
    it 'returns 30' do
      expect(identity.trust_weight).to eq(30)
    end
  end

  describe '.trust_level' do
    it 'returns :verified for trust_level' do
      expect(identity.trust_level).to eq(:verified)
    end
  end

  describe '.capabilities' do
    it 'includes :authenticate, :profile, :vault_auth, :outbound_auth' do
      expect(identity.capabilities).to include(:authenticate, :profile, :vault_auth, :outbound_auth)
    end
  end

  # ---- resolve ----

  describe '.resolve' do
    context 'when Legion::Crypt is not defined' do
      it 'returns nil' do
        hide_const('Legion::Crypt')
        expect(identity.resolve).to be_nil
      end
    end

    context 'when Legion::Crypt does not respond to kerberos_principal' do
      before do
        stub_const('Legion::Crypt', Module.new)
      end

      it 'returns nil' do
        expect(identity.resolve).to be_nil
      end
    end

    context 'when Legion::Crypt.kerberos_principal returns nil' do
      before do
        crypt = Module.new { def self.kerberos_principal = nil }
        stub_const('Legion::Crypt', crypt)
      end

      it 'returns nil' do
        expect(identity.resolve).to be_nil
      end
    end

    context 'when Legion::Crypt.kerberos_principal returns a full principal' do
      before do
        crypt = Module.new { def self.kerberos_principal = 'miverso2@MS.DS.UHC.COM' }
        stub_const('Legion::Crypt', crypt)
      end

      it 'returns an identity hash' do
        result = identity.resolve
        expect(result).to be_a(Hash)
      end

      it 'sets canonical_name to the downcased username' do
        expect(identity.resolve[:canonical_name]).to eq('miverso2')
      end

      it 'sets kind to :human' do
        expect(identity.resolve[:kind]).to eq(:human)
      end

      it 'sets source to :kerberos' do
        expect(identity.resolve[:source]).to eq(:kerberos)
      end

      it 'preserves the full principal' do
        expect(identity.resolve[:principal]).to eq('miverso2@MS.DS.UHC.COM')
      end

      it 'extracts the realm' do
        expect(identity.resolve[:realm]).to eq('MS.DS.UHC.COM')
      end

      it 'sets groups to an empty array' do
        expect(identity.resolve[:groups]).to eq([])
      end
    end

    context 'when principal has no realm' do
      before do
        crypt = Module.new { def self.kerberos_principal = 'localuser' }
        stub_const('Legion::Crypt', crypt)
      end

      it 'sets realm to nil' do
        expect(identity.resolve[:realm]).to be_nil
      end

      it 'sets canonical_name correctly' do
        expect(identity.resolve[:canonical_name]).to eq('localuser')
      end
    end
  end

  # ---- normalize ----

  describe '.normalize' do
    it 'strips @REALM and downcases' do
      expect(identity.normalize('miverso2@MS.DS.UHC.COM')).to eq('miverso2')
    end

    it 'downcases a name without realm' do
      expect(identity.normalize('MIVERSO2')).to eq('miverso2')
    end

    it 'strips leading and trailing whitespace' do
      expect(identity.normalize('  miverso2  ')).to eq('miverso2')
    end

    it 'removes special characters' do
      expect(identity.normalize('user.name@REALM.COM')).to eq('username')
    end

    it 'preserves hyphens and underscores' do
      expect(identity.normalize('user_name-ok@REALM')).to eq('user_name-ok')
    end

    it 'handles nil-like values via to_s' do
      expect(identity.normalize(nil)).to eq('')
    end

    it 'handles symbol input' do
      expect(identity.normalize(:alice)).to eq('alice')
    end
  end

  # ---- vault_auth ----

  describe '.vault_auth' do
    it 'returns nil (Phase 5 stub)' do
      expect(identity.vault_auth).to be_nil
    end
  end

  # ---- provide_token ----

  describe '.provide_token' do
    context 'when lex-kerberos Spnego is not available' do
      it 'returns nil' do
        hide_const('Legion::Extensions::Kerberos')
        expect(identity.provide_token).to be_nil
      end
    end

    context 'when Spnego is available and obtain_spnego_token succeeds' do
      let(:fake_token) { 'YWJjZGVm' }
      let(:spnego_result) { { success: true, token: fake_token } }
      let(:spnego_mod) do
        Module.new do
          def self.obtain_spnego_token(**)
            { success: true, token: 'YWJjZGVm' }
          end
        end
      end

      before do
        helpers_mod = Module.new
        kerberos_mod = Module.new
        kerberos_mod.const_set(:Helpers, helpers_mod)
        helpers_mod.const_set(:Spnego, spnego_mod)

        extensions_mod = Module.new
        extensions_mod.const_set(:Kerberos, kerberos_mod)
        stub_const('Legion::Extensions::Kerberos', kerberos_mod)

        crypt = Module.new { def self.kerberos_principal = 'miverso2@MS.DS.UHC.COM' }
        stub_const('Legion::Crypt', crypt)

        settings = Module.new do
          def self.[](key)
            { service_principal: 'HTTP/vault.example.com' } if key == :kerberos
          end
        end
        stub_const('Legion::Settings', settings)
      end

      it 'returns a Legion::Identity::Lease' do
        result = identity.provide_token
        expect(result).to be_a(Legion::Identity::Lease)
      end

      it 'sets provider to :kerberos' do
        expect(identity.provide_token.provider).to eq(:kerberos)
      end

      it 'sets credential to the token string' do
        expect(identity.provide_token.credential).to eq(fake_token)
      end

      it 'sets lease_id to nil' do
        expect(identity.provide_token.lease_id).to be_nil
      end

      it 'sets renewable to true' do
        expect(identity.provide_token.renewable).to be true
      end

      it 'sets expires_at approximately 10 hours from now' do
        result = identity.provide_token
        expect(result.expires_at).to be_within(5).of(Time.now + (10 * 3600))
      end

      it 'includes realm in metadata' do
        expect(identity.provide_token.metadata[:realm]).to eq('MS.DS.UHC.COM')
      end

      it 'reports as valid' do
        expect(identity.provide_token.valid?).to be true
      end
    end

    context 'when obtain_spnego_token returns failure' do
      let(:spnego_mod) do
        Module.new do
          def self.obtain_spnego_token(**)
            { success: false, error: 'No credentials cache' }
          end
        end
      end

      before do
        helpers_mod = Module.new
        kerberos_mod = Module.new
        kerberos_mod.const_set(:Helpers, helpers_mod)
        helpers_mod.const_set(:Spnego, spnego_mod)
        stub_const('Legion::Extensions::Kerberos', kerberos_mod)

        settings = Module.new do
          def self.[](key)
            { service_principal: 'HTTP/vault.example.com' } if key == :kerberos
          end
        end
        stub_const('Legion::Settings', settings)
      end

      it 'returns nil' do
        expect(identity.provide_token).to be_nil
      end
    end
  end
end
