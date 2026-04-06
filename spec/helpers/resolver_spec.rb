# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Identity::Kerberos::Helpers::Resolver do
  subject(:resolver) { described_class }

  describe '.principal' do
    context 'when Legion::Crypt is not defined' do
      it 'returns nil' do
        hide_const('Legion::Crypt')
        expect(resolver.principal).to be_nil
      end
    end

    context 'when Legion::Crypt does not respond to kerberos_principal' do
      before { stub_const('Legion::Crypt', Module.new) }

      it 'returns nil' do
        expect(resolver.principal).to be_nil
      end
    end

    context 'when Legion::Crypt.kerberos_principal returns a value' do
      before do
        crypt = Module.new { def self.kerberos_principal = 'miverso2@MS.DS.UHC.COM' }
        stub_const('Legion::Crypt', crypt)
      end

      it 'returns the principal string' do
        expect(resolver.principal).to eq('miverso2@MS.DS.UHC.COM')
      end
    end
  end

  describe '.extract_username' do
    it 'returns the portion before @' do
      expect(resolver.extract_username('miverso2@MS.DS.UHC.COM')).to eq('miverso2')
    end

    it 'returns the full string when no realm present' do
      expect(resolver.extract_username('localuser')).to eq('localuser')
    end

    it 'handles nil-like values via to_s' do
      expect(resolver.extract_username(nil)).to eq('')
    end
  end

  describe '.extract_realm' do
    it 'returns the realm portion after @' do
      expect(resolver.extract_realm('miverso2@MS.DS.UHC.COM')).to eq('MS.DS.UHC.COM')
    end

    it 'returns nil when no @ is present' do
      expect(resolver.extract_realm('localuser')).to be_nil
    end

    it 'handles nil-like values via to_s' do
      expect(resolver.extract_realm(nil)).to be_nil
    end
  end

  describe '.resolve_identity' do
    context 'when no principal is available' do
      before do
        allow(resolver).to receive(:principal).and_return(nil)
      end

      it 'returns nil' do
        expect(resolver.resolve_identity).to be_nil
      end
    end

    context 'when principal is an empty string' do
      before do
        allow(resolver).to receive(:principal).and_return('')
      end

      it 'returns nil' do
        expect(resolver.resolve_identity).to be_nil
      end
    end

    context 'when a valid principal is available' do
      before do
        allow(resolver).to receive(:principal).and_return('miverso2@MS.DS.UHC.COM')
      end

      it 'returns a hash' do
        expect(resolver.resolve_identity).to be_a(Hash)
      end

      it 'sets canonical_name to the lowercased username' do
        expect(resolver.resolve_identity[:canonical_name]).to eq('miverso2')
      end

      it 'sets kind to :human' do
        expect(resolver.resolve_identity[:kind]).to eq(:human)
      end

      it 'sets source to :kerberos' do
        expect(resolver.resolve_identity[:source]).to eq(:kerberos)
      end

      it 'preserves the full principal' do
        expect(resolver.resolve_identity[:principal]).to eq('miverso2@MS.DS.UHC.COM')
      end

      it 'extracts the realm' do
        expect(resolver.resolve_identity[:realm]).to eq('MS.DS.UHC.COM')
      end

      it 'returns an empty groups array (no LDAP lookup in this gem)' do
        expect(resolver.resolve_identity[:groups]).to eq([])
      end
    end

    context 'when canonical_name would be empty after sanitization' do
      before do
        allow(resolver).to receive(:principal).and_return('...@REALM.COM')
      end

      it 'returns nil' do
        expect(resolver.resolve_identity).to be_nil
      end
    end
  end
end
