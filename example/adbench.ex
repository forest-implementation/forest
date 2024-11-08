Code.require_file("data_preparator/data_preparator.ex", __DIR__)
Code.require_file("array_splitter/array_splitter.ex", __DIR__)

defmodule Preprocessor do
  # train = [1,2,3]
  # init_range = [{1,1},{0,5},{5,5}]

  # init_range
  # |> Preprocessor.nonzeroindices
  # |> IO.inspect(label: "beru pouze dimenze:")
  # |> then(fn indices -> Preprocessor.take(train, indices) end)
  # |> IO.inspect
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

  defp hfun(0), do: 0
  defp hfun(x) when x < 100 , do: H.h(x)
  defp hfun(count) do
    :math.log2(count) + 1.332
  end

  def preprocess(dataset_name) do
    %{"TE" => regular_test, "TR" => regular_train} =
      DataPreparator.adbench("example/data/adbench/csv/#{dataset_name}_TTV.csv", -2)

    %{"TE" => novelty_test} =
      DataPreparator.adbench("example/data/adbench/csv/#{dataset_name}_TV.csv", -2)

    {regular_train, regular_test, novelty_test}
  end

  defp anomaly_score_map(forest, x, batch_size) do
    forest
    |> Forest.evaluate(x, &Service.Novelty.decision/2)
    |> Enum.map(fn
      %{data: data, depth: depth} -> depth + hfun(length(data))
    end)
    |> Service.Novelty.anomaly_score(batch_size, &hfun/1)
    |> then(fn res -> {x, res} end)
  end

  def experiment(
        {train, rtest, ntest},
        robustfun,
        anomaly_treshold \\ [0.5, 0.55, 0.6],
        tree_count \\ 50,
        scorefun \\ &anomaly_score_map/3
      ) do
    # 10% batch size
    batch_size = div(length(train), 10)

    init_range =
      0..(length(Enum.at(train, 0)) - 1)
      |> Enum.map(&robustfun.(train, &1))

    # filter out dimensions where range was 0
    nozero = init_range |> nonzeroindices |> IO.inspect(label: "beru pouze dimenze:")

    f_train =
      train |> Enum.map(fn sloupec -> take(sloupec, nozero) end)

    # do not forget to filter out the ranges also
    f_init_range = take(init_range, nozero)

    forest =
      Forest.init(
        tree_count,
        %{data: f_train, ranges: f_init_range, batch_size: batch_size},
        Service.Novelty.make_split(ceil(hfun(length(f_train)))),
        &Service.Novelty.batch/2
      )

    r1 =
      rtest
      |> Enum.map(&scorefun.(forest, &1, batch_size))
      |> then(
          fn s ->
            Enum.map(anomaly_treshold,&{&1, Enum.count(s,fn {[_ | _], score} -> score < &1 end)})
          end
        )

    n1 =
      ntest
      |> Enum.map(&scorefun.(forest, &1, batch_size))
      |> then(fn s -> Enum.map(anomaly_treshold,&{&1,Enum.count(s,fn {[_ | _], score} -> score < &1 end)}) end)

    {r1, n1}
  end
end

# TODO: TENTO SOUBOR BUDE SLOUZIT PRO NASTAVOVANI PARAMETRU ATP
# MUZE SE SPOUSTET FURT DOKOLA NA SPECIFIKOVANYCH DATASETECH A SPECIFIKOVANCYH robust funkcich

# TODO: pak bude dalsi soubor ktery bude uz experiment spoustet s parametry co si myslime ze jsou nejlepsi
# a s validacnim csv (vlastne jen vymenis ve funkci priponu pred csv)
# ten uz se spustit jen jednou a jeho vysledky pujdou do clanku

datasets =
  File.ls("example/data/adbench/csv")
  |> then(fn {_, filenames} ->
    Stream.map(filenames, &Regex.run(~r/^((\d+)_[a-zA-Z.]+)\.csv$/, &1))
  end)
  |> Stream.reject(&is_nil/1)
  |> Enum.sort_by(&String.to_integer(Enum.at(&1, 2)))
  |> Enum.map(&Enum.at(&1, 1))
  # specify files to SKIP
  |> then(fn soubory -> ["9_census"] |> Enum.flat_map(&List.delete(soubory, &1)) end)
  |> IO.inspect()

# or specify your own
# datasets = ["1_ALOI", "2_annthyroid", "3_backdoor", "4_breastw"]

for dataset <- datasets do
  IO.inspect(dataset, label: "Dataset")
  {_, rtest, ntest} = tt = Preprocessor.preprocess(dataset)

  {r, n} = Preprocessor.experiment(tt, fn x, y -> Statistex.Robust.z_score(x, 3, y) end)
  # {r, n} = Preprocessor.experiment(tt, fn x, y -> Statistex.Robust.adjusted_box(x, y) end)

  "regular #{rtest |> length}" |> IO.inspect()
  r |> IO.inspect()

  "novelty #{ntest |> length}" |> IO.inspect()
  n |> IO.inspect()
end
