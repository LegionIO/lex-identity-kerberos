# frozen_string_literal: true

require 'legion/extensions/identity/kerberos/version'
require 'legion/extensions/identity/kerberos/helpers/resolver'
require 'legion/extensions/identity/kerberos/identity'

module Legion
  module Extensions
    module Identity
      module Kerberos
        extend Legion::Extensions::Core if Legion::Extensions.const_defined?(:Core, false)

        def self.identity_provider? = true
        def self.remote_invocable?  = false
        def self.crypt_required?    = true
      end
    end
  end
end
