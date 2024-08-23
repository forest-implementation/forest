defmodule Service.Tuple do

  def count({min, max}) when min < max do
    max - min
  end

  def midpoint({min, max}) when min < max do
    (min + max) / 2
  end
end

defmodule Service.Common do
  def minmax(x), do: Enum.min_max(x)

  # watch out, range is now a tuple
  def in_range(elements, {min, max}) do
    Enum.filter(elements, fn element ->
      element >= min and element <= max
    end)
  end

  def endcond(node), do: Service.Tuple.count(node.range) <= 1 or Enum.empty?(node.data)

  def findfun(node, element) do
    if Service.Common.in_range([element], node.left.range) |> length == 0 do
      1
    else
      0
    end
  end
end
