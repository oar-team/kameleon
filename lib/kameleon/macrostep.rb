require 'kameleon/recipe'

module Kameleon
  class Macrostep
    def initialize(step_path, options)
      @variables = []
      @macrostep = YAML.load_file(path)
      if not macrostep.kind_of? Array
        fail Error, "The macrostep #{path} is not valid (should be a list of microsteps)" 
      end

      # look for microstep selection in option
      options.each do |entry|
        if entry.kind_of? String
          selected_microsteps.push entry
        elsif entry.kind_of? Hash
          @variables.push entry
        end
      end
      if selected_microsteps
        # Some steps are selected so remove the others
        # WARN: Allow the user to define this list not in the original order
        selected_microsteps.each do |microstep_name|
          strip_macrostep.push(find_microstep(microstep_name))
        end
        @macrostep = strip_macrostep
      end
    end

    # :return: index of the microstep in this macrostep
    def find_microstep(microstep_name)
      
    end

  end
end

