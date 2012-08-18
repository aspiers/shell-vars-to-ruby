require 'yaml'

module TF
  class Environment
    HANDLER=<<'EOF'
output_variable () {
  varname="$1"
  eval "value=\"\$$varname\""

  value="${value//\"/\\\"}"

  nl=$'\n'
  _tf_escape='\'
  [ -n "$ZSH_VERSION" ] && _tf_escape='\\' # urgh
  value="${value//$nl/${_tf_escape}n}"

  tab=$'\t'
  value="${value//$tab/${_tf_escape}t}"

  echo "\"$varname\": \"$value\""
}

output_bash_variables () {
  builtin compgen -A variable | \
  while read _tf_varname; do
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

        YAML::load(output)
      end
    end
  end
end
