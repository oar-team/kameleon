#compdef kameleon

# This is ZSH completion script based on the kameleon 2.6.0.dev API
#
# Author: Michael Mercier
#
# This was made with the help of this howto:
# https://github.com/zsh-users/zsh-completions/blob/master/zsh-completions-howto.org

### Common pattern

local -a recipe_path
recipe_path=(/$'[^\0]##\0'/ ':file:kameleon recipe:_files -g "*.yaml"')

### Command options

local -a build_options
build_options=(/$'[^\0]##\0'/ "$recipe_path[@]")
#'-b:Sets the build directory path:_path_files'

local -a help_options
help_options=(/$'[^\0]##\0'/ ":cmd:kameleon command:($(kameleon commands))")

local -a info_options
info_options=(/$'[^\0]##\0'/ "$recipe_path[@]")

### Main argument parsing

# Arguments to _regex_arguments, built up in array $args.
local -a args reply
args=(
	# Command word. Can be anything
	/$'[^\0]#\0'/
)

# Define kameleon commands
_regex_words cmds 'kameleon commands' \
	'build:Builds the appliance from the given recipe:$build_options' \
	'help:Describe available commands or one specific command:$help_options' \
	'info:Display detailed information about a recipe:$info_options' \
	'list:Lists all defined recipes in the current directory' \
	'new:Creates a new recipe' \
	'repository:Manages set of remote git repositories' \
	'template:Lists and imports templates' \
	'version:Prints the Kameleon version information'
args+=("$reply[@]")

# Define kameleon common options
_regex_words opts 'kameleon options' \
	'--color:Enables colorization in output (Default)' \
	'--no-color:Disables colorization in output' \
	'--verbose:Enables verbose output for kameleon Users' \
	'--no-verbose:Disables verbose output for kameleon Users (Default)' \
	'--debug:Enables debug output for kameleon Developpers' \
	'--no-debug:Disables debug output for kameleon Developpers (Default)' \
	'--script:Never prompts for User intervention' \
	'--no-script:Prompts for user intervention if necessary (Default)'
args+=("$reply[@]" "#")

# Create the "_kameleon" completion function
_regex_arguments _kameleon "${args[@]}"
# Apply "_kameleon"
_kameleon "$@"
