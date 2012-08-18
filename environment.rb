require 'yaml'

module TF
  class Environment
    HANDLER=<<'EOF'
output_variable () {
  varname="$1"
  eval "value=\"\$$varname\""
  escape_value
  echo "\"$varname\": \"$value\""
}

escape_value () {
  _tf_escape='\'
  [ -n "$ZSH_VERSION" ] && _tf_escape='\\' # urgh

  value="${value//\\/${_tf_escape}${_tf_escape}}"

  value="${value//\"/${_tf_escape}\"}"

  nl=$'\n'
  value="${value//$nl/${_tf_escape}n}"

  tab=$'\t'
  value="${value//$tab/${_tf_escape}t}"
}

output_bash_array () {
  varname="$1"
  echo "\"$varname\":"
  keys_calculator="echo \${!$varname[@]}"
  for i in `eval "$keys_calculator"`; do
    eval "value=\"\${$varname[$i]}\""
    escape_value
    echo "  \"$i\": \"$value\""
  done
}

output_zsh_array () {
  varname="$1"
  echo "\"$varname\":"
  i=1
  values_calculator="echo \"\${$varname""[@]}\""
  for value in `eval "$values_calculator"`; do
    [ -z "$value" ] && continue
    escape_value
    echo "  \"$i\": \"$value\""
    : $(( i++ ))
  done
}

output_zsh_assoc_array () {
  varname="$1"
  echo "\"$varname\":"
  keys_calculator="echo \"\${(k)$varname""[@]}\""
  for key in `eval "$keys_calculator"`; do
    eval "value=\"\${$varname""[$key]}\""
    #[ -z "$value" ] && continue
    escape_value
    echo "  \"$key\": \"$value\""
  done
}

output_bash_variables () {
  # subshell stops us from polluting the output, so
  # so we only have to be careful not to stomp on anything,
  # by using _tf_ prefix

  # This one doesn't distinguish between normal variables and arrays
  #builtin compgen -A variable | \

  builtin declare -p | \
  while read _tf_decl _tf_opts _tf_rest; do
    [ "$_tf_decl" = 'declare' ] || continue

    _tf_varname="${_tf_rest%%=*}"

    case "$_tf_opts" in
      -a*|-A*)
        output_bash_array "$_tf_varname"
        ;;
      *)
        output_variable   "$_tf_varname"
        ;;
    esac
  done
}

output_zsh_variables () {
  zmodload zsh/parameter
  for _tf_varname in ${(k)parameters[@]}; do
    case "$_tf_varname" in
      options|commands|fns|functions|builtins|reswords|aliases|widgets|parameters)
        continue
        ;;
    esac

    param_type="${parameters[$_tf_varname]}"
    case "$param_type" in
      scalar*|integer*)
        output_variable  "$_tf_varname" ;;
      array*)
        output_zsh_array "$_tf_varname" ;;
      assoc*)
        output_zsh_assoc_array "$_tf_varname" ;;
    esac
  done
}

echo "---"
if [ -n "$BASH_VERSION" ]; then
  output_bash_variables
elif [ -n "$ZSH_VERSION" ]; then
  output_zsh_variables
else
  echo "This shell isn't supported yet! ($0)" >&2
  exit 1
fi
EOF

    class << self
      def show_env_command
        Environment::HANDLER
      end

      def parse_env output
        output = output.join("\n")

        # http://www.yaml.org/spec/1.2/spec.html#id2770814
        output.gsub!(/[\x00-\x08\x0b-\x1f\x7f-\x84\x86-\x9f]/) { |m| "\\x%02x" % m.ord }

        #puts "\nyaml:\n--------------------\n#{output}\n--------------------\n"
        YAML::load(output)
      end
    end
  end
end
