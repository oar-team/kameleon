require 'securerandom'

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


class Object
  ##
  #   @person ? @person.name :nil
  # vs
  #   @person.try(:name)
  def try(method)
    send method if respond_to? method
  end
end

class Hash
  def self.try_convert(obj)
    obj.try(:to_hash)
  end

  def flatten
    to_a.flatten!
  end
end
