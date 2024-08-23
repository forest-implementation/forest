defmodule Service.Novelty do
  def split_range(node, dim) do
    {new_list, {min, max}} = Service.Common.remove_at_index(node.range, dim)

    sp = Service.Tuple.midpoint({min, max})
    {novy_levy, novy_pravy} = {{min, sp}, {sp, max}}

    {List.insert_at(new_list,dim, novy_levy), List.insert_at(new_list, dim, novy_pravy)}
  end
end
