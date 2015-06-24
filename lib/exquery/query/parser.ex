defmodule ExQuery.Query.Parser do
  @moduledoc """
  Parser for query
  """

  defmodule ParseException do
    defexception message: nil, param: nil
  end

  @elemname quote(do: exq_e)
  @tokens [
    "and", "or",
    "==", "!=", "!",
    ">", "<", ">=", "<=",
    "+", "-", "*", "/"
  ]

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
  def from_string(buf, struct \\ nil) do
    {tokens, vars} = tokenize buf

    {clause, guards} = tokens |> group_controlflow
                              |> tokens_to_ast {vars, []}


    mapdestruct = {:%{}, [], Enum.map(clause, fn
      ({lookup, {_, _, _} = var}) ->
        {lookup, var}

      # unpack first level if the key is nested
      ({_lookup, {exportas, {:%{}, _, [t]}}}) ->
        t
    end)}

    destruct = if nil === struct do
      mapdestruct
    else
      # Put in a struct and rewrite keys to atom, but verify that the
      # key actually exists
      keys = Map.keys(struct.__struct__) |> Enum.map(&Atom.to_string/1)
      {:%{}, [], vars} = mapdestruct
      vars = Enum.map vars, fn({k, v}) ->
        unless Enum.member?(keys, k) do
          raise ParseException, message: "unknown key `#{k}`", param: k
        end

        k = String.to_existing_atom k
        {k, v}
      end
      [Elixir | struct] = String.split("#{struct}", ".") |> Enum.map(&String.to_existing_atom/1)
      {:%, [], [{:__aliases__, [alias: false], struct}, {:%{}, [], vars}]}
    end

    expr = case guards do
      [] ->
        quote(do: fn
          (unquote(destruct)) -> true
          (_) -> false
        end)

      _ ->
        quote(do: fn
          (unquote(destruct)) -> unquote(guards)
          (_) -> false
        end)
    end

    {fun, _x} = Code.eval_quoted expr
    fun
  end

  defp tokenize(buf), do: tokenize(buf, %{})
  defp tokenize("", vars), do: {[], vars}
  defp tokenize(<<byte :: binary-size(1), rest :: binary()>>, vars) when byte in ["\"", "'"] do
    matched? = String.ends_with? rest, byte
    [string, rest] = case String.split rest, byte, parts: 2 do
      [string] when matched? -> [string, ""]
      [string, rest] -> [string, rest]
      [_string] ->
        raise ParseException , message: "could not find matching quote `#{byte}`"
    end

    {tokens, vars} = tokenize rest, vars
    {[ string | tokens ], vars}
  end
  defp tokenize(buf, vars) do
    [token | rest ] = String.split buf, " ", parts: 2, trim: true
    {token, vars} = map_token token, vars

    {tokens, vars} = tokenize Enum.join(rest), vars
    {[ token | tokens ], vars}
  end

  defp map_token(":" <> atom, vars), do: {to_atom(atom), vars}
  defp map_token(<<byte, _ :: binary()>> = token, vars) when byte in ?0..?9, do: {to_number(token), vars}
  defp map_token(token, vars) when token in @tokens, do: {token, vars}
  defp map_token("in", vars), do: {"in", vars}
  defp map_token(token, vars) do
    # slighly messy. Either we return the token => :#{varname}
    # or we return {:#{varname}, destruction}
    case vars[token] do
      nil ->
        exportas = :"var_#{Map.size(vars)}"
        case String.split token, "." do
          [^token] ->
            {Macro.var(exportas, __MODULE__), Map.put(vars, token, Macro.var(exportas, __MODULE__))}

          parts ->
            exportas = Macro.var exportas, __MODULE__
            destruction = Enum.reduce Enum.reverse(parts), exportas, fn(part, acc) ->
              quote do: %{unquote(part) => unquote(acc)}
            end
            {exportas, Map.put(vars, token, {exportas, destruction})}
        end

      {varname, _} ->
        {varname, vars}

      varname ->
        {varname, vars}
    end
  end

  defp to_atom(atom) do
    String.to_existing_atom atom
  rescue e in ArgumentError ->
    raise ParseException, message: "no such keyword `#{atom}`"
  end


  defp to_number(buf) do
    case Integer.parse buf do
      {int, ""} ->
        int

      # convert to range
      {int, ".." <> rest} ->
        Range.new int, to_number rest

      {_, "." <> _} ->
        case Float.parse buf do
          {float, ""} ->
            float

          {float, ".." <> rest} ->
            Range.new float, to_number rest

          {_, _} ->
            raise ParseException, message: "error parsing '#{buf}' as float"
        end

      {_, _} ->
        raise ParseException, message: "error parsing '#{buf}' as integer"
    end
  end

  defp group_controlflow(tokens) do
    case Enum.split_while tokens, &( ! &1 in ["and", "or"] ) do
      {a, []} ->
        a

      {a, [op | b]} ->
        [a, op, group_controlflow(b)]
    end
  end


  # rewrite groups to ast nodes
  defp tokens_to_ast([], acc), do: acc
  defp tokens_to_ast([ [_|_] = group | rest], {clause, currexpr}) do
    {clause, expr} = tokens_to_ast group, {clause, nil}
    tokens_to_ast [expr | rest], {clause, expr}
  end

  # return last argument
  defp tokens_to_ast([e], {clause, _currexpr} ) do
    {clause, e}
  end

  for token <- @tokens do
    fun = String.to_atom(token)

    defp tokens_to_ast([lhs, unquote(token) | rhs], {clause, _expr} = acc) do
      {clause, rhs} = tokens_to_ast rhs, {clause, nil}

      fun = unquote(fun)
      expr = quote do: unquote(fun)(unquote(lhs), unquote(rhs))
      {clause, expr}
    end
  end

  defp tokens_to_ast([lhs, "in" | rhs], {clause, _expr} = acc) do
    {clause, rhs} = tokens_to_ast rhs, {clause, nil}
    expr = cond do
      Range.range?(rhs) ->
        quote(do: unquote(lhs) in unquote(Macro.escape(rhs)))

      true ->
        quote(do: is_list(unquote(rhs)) and Enum.member?(unquote(rhs), unquote(lhs)))
    end
    {clause, expr}
  end
end
