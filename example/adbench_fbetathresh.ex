# MIX_ENV=example mix run example/adbench_fbetathresh.ex

Code.require_file("data_preparator/data_preparator.ex", __DIR__)
Code.require_file("array_splitter/array_splitter.ex", __DIR__)

defmodule Preprocessor do
  def take(array, indices) do
    array
    |> Enum.with_index()
    |> Enum.filter(fn {_element, index} -> index in indices end)
    |> Enum.map(fn {element, _index} -> element end)
  end

  def nonzeroindices(ranges) do
    ranges
    |> Stream.with_index()
    |> Stream.filter(fn {{min, max}, _index} -> not (min == max) end)
    |> Enum.map(fn {_, index} -> index end)
  end

  def preprocess(dataset_name) do
    %{"TE" => regular_test, "TR" => regular_train} =
      DataPreparator.adbench("example/data/adbench/csv/#{dataset_name}_TTV.csv", -2)

    %{"TE" => novelty_test} =
      DataPreparator.adbench("example/data/adbench/csv/#{dataset_name}_TV.csv", -2)

    {regular_train, regular_test, novelty_test, dataset_name}
  end

  def experiment(
        {train, rtest, ntest, dataset_name},
        robustfun,
        anomaly_threshold \\ 00000..2000//1 |> Enum.map(&(&1 / 100)),
        tree_count \\ 100,
        scorefun \\ &anomaly_score_map/3,
        batch_size \\ min(1024, 1024)
      ) do
    IO.inspect(dataset_name)

    init_range =
      0..(length(Enum.at(train, 0)) - 1)
      |> Enum.map(&robustfun.(train, &1))

    nozero = init_range |> nonzeroindices |> IO.inspect(label: "beru pouze dimenze:")
    f_train = train |> Enum.map(fn sloupec -> take(sloupec, nozero) end)
    f_init_range = take(init_range, nozero)

    forest =
      Forest.init(
        tree_count,
        %{data: f_train, ranges: f_init_range, batch_size: batch_size},
        Service.Novelty.make_split(6),
        &Service.Novelty.batch/2
      )

    r1 =
      rtest
      |> Enum.map(&scorefun.(forest, &1, batch_size))
      |> then(fn s ->
        Enum.map(anomaly_threshold, &{&1, Enum.count(s, fn {[_ | _], score} -> score < &1 end)})
      end)

    n1 =
      ntest
      |> Enum.map(&scorefun.(forest, &1, batch_size))
      |> then(fn s ->
        Enum.map(anomaly_threshold, &{&1, Enum.count(s, fn {[_ | _], score} -> score < &1 end)})
      end)

    results =
      Enum.zip_with([r1, n1], fn [{threshold, r}, {threshold, n}] ->
        tp = r
        fp = n
        f_n = (rtest |> length) - r
        tn = (ntest |> length) - n
        ctverice = {tp, f_n, fp, tn}
        {threshold, fbeta2(ctverice, 2)}
      end)

    File.write!("csv/fbeta/threshold_fbeta_#{dataset_name}.csv",
      results
      |> Enum.map(fn {threshold, fbeta} -> "#{threshold},#{fbeta}" end)
      |> Enum.join("\n")
    )

    IO.puts("Results saved for #{dataset_name}")
  end

  defp fbeta2({tp, f_n, fp, tn}, b) do
    (1 + b * b) * tp / ((1 + b * b) * tp + fp + 1.5 + b * b * f_n)
  end
end

datasets =
  File.ls("example/data/adbench/csv")
  |> then(fn {_, filenames} ->
    Stream.map(filenames, &Regex.run(~r/^((\d+)_[a-zA-Z.]+)\.csv$/, &1))
  end)
  |> Stream.reject(&is_nil/1)
  |> Enum.sort_by(&String.to_integer(Enum.at(&1, 2)))
  |> Enum.map(&Enum.at(&1, 1))
  |> Enum.reject(fn dataset -> Enum.member?(["3_backdoor", "9_census"], dataset) end)
  |> IO.inspect()

for dataset <- datasets do
  IO.inspect(dataset, label: "Dataset")
  {_, rtest, ntest, dataset_name} = tt = Preprocessor.preprocess(dataset)
  IO.inspect(dataset_name)
  Preprocessor.experiment(tt, fn x, y -> Statistex.Robust.z_score(x, 3, y) end)
end
