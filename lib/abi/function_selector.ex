defmodule ABI.FunctionSelector do
  @moduledoc """
  Module to help parse the ABI function signatures, e.g.
  `my_function(uint64, string[])`.
  """

  require Integer

  @type type ::
    {:uint, integer()} |
    :bool

  @type t :: %__MODULE__{
    function: String.t,
    types: [type],
    returns: type
  }

  defstruct [:function, :types, :returns]

  @doc """
  Decodes a function selector to struct. This is a simple version
  and we may opt to do format parsing later.

  ## Examples

      iex> ABI.FunctionSelector.decode("bark(uint256,bool)")
      %ABI.FunctionSelector{
        function: "bark",
        types: [
          {:uint, 256},
          :bool
        ]
      }

      iex> ABI.FunctionSelector.decode("growl(uint,address,string[])")
      %ABI.FunctionSelector{
        function: "growl",
        types: [
          {:uint, 256},
          :address,
          {:array, :string}
        ]
      }

      iex> ABI.FunctionSelector.decode("rollover()")
      %ABI.FunctionSelector{
        function: "rollover",
        types: []
      }

      iex> ABI.FunctionSelector.decode("pet(address[])")
      %ABI.FunctionSelector{
        function: "pet",
        types: [
          {:array, :address}
        ]
      }

      iex> ABI.FunctionSelector.decode("paw(string[2])")
      %ABI.FunctionSelector{
        function: "paw",
        types: [
          {:array, :string, 2}
        ]
      }

      iex> ABI.FunctionSelector.decode("shake((string))")
      %ABI.FunctionSelector{
        function: "shake",
        types: [
          {:tuple, [:string]}
        ]
      }
  """
  def decode(signature) do
    captures = Regex.named_captures(~r/(?<function>[a-zA-Z_$][a-zA-Z_$0-9]*)\((?<types>(([^,]+),?)*)\)/, signature)

    %ABI.FunctionSelector{
      function: captures["function"],
      types: captures["types"] |> String.split(",", trim: true) |> Enum.map(&decode_type/1),
      returns: nil
    }
  end

  def decode_type("uint" <> size_str) do
    size = case size_str do
      "" -> 256 # default
      _ ->
        {size, ""} = Integer.parse(size_str)

        size
    end

    {:uint, size}
  end

  def decode_type("bool"), do: :bool
  def decode_type("string"), do: :string
  def decode_type("address"), do: :address
  def decode_type(els) do
    cond do
      # Check for array type
      captures = Regex.named_captures(~r/(?<type>[a-z0-9]+)\[(?<element_count>\d*)\]/, els) ->
        type = decode_type(captures["type"])

        if captures["element_count"] != "" do
          {element_count, ""} = Integer.parse(captures["element_count"])

          {:array, type, element_count}
        else
          {:array, type}
        end
      # Check for tuples
      captures = Regex.named_captures(~r/\((?<types>[a-z0-9\[\]]+,?)+\)/, els) ->
        types =
          String.split(captures["types"], ",", trim: true)
          |> Enum.map(fn type -> decode_type(type) end)

        {:tuple, types}
      true ->
        raise "Unsupported type: #{els}"
    end
  end

  @doc """
  Encodes a function call signature.

  ## Examples

      iex> ABI.FunctionSelector.encode(%ABI.FunctionSelector{
      ...>   function: "bark",
      ...>   types: [
      ...>     {:uint, 256},
      ...>     :bool,
      ...>     {:array, :string},
      ...>     {:array, :string, 3},
      ...>     {:tuple, [{:uint, 256}, :bool]}
      ...>   ]
      ...> })
      "bark(uint256,bool,string[],string[3],(uint256,bool))"
  """
  def encode(function_selector) do
    types = get_types(function_selector) |> Enum.join(",")

    "#{function_selector.function}(#{types})"
  end

  defp get_types(function_selector) do
    for type <- function_selector.types do
      get_type(type)
    end
  end

  defp get_type({:uint, size}), do: "uint#{size}"
  defp get_type(:bool), do: "bool"
  defp get_type(:string), do: "string"
  defp get_type(:address), do: "address"
  defp get_type({:array, type}), do: "#{get_type(type)}[]"
  defp get_type({:array, type, element_count}), do: "#{get_type(type)}[#{element_count}]"
  defp get_type({:tuple, types}) do
    encoded_types = types
    |> Enum.map(&get_type/1)
    |> Enum.join(",")

    "(#{encoded_types})"
  end
  defp get_type(els), do: "Unsupported type: #{inspect els}"

end
