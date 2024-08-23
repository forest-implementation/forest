defmodule Service.Outlier do

  def split_range(node), do: split_range(node, &Service.RandomSeed.generate/2)

  def split_range(node, randfun) do
    # get random value between min and max of data
    sp = node.data |> Enum.min_max |> then(fn {min, max} -> randfun.(min, max) end)
    {{Enum.min(node.data), sp}, {sp, Enum.max(node.data)}}
  end
end
