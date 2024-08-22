defmodule Service.Common do
  def minmax(x), do: Enum.min_max(x) |> then(fn {a, b} -> a..b end)

  def split_range(node) do
    min = Enum.min(node.range)
    max = Enum.max(node.range)
    midpoint = min + div(Enum.count(node.range), 2)
    {min..(midpoint - 1), midpoint..max}
  end

  def in_range(elements, range) do
    Enum.filter(elements, fn element ->
      element >= Enum.min(range) and element <= Enum.max(range)
    end)
  end

  def endcond(node), do: Enum.count(node.range) <= 1 or Enum.empty?(node.data)

  def findfun(node, element) do
    if Service.Common.in_range([element], node.left.range) |> length == 0 do
      1
    else
      0
    end
  end
end
