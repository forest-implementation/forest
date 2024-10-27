defmodule Service.Novelty do
  def decision(element, {dimension, sp}) do
    Enum.at(element, dimension) < sp
  end

  def next_split(%{data: data, ranges: ranges, depth: depth}) do
    dimension = Randixir.int(0, (data |> hd |> length) - 1)

    # lets split range in two .. start,
    {min, max} = Enum.at(ranges, dimension)

    sp = Service.Tuple.midpoint({min, max})

    {left_ranges, right_ranges} =
      {List.replace_at(ranges, dimension, {min, sp}),
       List.replace_at(ranges, dimension, {sp, max})}

    %{true => left_data, false => right_data} =
      data
      |> Enum.group_by(&decision(&1, {dimension, sp}))
      |> Map.merge(%{false => [], true => []}, fn _, v1, _ -> v1 end)

    {{dimension, sp}, %{data: left_data, ranges: left_ranges, depth: depth + 1},
     %{data: right_data, ranges: right_ranges, depth: depth + 1}}
  end

  def make_split(max_depth) do
    fn
      %{data: [_], depth: _} = dp ->
        {dp}

      %{data: [], depth: _} = dp ->
        {dp}

      %{data: _, ranges: _, depth: d} = dp when d == max_depth ->
        {dp}

      %{data: _, ranges: _, depth: _} = dp ->
        next_split(dp)

      %{data: data, ranges: ranges} ->
        make_split(max_depth).(%{:data => data, :ranges => ranges, :depth => 0})
    end
  end

  def batch(%{data: data, batch_size: bs} = dp, _) do
    %{dp | data: data |> Enum.take_random(bs)}
  end

  def avg(depths) do
    Enum.sum(depths) / length(depths)
  end

  def harmonic_num(n) do
    1..n |> Stream.map(&(1.0 / &1)) |> Enum.sum()
  end

  def average_path_length_c(n) when n < 2, do: 0
  def average_path_length_c(2), do: 1

  def average_path_length_c(batch_size) do
    2 * harmonic_num(batch_size - 1) - 2 * (batch_size - 1) / batch_size
  end

  def anomaly_score(depths, batch_size) do
    :math.pow(2, -avg(depths) / H.h(batch_size))
  end
end
