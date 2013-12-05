require 'log4r'
require 'kameleon/recipe'
require 'kameleon/shell'
require 'kameleon/error'


module Kameleon
  class Engine
    def initialize(options)
      @options = options
      @logger = Log4r::Logger.new("kameleon::engine")
      @recipe = Recipe.new(@options[:recipe_query], @options[:include_paths])
      @local_shell = BasicShell.new
      container = @recipe.global['container']
      case container
      when nil
        @container_shell = BasicShell.new
      when :kvm
        @container_shell = RemoteShell.new
      when :chroot
        @container_shell = ChrootShell.new
      else
        raise Error::InternalError.new("Invalid container value: #{container}")
      end
    end

    def clean(signal)

    end

    def run
      @logger.info('starting kameleon')
      @logger.warn('fake warning')
      @logger.error('fake error')
      begin
        @recipe.macrosteps.each do |macrostep|
          macrostep.each do |microstep|
            microstep.each do |cmd|
              case cmd.key
              when :exec
                @container_shell.exec(cmd.value)
              when :exec_local
                @local_shell.exec(cmd.value)
              else
                raise Error::InternalError.new(
                  "Invalid container value: #{container}")
              end
            end
          end
        end
      rescue Exception => e
        @logger.error("An error occured : #{e}")
      end
    end
  end

  ### function for converting command definitions into bash commands
  def cmd_parse(cmd,step)
    if cmd.keys[0]=="check_cmd"
      #TODO check if the command exists before starting the script
      make_exec_current( "which " + cmd.values[0] + " >/dev/null" )
    elsif cmd.keys[0]=="check_cmd_chroot"
      make_exec_chroot( " which " + cmd.values[0] )
    elsif cmd.keys[0]=="exec_current"
      make_exec_current( cmd.values[0] )
    elsif cmd.keys[0]=="exec_appliance"
      make_exec_appliance( cmd.values[0] )
    elsif cmd.keys[0]=="exec_chroot"
      make_exec_chroot( cmd.values[0] )
    elsif cmd.keys[0]=="append_file"
      return "echo \"" + cmd.values[0][1] + "\" >> " + $chroot + "/" + cmd.values[0][0]
    elsif cmd.keys[0]=="write_file"
      return "echo \"" + cmd.values[0][1] + "\" > " + $chroot + "/" + cmd.values[0][0]
    elsif cmd.keys[0]=="erb_config"
      return "ERB-config,#{cmd.values[0][0]},#{cmd.values[0][1]}"
    elsif cmd.keys[0]=="breakpoint"
      return "KML-breakpoint " + cmd.values[0]
    elsif cmd.keys[0]=="exec_ctxt" || cmd.keys[0]=="exec_context"
      return context_parse(cmd.values[0])
    elsif cmd.keys[0]=="exec_on_clean"
      return "Clean-command,#{cmd.values[0]}"
    elsif cmd.keys[0]=="on_clean"
      output=[]
      cmd.values.each do |clean_entry|
        clean_entry.each do |entry|
          entry.each do |clean_cmd,val|
            if clean_cmd == "exec_current"

            elsif clean_cmd == "exec_appliance"
              output << "echo \"" + "cd " + $chroot + "; " + val + "\" > " + $clean_script + ".rev; cat " + $clean_script + ">> " + $clean_script + ".rev; mv -f " + $clean_script + ".rev " + $clean_script
            elsif clean_cmd == "exec_chroot"
              output << "echo \"" + "chroot " + $chroot + " " + val + "\" > " + $clean_script + ".rev; cat " + $clean_script + ">> " + $clean_script + ".rev; mv -f " + $clean_script + ".rev " + $clean_script
            else
              printf("Step %s: no such on_clean command: %s\n", step, clean_cmd)
              exit(9)
            end
          end
        end
      end
      return output.join(';')
    else
      printf("Step %s: no such command %s\n", step, cmd.keys[0])
      exit(9)
    end
  end

  # # Global variables parsing
  # def var_parse(str, path)
  #   str.gsub(/\$\$[a-zA-Z0-9\-_]*/) do
  #     |c|
  #     if $recipe['global'][c[2,c.length]]
  #       c=$recipe['global'][c[2,c.length]]
  #     else
  #       printf("%s: variable %s not found in [global] array\n", path, c)
  #       exit(6)
  #     end
  #     return $` + c + var_parse($', path)
  #   end
  # end


  # # Context parsing
  # def context_parse(str)
  #   str.gsub(/^\w+/) do
  #     |context|
  #     unless $recipe['contexts']
  #       printf("Missing [contexts] array into recipe\n")
  #       exit(6)
  #     end
  #     if $recipe['contexts'][context]
  #       if $recipe['contexts'][context]['cmd']
  #         cmd=$recipe['contexts'][context]['cmd']
  #         args=$'.strip
  #       else
  #         printf("cmd not found in [contexts][%s] array\n", context)
  #         exit(6)
  #       end
  #     else
  #       printf("context %s not found in [contexts] array\n", context)
  #       exit(6)
  #     end
  #     if $recipe['contexts'][context]['escape']
  #       escape=$recipe['contexts'][context]['escape']
  #       args=args.gsub(/[#{escape}]/,"\\\\#{escape}")
  #     end
  #     cmd="chroot," + cmd.gsub(/%%/, args)
  #     return cmd

  #   end
  # end
end
