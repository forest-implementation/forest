defmodule Service.Outlier do
  def split_range(node, dim), do: split_range(node, &Service.RandomSeed.generate_float/2, dim)

  def split_range(node, randfun, dim) do
    # TODO: SPLITPOINT BUDE SPATNE

    {new_list, _} = Service.Common.remove_at_index(node.range, dim)

    {min, max} = node.data |> Service.Common.take_dimension(dim) |> Enum.min_max

    sp = randfun.(min, max)
    {novy_levy, novy_pravy} = {{min, sp}, {sp, max}}

    {List.insert_at(new_list,dim, novy_levy), List.insert_at(new_list, dim, novy_pravy)}
  end
end
