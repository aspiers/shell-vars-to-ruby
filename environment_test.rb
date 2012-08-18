require 'minitest/autorun'

class TestEnvironment < MiniTest::Unit::TestCase
  def setup
    @test = TF::Environment
  end

  def test_parse_array_bash
    result = @test.parse_array :array_bash, '[0]="four" [1]="five" [2]="six" [10]="ten"'.shellsplit
    bash_expected=[:array_bash, {'0'=>'four','1'=>'five','2'=>'six','10'=>'ten'} ]
    assert_equal bash_expected, result
  end
  def test_parse_array_zsh
    result = @test.parse_array :array_zsh, "four five six '' '' '' '' '' '' ten".shellsplit
    zsh_expected=[:array_zsh, {'1'=>'four','2'=>'five','3'=>'six','10'=>'ten'} ]
    assert_equal zsh_expected, result
  end

  def test_parse_var
    {
      "_="                     => ["_",       '' ],
      "FIGNORE=''"             => ["FIGNORE", '' ],

      "USER=vagrant"           => ["USER",      "vagrant"],
      "variable1='play'\''me'" => ["variable1", "play'me"],

      # bash format
      'variable2=$\'play\n with\n me\n now\'' => ["variable2", 'play\n with\n me\n now'],
      # zsh format
      "variable2=$'play\n with\n me\n now'"   => ["variable2", "play\n with\n me\n now"],

      # bash format
      'array1=([0]="four" [1]="five" [2]="six" [10]="ten")' => ["array1", {'0'=>'four','1'=>'five','2'=>'six','10'=>'ten'} ],
      # zsh format
      "array2=(four five six '' '' '' '' '' '' ten)"        => ["array2", {'1'=>'four','2'=>'five','3'=>'six','10'=>'ten'} ]

    }.each do |example, result|
      assert_equal(result, @test.parse_var( example ) )
    end
  end

  def test_show_env_command_zsh_popen
    result = IO.popen("x=3;\n#{@test.show_env_command}") {|io|io.readlines}
    result = @test.parse_env( result )
    assert_equal "3", result["x"]
  end

  def run_session(prog, shellcode)
    shell = Session::Sh.new(:prog => prog)
    result = shell.execute("#{shellcode}\n#{@test.show_env_command}")
    result = result[0].split(/\n/)
    @test.parse_env( result )
  end

  def multi_shell_run(shellcode)
    %w(bash zsh).each do |shell|
      yield run_session(shell, shellcode)
    end
  end

  def test_simple_assignment
    multi_shell_run 'x=3' do |result|
      assert_equal "3", result["x"]
    end
  end

  def test_array_assignment_double_quotes_bash
    result = run_session('bash', 'x=("a" "b")')
    assert_equal({"0" => "a", "1" => "b"}, result["x"])
  end

  def test_array_assignment_double_quotes_zsh
    result = run_session('zsh', 'x=("a" "b")')
    assert_equal({"1" => "a", "2" => "b"}, result["x"])
  end

  def test_array_assignment_single_quotes_bash
    result = run_session('bash', "x=('a' 'b')")
    assert_equal({"0" => "a", "1" => "b"}, result["x"])
  end

  def test_array_assignment_single_quotes_zsh
    result = run_session('zsh', "x=('a' 'b')")
    assert_equal({"1" => "a", "2" => "b"}, result["x"])
  end

  def test_array_modification_single_quotes_bash
    result = run_session('bash', "x=('a' 'b'); x[5]=c")
    assert_equal({"0" => "a", "1" => "b", "5" => "c"}, result["x"])
  end

  def test_array_modification_single_quotes_zsh
    result = run_session('zsh', "x=('a' 'b'); x[5]=c")
    assert_equal({"1" => "a", "2" => "b", "5" => "c"}, result["x"])
  end

  def test_array_and_multiline
    multi_shell_run %q!x=('a' 'b'); ml=$'line one\nline two'! do |result|
      assert_equal({"0" => "a", "1" => "b"}, result["x"])
      assert_equal("line one\nline two", result["ml"])
    end
  end
end
