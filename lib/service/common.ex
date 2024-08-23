defmodule Service.Tuple do
  def count({min, max}) when min < max do
    max - min
  end

  def midpoint({min, max}) when min < max do
    (min + max) / 2
  end
end

defmodule Service.Common do

  def remove_at_index(list, index) when is_list(list) and is_integer(index) and index >= 0 do
    case Enum.split(list, index) do
      {before, [element | af]} -> {before ++ af, element}
      {before, []} -> {before, nil}
    end
  end

  def take_dimension(list_of_lists, n) when is_list(list_of_lists) do
    list_of_lists
    |> Enum.map(fn sublist -> Enum.at(sublist, n) end)
  end


  def minmax(x, dim) do
    take_dimension(x, dim) |> Enum.min_max()
  end

  # watch out, range is now an array of tuples
  def in_range(elements, ranges, dim) do
    {min,max} = Enum.at(ranges, dim)
    # one_dim_elements = elements |> take_dimension(dim) |> IO.inspect

    Enum.filter(elements, fn element ->
      Enum.at(element,dim) >= min and Enum.at(element,dim) <= max
    end)
  end

  def endcond(node), do: length(node.data) <= 1

  def findfun(node, element, dim) do
    if Service.Common.in_range([element], node.left.range, dim) |> length == 0 do
      1
    else
      0
    end
  end

  def dimfun(node) do
    alldims = length(Enum.at(node.data, 0))
    Service.RandomSeed.generate_int(0, alldims-1)
  end
end
