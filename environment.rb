require 'yaml'

module TF
  class Environment
    HANDLER=<<'EOF'
i=0

debug () {
  : echo "$i: $*" >&2
  : $(( i++ ))
}

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

output_bash_variables () {
  # This one doesn't distinguish between normal variables and arrays
  #builtin compgen -A variable | \

  builtin declare -p | \
  while read _tf_decl _tf_opts _tf_rest; do
    [ "$_tf_decl" = 'declare' ] || continue
    [ "$_tf_opts" = '-a' ] && continue

    _tf_varname="${_tf_rest%%=*}"

    # subshell stops us from polluting the output, so
    # so we only have to be careful not to stomp on anything.
    output_variable $_tf_varname
  done
}

output_zsh_variables () {
  zmodload zsh/parameter
  for _tf_varname in ${(k)parameters[@]}; do
    # subshell stops us from polluting the output, so
    # so we only have to be careful not to stomp on anything.
    case "$_tf_varname" in
      options|commands|fns|functions|builtins|reswords|aliases|widgets|parameters)
        :
        ;;
      *)
        [[ $#_tf_varname -gt 100 ]] || output_variable $_tf_varname
        ;;
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

#zzzz=$'just\nfor\ntesting'
#output_variable zzzz
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
