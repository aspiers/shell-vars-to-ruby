require 'minitest/autorun'

class TestEnvironment < MiniTest::Unit::TestCase
  def setup
    @test = TF::Environment
  end

  def test_show_env_command_zsh_popen
    result = IO.popen("x=3;\n#{@test.show_env_command}") { |io|
      io.readlines.map { |l| l.chomp }
    }
    result = @test.parse_env( result )
    assert_equal "3", result["x"]
  end

  def show_code(code)
    puts "code was:"
    puts "----------"
    puts code
    puts "----------"
  end

  def run_session(prog, shellcode)
    shell = Session::Sh.new(:prog => prog)
    code = "#{shellcode}\n#{@test.show_env_command}"
    begin
      result = shell.execute(code)
    rescue Session::ExecutionError
      puts "Failed to execute code (#$!)"
      show_code(code)
      return nil
    end
    stdout, stderr = *result
    if ! stderr.empty?
      puts "\nstderr:\n----------\n#{stderr}----------"
    end
    stdout_lines = stdout.split(/\n/)
    parsed = @test.parse_env(stdout_lines)
    yield parsed
  end

  def multi_shell_run(shellcode)
    %w(bash zsh).each do |shell|
      run_session(shell, shellcode) do |result|
        yield result
      end
    end
  end

  def test_simple_assignment
    multi_shell_run 'x=3' do |result|
      assert_equal "3", result["x"]
    end
  end

  def test_array_assignment_double_quotes_bash
    run_session('bash', 'x=("a" "b")') do |result|
      assert_equal({"0" => "a", "1" => "b"}, result["x"])
    end
  end

  def test_array_assignment_double_quotes_zsh
    run_session('zsh', 'x=("a" "b")') do |result|
      assert_equal({"1" => "a", "2" => "b"}, result["x"])
    end
  end

  def test_array_assignment_single_quotes_bash
    run_session('bash', "x=('a' 'b')") do |result|
      assert_equal({"0" => "a", "1" => "b"}, result["x"])
    end
  end

  def test_array_assignment_single_quotes_zsh
    run_session('zsh', "x=('a' 'b')") do |result|
      assert_equal({"1" => "a", "2" => "b"}, result["x"])
    end
  end

  def test_array_modification_single_quotes_bash
    run_session('bash', "x=('a' 'b'); x[5]=c") do |result|
      assert_equal({"0" => "a", "1" => "b", "5" => "c"}, result["x"])
    end
  end

  def test_array_modification_single_quotes_zsh
    run_session('zsh', "x=('a' 'b'); x[5]=c") do |result|
      # zsh doesn't support sparse arrays
      assert_equal({"1" => "a", "2" => "b", "3" => "c"}, result["x"])
    end
  end

  def test_array_and_multiline_bash
    run_session('bash', %!x[1]=a; x[2]=b\nml=$'line one\\nline two'!) do |result|
      assert_equal({"1" => "a", "2" => "b"}, result["x"])
      assert_equal("line one\nline two", result["ml"])
    end
  end

  def test_array_and_raw_multiline_bash
    run_session('bash', %!x[1]=a; x[2]=b\nml=$'line one\nline two'!) do |result|
      assert_equal({"1" => "a", "2" => "b"}, result["x"])
      assert_equal("line one\nline two", result["ml"])
    end
  end

  def test_array_and_multiline_zsh
    run_session('zsh', %!x[1]=a; x[2]=b\nml=$'line one\\nline two'!) do |result|
      assert_equal({"1" => "a", "2" => "b"}, result["x"])
      assert_equal("line one\nline two", result["ml"])
    end
  end

  def test_array_and_raw_multiline_zsh
    run_session('zsh', %!x[1]=a; x[2]=b\nml=$'line one\nline two'!) do |result|
      assert_equal({"1" => "a", "2" => "b"}, result["x"])
      assert_equal("line one\nline two", result["ml"])
    end
  end

  def test_raw_multiline_bash
    run_session('bash', %!x[1]=a; x[2]=b\nml=$'line one\nline two'!) do |result|
      assert_equal("line one\nline two", result["ml"])
    end
  end

  def test_raw_multiline_zsh
    run_session('zsh', %!x[1]=a; x[2]=b\nml=$'line one\nline two'!) do |result|
      assert_equal("line one\nline two", result["ml"])
    end
  end

  def test_backslash_bash
    run_session('bash', %q!x='a\b'!) do |result|
      assert_equal('a\b', result["x"])
    end
  end

  def test_backslash_zsh
    run_session('zsh', %q!x='a\b'!) do |result|
      assert_equal('a\b', result["x"])
    end
  end

  def test_double_quote_bash
    run_session('bash', %q!x='a"b'!) do |result|
      assert_equal('a"b', result["x"])
    end
  end

  def test_double_quote_zsh
    run_session('zsh', %q!x='a"b'!) do |result|
      assert_equal('a"b', result["x"])
    end
  end

  def test_var_defs_inside_functions_are_ignored
    multi_shell_run "x=5\nmyfunc () { x=3; }" do |result|
      assert_equal "5", result["x"]
    end

    multi_shell_run "x=5\nmyfunc () {\nx=3\n}" do |result|
      assert_equal "5", result["x"]
    end
  end

  def test_assoc_arrays
    multi_shell_run "declare -A aa; aa[a]=one; aa[b]=two" do |result|
      assert_equal({'a' => 'one', 'b' => 'two' }, result["aa"])
    end
  end
end
