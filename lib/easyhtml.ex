defmodule EasyHTML do
  @moduledoc """
  EasyHTML makes working with HTML easy.

  It is a tiny wrapper around [Floki](https://hex.pm/packages/floki) that adds
  conveniences for HTML nodes:

    * An `Inspect` implementation to pretty-print them
    * An `Access` implementation to easily traverse them
    * A `String.Chars` implementation to convert them to text

  ## Examples

      iex> doc = EasyHTML.parse!("<p>Hello, <em>world</em>!</p>")
      #EasyHTML[<p>Hello, <em>world</em>!</p>]
      iex> doc["em"]
      #EasyHTML[<em>world</em>]
      iex> to_string(doc)
      "Hello, world!"
  """

  defstruct [:nodes]

  defmacro sigil_HTML({:<<>>, _, [binary]}, []) do
    Macro.escape(parse!(binary))
  end

  def parse!(html) do
    %__MODULE__{nodes: Floki.parse_document!(html, attributes_as_maps: true)}
  end

  def fetch(%__MODULE__{} = struct, selector) when is_binary(selector) do
    case Floki.find(struct.nodes, selector) do
      [] -> :error
      nodes -> {:ok, %__MODULE__{nodes: nodes}}
    end
  end

  def to_string(%__MODULE__{} = struct) do
    Floki.text(struct.nodes)
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(struct, opts) do
      open = "~HTML["
      close = "]"
      container_opts = [separator: "", break: :flex]
      container_doc(open, struct.nodes, close, opts, &fun/2, container_opts)
    end

    defp fun({tag, attributes, content}, opts) do
      tag_color = :map
      attribute_color = :map

      attributes =
        for {name, value} <- attributes do
          concat([
            color(" #{name}=", attribute_color, opts),
            color("\"#{value}\"", :string, opts)
          ])
        end
        |> concat()

      open =
        concat([
          color("<#{tag}", tag_color, opts),
          attributes,
          color(">", tag_color, opts)
        ])

      close = color("</#{tag}>", tag_color, opts)
      container_opts = [separator: "", break: :strict]
      container_doc(open, content, close, opts, &fun/2, container_opts)
    end

    defp fun({:comment, content}, opts) do
      color("<!-- #{content} -->", :comment, opts)
    end

    defp fun(string, opts) when is_binary(string) do
      color(string, :string, opts)
    end

    defp fun(other, _opts) do
      raise inspect(other)
    end
  end

  defimpl String.Chars do
    def to_string(struct) do
      Floki.text(struct.nodes)
    end
  end

  defimpl Enumerable do
    def count(_), do: {:error, __MODULE__}
    def member?(_, _), do: {:error, __MODULE__}
    def slice(_), do: {:error, __MODULE__}

    def reduce(_list, {:halt, acc}, _fun), do: {:halted, acc}

    def reduce(%EasyHTML{nodes: nodes}, acc, fun) do
      reduce(nodes, acc, fun)
    end

    def reduce([], {:cont, acc}, _fun), do: {:done, acc}

    def reduce([node | rest], {:cont, acc}, fun) do
      reduce(rest, fun.(%EasyHTML{nodes: [node]}, acc), fun)
    end
  end
end
