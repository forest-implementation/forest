defmodule Service.Outlier do
  # helps to decide where to go during traversal
  def decision(element, {dimension, sp}) do
    Enum.at(element, dimension) < sp
  end

  def split_data(%{:data => [a], :depth => d}), do: {%{depth: d, data: a}}

  def split_data(%{:data => data, :depth => depth, :max_depth => md}) when md == depth,
    do: {%{depth: depth, data: data}}

  def split_data(%{:data => data, :depth => depth, :max_depth => _} = puvodni) do
    # dimension switching if not available to go further (e.g. all data are same)
    dimension =
      0..((data |> hd |> length) - 1)
      |> Enum.to_list()
      |> Enum.shuffle()
      |> Enum.find(:not_found, fn x ->
        data |> Service.Common.take_dimension(x) |> Enum.uniq() |> length > 1
      end)

    case dimension do
      :not_found ->
        {%{depth: depth, data: data}}

      _ ->
        one_dimension_data = data |> Service.Common.take_dimension(dimension)
        {min, max} = one_dimension_data |> Enum.min_max()
        sp = Service.RandomSeed.generate_float(min, max)
        %{true => left, false => right} = data |> Enum.group_by(&decision(&1, {dimension, sp}))

        {{dimension, sp}, Map.merge(puvodni, %{data: left, depth: depth + 1}),
         Map.merge(puvodni, %{data: right, depth: depth + 1})}
    end
  end

  def split_data(%{:data => _, :max_depth => _} = mp), do: split_data(Map.put(mp, :depth, 0))

  def split_data([_ | _] = data),
    do:
      split_data(%{:data => data, :depth => 0, :max_depth => :math.ceil(:math.log2(length(data)))})

  def batch(%{data: data, batch_size: bs, max_depth: _} = dp, _) do
    Map.put(dp, :data, Enum.take_random(data, bs))
  end

  def batch(%{data: _, batch_size: bs} = dp, n),
    do: batch(Map.put(dp, :max_depth, :math.ceil(:math.log2(bs))), n)

  def batch(%{data: data} = dp, n) do
    batch(Map.put(dp, :batch_size, length(data)), n)
  end

  def ecko(depths) do
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
    :math.pow(2, -ecko(depths) / average_path_length_c(batch_size))
  end
end
