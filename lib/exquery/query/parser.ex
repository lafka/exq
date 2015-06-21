defmodule ExQuery.Query.Parser do
  @moduledoc """
  Parser for query
  """

  defmodule ParseException do
    defexception message: nil
  end

  @doc """
  A query consists of k/v pairs separated by ~r/(,\s?| OR | AND )/
  expressions. They may be grouped together using `( <query> )`.

  The parser returns a function that takes item `e` and returns true
  the matched term or nil if it failed. This will be the equivalent of
  a `where` clause in SQL or Elixir guards.


  ## Examples
    iex> ExQuery.Query.Parser.from_string("k == :key").(%{"k" => :key})
    true
  """
  def from_string(buf) do
    {clause, guards} = Regex.split(~r/\s/, buf)
      |> group_controlflow
      |> tokens_to_ast {%{}, []}

    destruct = {:%{}, [], Enum.map(clause, fn({lookup, var}) ->
      {lookup, Macro.var(var, __MODULE__)}
    end)}

    expr = case guards do
      [] ->
        quote(do: fn
          (unquote(destruct)) -> true
          (_) -> false
        end)

      _ ->
        quote(do: fn
          (unquote(destruct)) when unquote(guards) -> true
          (_) -> false
        end)
    end

    #IO.puts Macro.to_string expr

    {fun, _x} = Code.eval_quoted expr
    fun
  end

  defp group_controlflow(tokens) do
    case Enum.split_while tokens, &( ! &1 in ["and", "or"] ) do
      {a, []} ->
        a

      {a, [op | b]} ->
        [a, op, group_controlflow(b)]
    end
  end


  @elemname quote(do: exq_e)
  @tokens [
    "and", "or",
    "==", "!=", "!",
    ">", "<", ">=", "<=",
    "+", "-", "*", "/"
  ]

  # acc := {%{} for destruction, current ast()}
  # rewrite groups to ast nodes
  defp tokens_to_ast([], acc), do: acc
  defp tokens_to_ast([ [_|_] = group | rest], {clause, currexpr}) do
    {clause, expr} = tokens_to_ast group, {clause, nil}
    tokens_to_ast [expr | rest], {clause, expr}
  end
#  defp tokens_to_ast(["(" | rest], {clause, currexpr} = acc) do
#    {group, [gend | rest]} = Enum.split_while rest, &( ! String.ends_with?(&1, ")") )
#    group = group ++ [String.replace(gend, ~r/\)$/, "")]
#    {clause, expr} = tokens_to_ast group, {clause, nil}
#    tokens_to_ast [expr | rest], {clause, currexpr}
#  end
#  defp tokens_to_ast(["(" <> buf | rest], acc), do:
#    tokens_to_ast(["(", buf | rest], acc)

  #defp tokens_to_ast([token | _] = tokens, _acc) when token in @tokens do
  #  raise ParseException, message: "missing left hand expr in `#{Enum.join(tokens, " ")}`"
  #end


  # make keywords
  defp tokens_to_ast([":" <> atom | rest], acc) do
    tokens_to_ast [String.to_existing_atom(atom) | rest], acc
  rescue e in ArgumentError ->
    raise ParseException, message: "no such keyword `#{atom}`"
  end

  # rewrite integer/floats
  defp tokens_to_ast([<<byte, _ :: binary()>> = token | rest], acc)
    when byte in ?0..?9 do
    case Integer.parse token do
      {int, ""} ->
        tokens_to_ast [int | rest], acc

      {_, "." <> _} ->
        case Float.parse token do
          {float, ""} ->
            tokens_to_ast [float | rest], acc

          {_, _} ->
            raise ParseException, message: "error parsing '#{token}' as float"
        end

      {_, _} ->
        raise ParseException, message: "error parsing '#{token}' as integer"
    end
  end

  # If it's still a string it should be variable name, rewrite
  defp tokens_to_ast([buf | rest], {clause, currexpr} = acc) when is_binary(buf) do

    case clause[buf] do
      nil ->
        varname = :"var_#{Map.size(clause)}"
        tokens_to_ast [Macro.var(varname, __MODULE__) | rest],
                      {Map.put(clause, buf, varname), currexpr}

      varname ->
        {clause, Macro.var(varname, __MODULE__)}
        tokens_to_ast [Macro.var(varname, __MODULE__) | rest], acc
    end
  end

  # return last argument
  defp tokens_to_ast([e], {clause, _currexpr} ) do
    {clause, e}
  end

  for token <- @tokens do
    fun = String.to_atom(token)
    #defp tokens_to_ast([lhs, unquote(token)], _acc) do
    #  raise ParseException, message: "missing right hand expr for #{lhs} #{unquote(token)}"
    #end

    defp tokens_to_ast([lhs, unquote(token) | rhs], {clause, _expr} = acc) do
      {clause, rhs} = tokens_to_ast rhs, {clause, nil}

      fun = unquote(fun)
      expr = quote do: unquote(fun)(unquote(lhs), unquote(rhs))
      {clause, expr}
    end
  end


  # Fix strings
  #defp tokens_to_ast([<<byte :: binary-size(1), _ :: binary>> = buf | rest], acc)
  #  when byte in ["'", "\""] do

  #  {buf, rest} = case Enum.split_while [buf | rest], &( ! String.ends_with?(&1, byte) ) do
  #    {a, []} ->
  #      {Enum.join(a, " "), []}

  #    {a, [last | b]} ->
  #      {Enum.join(a ++ [last], " "), b}
  #  end

  #  case String.split_at buf, -1 do
  #    {_buf, ^byte} ->
  #      tokens_to_ast [buf | rest], acc

  #    _ ->
  #      raise ParseException, message: "error find matching `#{byte}` quote"
  #  end
  #end

  ## If nothing above matches someone fucked up
  #defp tokens_to_ast(expr, acc) when is_list(expr) do
  #  raise ParseException, message: "extra syntax at end: #{Enum.join(expr, " ")}"
  #end
  #defp tokens_to_ast(expr, acc) do
  #  raise ParseException, message: "extra syntax at end: #{inspect expr}"
  #end

#[{{:., [], [{:x, [], Exq.Query.Parser}, :varname]}, [], []},
#[{{:., [], [{:x, [], Exq.Query.Parser}, :lvarname]}, [], []}, {"key", [], []}]}

end
