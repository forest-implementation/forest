%{"-1" => regular, "+1" => novelty} =
  TestHelper.MyCSVParser.load_csv("data/german_processed.csv")
  |> Enum.group_by(fn row -> Enum.at(row, 0) end, fn val ->
    Enum.drop(val, 1) |> Enum.map(&String.to_float/1)
  end)

[r70, r20, _r10, _] = TestHelper.ArraySplitter.split(regular, [70, 20, 10])
[n80, _n20, _] = TestHelper.ArraySplitter.split(novelty, [80, 20])

# div(length(r70), 1)
batch_size = 100

init_range =
  0..(length(Enum.at(r70, 0)) - 1)
  |> Enum.map(&Statistex.Robust.adjusted_box(r70, &1))

# |> Enum.map(&Service.Common.take_dimension(r70, &1) |> Enum.min_max)
# |> Enum.map(&Service.Common.take_dimension(r70, &1) |> Statistex.Robust.lmlhhm)

IO.inspect(init_range, label: "INIT range")

group_in_range = fn data, ranges ->
  data
  |> Enum.group_by(fn elem ->
    Stream.zip_with(ranges, elem, fn {min, max}, el -> min <= el and el <= max end)
    |> Enum.all?()
  end)
end

group_in_range.(n80, init_range)
|> Map.update(false, :aa, &(length(&1) / length(n80)))
|> Map.update(true, :aa, &(length(&1) / length(n80)))
|> IO.inspect(label: "german n80")

group_in_range.(r70, init_range)
|> Map.update(false, :aa, &(length(&1) / length(r70)))
|> Map.update(true, :aa, &(length(&1) / length(r70)))
|> IO.inspect(label: "german r70")

group_in_range.(r20, init_range)
|> Map.update(false, :aa, &(length(&1) / length(r20)))
|> Map.update(true, :aa, &(length(&1) / length(r20)))
|> IO.inspect(label: "german r20")

forest =
  Forest.init(
    50,
    %{data: r70, ranges: init_range, batch_size: batch_size},
    Service.Novelty.make_split(50),
    &Service.Novelty.batch/2
  )

"novelty #{n80 |> length}" |> IO.inspect()

n80
|> Enum.map(&anomaly_score_map(forest, &1, batch_size))
|> Enum.count(fn {[_ | _], score} -> score >= 0.5 end)
|> IO.inspect(charlists: :as_lists)

"regular #{r20 |> length}" |> IO.inspect()

r20
|> Enum.map(&anomaly_score_map(forest, &1, batch_size))
|> Enum.count(fn {[_ | _], score} -> score < 0.5 end)
|> IO.inspect(charlists: :as_lists)