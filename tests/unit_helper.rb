require File.expand_path("../base_helper", __FILE__)



if defined? SimpleCov
  SimpleCov.command_name 'unit'
end


module UnitExampleGroup
  def self.included(base)
    base.metadata[:type] = :unit
    base.before do
      Object.any_instance.stub(:system) { |*args, &block|
        UnitExampleGroup.prevent_system_calls(*args, &block)
      }
      Object.any_instance.stub(:`) { |*args, &block|
        UnitExampleGroup.prevent_system_calls(*args, &block)
      }
      Object.any_instance.stub(:exec) { |*args, &block|
        UnitExampleGroup.prevent_system_calls(*args, &block)
      }
      Object.any_instance.stub(:fork) { |*args, &block|
        UnitExampleGroup.prevent_system_calls(*args, &block)
      }
      Object.any_instance.stub(:spawn) { |*args, &block|
        UnitExampleGroup.prevent_system_calls(*args, &block)
      }
    end
  end

  def self.prevent_system_calls(*args, &block)
    args.pop if args.last.is_a?(Hash)

    raise <<-MSG
Somehow your code under test is trying to execute a command on your system,
please stub it out or move your spec code to an acceptance spec.

Block: #{block.inspect}
Command: "#{args.join(' ')}"
MSG
  end
end


RSpec.configure do |config|
  config.include RSpec::Fire

  config.include UnitExampleGroup, :type => :unit, :example_group => {
    :file_path => /\bspec\/unit\//
  }
end
