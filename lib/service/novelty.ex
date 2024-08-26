defmodule Service.Novelty do
  def decision(element, {dimension, sp}) do
    Enum.at(element, dimension) < sp
  end

  def split_data(%{:data => [a], :ranges => ranges, :depth => d}),
    do: {%{depth: d, ranges: ranges, data: a}}

  def split_data(%{data: data, ranges: ranges, depth: depth}) do
    # take range for the corresponding dimension (random)
    dimension = Service.RandomSeed.generate_int(0, (data |> hd |> length) - 1)

    # lets split range in two .. start,
    {min, max} = Enum.at(ranges, dimension)
    sp = Service.Tuple.midpoint({min, max})

    {left_ranges, right_ranges} =
      {List.replace_at(ranges, dimension, {min, sp}),
       List.replace_at(ranges, dimension, {sp, max})}

    %{true => left_data, false => right_data} =
      data |> Enum.group_by(&decision(&1, {dimension, sp}))

    {{dimension, sp}, %{data: left_data, ranges: left_ranges, depth: depth + 1},
     %{data: right_data, ranges: right_ranges, depth: depth + 1}}
  end

  def split_data(%{:data => data, :ranges => ranges}), do: split_data(%{:data => data, :ranges => ranges, :depth => 0})
  def split_data(data, ranges), do: split_data(%{:data => data, :ranges => ranges, :depth => 0})
end
