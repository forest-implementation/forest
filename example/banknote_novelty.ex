Code.require_file("csv_loader/csv_loader.ex", __DIR__)
Code.require_file("array_splitter/array_splitter.ex", __DIR__)

# Define the anonymous function for anomaly score calculation
anomaly_score_map_fn = fn forest, x, batch_size ->
  forest
  |> Forest.evaluate(x, &Service.Novelty.decision/2)
  |> Enum.map(fn
    %{data: data, depth: depth} -> depth + H.h(length(data))
  end)
  |> Service.Novelty.anomaly_score(batch_size)
  |> then(fn res -> {x, res} end)
end

%{"0" => regular, "1" => novelty} =
  CSVLoader.load_csv("example/data/other/Banknote_Authentication.csv")
  |> Enum.group_by(fn row -> Enum.at(row, -1) end, fn val ->
    Enum.drop(val, -1) |> Enum.map(&String.to_float/1)
  end)

[r70, r20, _, _] = ArraySplitter.split(regular, [70, 20, 10])
[n80, _, _] = ArraySplitter.split(novelty, [80, 20])

# 10% of data
batch_size = div(length(r70), 10)

init_range =
  0..(length(Enum.at(r70, 0)) - 1)
  |> Enum.map(&Statistex.Robust.adjusted_box(r70, &1))

IO.inspect(init_range)

group_in_range = fn data, ranges ->
  data
  |> Enum.group_by(fn elem ->
    Stream.zip_with(ranges, elem, fn {min, max}, el -> min <= el and el <= max end)
    |> Enum.all?()
  end)
end

group_in_range.(n80, init_range)
|> Map.update(false, :aa, &length/1)
|> Map.update(true, :aa, &length/1)
|> IO.inspect(label: "banknote")

group_in_range.(r70, init_range)
|> Map.update(false, :aa, &length/1)
|> Map.update(true, :aa, &length/1)

group_in_range.(r20, init_range)
|> Map.update(false, :aa, &length/1)
|> Map.update(true, :aa, &length/1)

forest =
  Forest.init(
    50,
    %{data: r70, ranges: init_range, batch_size: batch_size},
    Service.Novelty.make_split(ceil(H.h(length(r70)))),
    &Service.Novelty.batch/2
  )

"novelty #{n80 |> length}" |> IO.inspect()

n80
|> Enum.map(&anomaly_score_map_fn.(forest, &1, batch_size))
|> Enum.count(fn {[_ | _], score} -> score >= 0.5 end)
|> IO.inspect(charlists: :as_lists)

"regular #{r20 |> length}" |> IO.inspect()

r20
|> Enum.map(&anomaly_score_map_fn.(forest, &1, batch_size))
|> Enum.count(fn {[_ | _], score} -> score < 0.5 end)
|> IO.inspect(charlists: :as_lists)
