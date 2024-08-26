defmodule Service.Outlier do
  # helps to decide where to go during traversal
  def decision(element, {dimension, sp}) do
    Enum.at(element, dimension) < sp
  end

  def split_data(%{:data => [a], :depth => d}), do: {%{depth: d, data: a}}

  def split_data(%{:data => data, :depth => depth}) do
    dimension = Service.RandomSeed.generate_int(0, (data |> hd |> length) - 1)
    one_dimension_data = data |> Service.Common.take_dimension(dimension)
    {min, max} = one_dimension_data |> Enum.min_max()
    sp = Service.RandomSeed.generate_float(min, max)

    %{true => left, false => right} = data |> Enum.group_by(&decision(&1, {dimension, sp}))

    {{dimension, sp}, %{data: left, depth: depth + 1}, %{data: right, depth: depth + 1}}
  end

  def split_data(%{:data => data}), do: split_data(%{:data => data, :depth => 0})
  def split_data(data), do: split_data(%{:data => data, :depth => 0})
end
