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

  ### helper functions for output colorizing
  def colorize(text, color_code)
    "#{color_code}#{text}\e[0m"
  end

  def red(text); colorize(text, "\e[31m\e[1m"); end
  def green(text); colorize(text, "\e[32m\e[1m"); end
  def blue(text); colorize(text, "\e[34m\e[1m"); end
  def cyan(text); colorize(text, "\e[36m"); end
end
