defmodule ExQuery.Query do
  alias ExQuery.Query.Parser

  @doc """
  Parse a string to query

  See `Spew.Query.Parser.from_string/1`
  """
  def from_string(buf), do: Parser.from_string(buf)
end
