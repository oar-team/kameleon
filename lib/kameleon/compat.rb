require 'securerandom'
require 'yaml'

# Fast and backwards compatible YAML with Syck
# Snippet from http://developer.zendesk.com/blog/2013/10/03/using-syck-for-yaml/
if RUBY_VERSION >= "1.9.3"
  require 'syck'
  # to force yaml to dump ASCII-8Bit strings as strings
  YAML::ENGINE.yamler = 'syck'
  engine = YAML::ENGINE

  def engine.yamler=(value)
    return if value == 'syck'
    raise ArgumentError, "Already using Syck, cannot change to #{value}"
  end

  # Disable Psych in Rubygems
  ENV['TEST_SYCK'] = 'true'
end

# force UTF-8 on all strings back from YAML.
class << YAML::DefaultResolver
  alias_method :node_import_without_utf8, :node_import

  def node_import(node)
    val = node_import_without_utf8(node)
    val.force_encoding("UTF-8") if val.respond_to?(:force_encoding)
    val
  end
end

if RUBY_VERSION < "1.9.3"
  # Backport of missing SecureRandom methods from 1.9
  # Snippet from http://softover.com/UUID_in_Ruby_1.8
  module SecureRandom
    class << self
      def method_missing(method_sym, *arguments, &block)
        case method_sym
        when :urlsafe_base64
          r19_urlsafe_base64(*arguments)
        when :uuid
          r19_uuid(*arguments)
        else
          super
        end
      end

      private
      def r19_urlsafe_base64(n=nil, padding=false)
        s = [random_bytes(n)].pack("m*")
        s.delete!("\n")
        s.tr!("+/", "-_")
        s.delete!("=") if !padding
        s
      end

      def r19_uuid
        ary = random_bytes(16).unpack("NnnnnN")
        ary[2] = (ary[2] & 0x0fff) | 0x4000
        ary[3] = (ary[3] & 0x3fff) | 0x8000
        "%08x-%04x-%04x-%04x-%04x%08x" % ary
      end
    end
  end
end
