defmodule Service.Outlier do
  def split_range(node, dim), do: split_range(node, &Service.RandomSeed.generate_float/2, dim)

  def split_range(node, randfun, dim) do
    {new_list, {min, max} = removed_element} = Service.Common.remove_at_index(node.range, dim)

    sp = removed_element |> then(fn {min, max} -> randfun.(min, max) end)
    {novy_levy, novy_pravy} = {{min, sp}, {sp, max}}

    {List.insert_at(new_list,dim, novy_levy), List.insert_at(new_list, dim, novy_pravy)}
  end
end
