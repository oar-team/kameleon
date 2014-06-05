complete -c kameleon -l help --description "Describe available commands or one specific command" \
         -a 'help new templates version build checkpoints clear'

complete -c kameleon -l build --description "Builds the appliance from the recipe"
complete -c kameleon -l clear --description "Cleaning out context and removing all checkpoints"
complete -c kameleon -l checkpoints --description "Describe available commands or one specific command"
complete -c kameleon -l version --description "Prints the Kameleon's version information"
complete -c kameleon -l new --description "Creates a new recipe"
complete -c kameleon -l templates --description "Lists all defined templates"
