defmodule Service.Outlier do
  # helps to decide where to go during traversal
  def decision(element, {dimension, sp}) do
    Enum.at(element, dimension) < sp
  end

  defp dimension(data) do
    0..((data |> hd |> length) - 1)
    |> Enum.shuffle()
    |> Enum.find(
      :not_found,
      fn x -> data |> Service.Common.take_dimension(x) |> Enum.uniq() |> length > 1 end
    )
  end

  defp next_split(data, depth, dimension) do
    one_dimension_data = data |> Service.Common.take_dimension(dimension)
    {min, max} = one_dimension_data |> Enum.min_max()
    sp = Service.RandomSeed.generate_float(min, max)
    %{true => left, false => right} = data |> Enum.group_by(&decision(&1, {dimension, sp}))

    {{dimension, sp}, %{data: left, depth: depth + 1}, %{data: right, depth: depth + 1}}
  end

  def make_split(max_depth) do
    split_data = fn
      %{:data => [a], :depth => d} ->
        {%{depth: d, data: a}}

      %{:data => data, :depth => depth} when max_depth == depth ->
        {%{depth: depth, data: data}}

      %{:data => data, :depth => depth} ->
        case dimension(data) do
          :not_found -> {%{depth: depth, data: data}}
          dim -> next_split(data, depth, dim)
        end
    end

    fn
      %{:data => data, :depth => depth} ->
        split_data.(%{:data => data, :depth => depth})

      %{:data => _} = mp ->
        split_data.(Map.put(mp, :depth, 0))

      [_ | _] = data ->
        split_data.(%{:data => data, :depth => 0})
    end
  end

  # def split_data(data, batch_size = 1, max_depth = 10) do
  #   make_split(max_depth).(data)
  # end

  def batch(%{data: data, batch_size: bs}, _) do
    %{data: Enum.take_random(data, bs)}
  end

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
