defmodule Service.Novelty do
  def split_range(node) do
    {min, max} = node.range

    midpoint = Service.Tuple.midpoint({min, max})
    {{min, midpoint}, {midpoint, max}}
  end
end
