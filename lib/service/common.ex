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

end
