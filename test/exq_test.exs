defmodule ExqQueryTest do
  use ExUnit.Case

  alias Exq.Query.Parser
  alias Exq.Query.Parser.ParseException
  doctest Exq.Query.Parser

  test "`and` expr" do
    match = Exq.Query.Parser.from_string "k == :key and v == :val"

    assert  true === match.(%{"k" => :key, "v" => :val})
    assert false === match.(%{"k" => :key, "v" => :notval})
  end

  test "`or` expr" do
    match = Exq.Query.Parser.from_string "k == :key or k == :nokey"

    assert  true === match.(%{"k" => :key})
    assert  true === match.(%{"k" => :nokey})
    assert false === match.(%{"k" => :wrongkey})
  end

  test "`==` expr" do
      match = Exq.Query.Parser.from_string "n == n1"

      assert  true === match.(%{"n" => "a", "n1" => "a"})
      assert false === match.(%{"n" => "a", "n1" => "b"})
  end

  test "`!=` expr" do
      match = Exq.Query.Parser.from_string "n != n1"

      assert  true === match.(%{"n" => "a", "n1" => "b"})
      assert false === match.(%{"n" => "a", "n1" => "a"})
  end

  test "less, greater than expr" do
      ltmatch = Exq.Query.Parser.from_string "n < n1"

      assert  true === ltmatch.(%{"n" => "1", "n1" => "2"})
      assert false === ltmatch.(%{"n" => "2", "n1" => "1"})

      gtmatch = Exq.Query.Parser.from_string "n > n1"

      assert  true === gtmatch.(%{"n" => "2", "n1" => "1"})
      assert false === gtmatch.(%{"n" => "1", "n1" => "2"})

      ltematch = Exq.Query.Parser.from_string "n >= n1"
      assert  true === ltematch.(%{"n" => "2", "n1" => "2"})
      assert false === ltematch.(%{"n" => "1", "n1" => "2"})

      gtematch = Exq.Query.Parser.from_string "n <= n1"
      assert  true === gtematch.(%{"n" => "2", "n1" => "2"})
      assert false === gtematch.(%{"n" => "2", "n1" => "1"})
  end

  for op <- [:+, :-, :*, :/] do
    test "`#{op}` expr" do
      match = Exq.Query.Parser.from_string "n1 == n #{unquote(op)} 2"

      op = unquote(op)
      assert  true === match.(%{"n" => 5, "n1" => apply(Kernel, unquote(op), [5, 2])})
      assert false === match.(%{"n" => 5, "n1" => -1 })
    end
  end

  test "parse scalar values" do
    matches = [
      {:atom, Exq.Query.Parser.from_string("atom == :key")},
      {:int, Exq.Query.Parser.from_string("int == 1")},
      {:float, Exq.Query.Parser.from_string("float == 1.0")},
      {:string_double_quote, Exq.Query.Parser.from_string("string == \"str\"")},
      {:string_single_quote, Exq.Query.Parser.from_string("string == 'str'")}
    ]

    for {t, match} <- matches do
      assert true === match.(%{"atom" => :key,
                               "int" => 1,
                               "float" => 1.0,
                               "string" => "str"}), "failed to match valid type: #{t}"

      assert false === match.(%{"atom" => 1,
                               "int" => :nope,
                               "float" => :nope,
                               "string" => 1.42}), "failed to match invalid type: #{t}"
    end
  end

    #"and", "or",
    #"==", "!=", "!",
    ##">", "<", ">=", "<=",
    ##"+", "-", "*", "/", "%"

  # would i like to
  # datetime := "2015-05-03*"
  # state := {_, s} and s in ("running", "waiting")
  # state := {_, s} and s in ["running", "waiting"]
  # vsn(VSN > "2.0" :: vsn and VSN < "2.2")
end
