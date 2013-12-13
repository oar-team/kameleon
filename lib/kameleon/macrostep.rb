require 'kameleon/recipe'

module Kameleon
  class Macrostep
    attr_accessor :path
    def initialize(path, options)
      @variables = {}
      @path = path
      @name = File.basename path, ".yaml"
      @microsteps = YAML.load_file(path)
      if not @microsteps.kind_of? Array
        fail Error, "The macrostep #{path} is not valid (should be a list of microsteps)" 
      end

      # look for microstep selection in option
      if options
        selected_microsteps = []
        options.each do |entry|
          if entry.kind_of? String
            selected_microsteps.push entry
          elsif entry.kind_of? Hash
            @variables.merge! entry
          end
        end
        if selected_microsteps
          # Some steps are selected so remove the others
          # WARN: Allow the user to define this list not in the original order
          strip_macrostep = []
          selected_microsteps.each do |microstep_name|
            strip_macrostep.push(find_microstep(microstep_name))
          end
          @microsteps = strip_macrostep
        end
      end
    end
    
    # :return: the microstep in this macrostep by name
    def find_microstep(microstep_name)
      @microsteps.each do |microstep| 
        if microstep_name.eql? microstep.keys[0] 
          return microstep
        end
      end
      fail Error ,"Can't find microstep \"#{microstep_name}\" in macrostep \"#{@name}\""
    end
    
    # Resolve macrosteps variable
    def resolve()
      #TODO
    end

  end
end

