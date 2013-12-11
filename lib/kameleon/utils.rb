module Kameleon
  ### Hash that keeps elements in the insertion order -- it's more
  ### convenient for storing macrostep->microstep->comand structure
  class OrderedHash < Hash
    def initialize
      @key_list = []
      super
    end
    def []=(key, value)
      if has_key?(key)
        super(key, value)
      else
        @key_list.push(key)
        super(key, value)
      end
    end

    def by_index(index)
      self[@key_list[index]]
    end

    def each
      @key_list.each do |key|
        yield( [key, self[key]] )
      end
    end

    def delete(key)
      @key_list = @key_list.delete_if { |x| x == key }
      super(key)
    end
  end
end
