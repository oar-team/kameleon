function __fish_kameleon_using_command
  set cmd (commandline -opc)
  if [ (count $cmd) -gt 1 ]
    if [ $argv[1] = $cmd[2] ]
      return 0
    end
  end
  return 1
end

complete -f -c kameleon -a '(kameleon commands)'
complete -f -c kameleon -n '__fish_kameleon_using_command build' -a '(kameleon completions build)'
complete -f -c kameleon -n '__fish_kameleon_using_command clear' -a '(kameleon completions clear)'
complete -f -c kameleon -n '__fish_kameleon_using_command checkpoints' -a '(kameleon completions checkpoints)'
