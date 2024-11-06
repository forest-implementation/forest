Code.require_file("data_preparator/data_preparator.ex", __DIR__)
Code.require_file("array_splitter/array_splitter.ex", __DIR__)

defmodule Preprocessor do
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
      %{data: data, depth: depth} -> depth + H.h(length(data))
    end)
    |> Service.Novelty.anomaly_score(batch_size)
    |> then(fn res -> {x, res} end)
  end

  def experiment(
        {train, rtest, ntest},
        robustfun,
        anomaly_treshold \\ 0.5,
        tree_count \\ 50,
        scorefun \\ &anomaly_score_map/3
      ) do
    # 10% batch size
    batch_size = div(length(train), 10)

    init_range =
      0..(length(Enum.at(train, 0)) - 1)
      |> Enum.map(&robustfun.(train, &1))

    # |> Enum.map(&Statistex.Robust.adjusted_box(train, &1))

    forest =
      Forest.init(
        tree_count,
        %{data: train, ranges: init_range, batch_size: batch_size},
        Service.Novelty.make_split(ceil(:math.log2(length(train) + 2))),
        &Service.Novelty.batch/2
      )

    r1 =
      rtest
      |> Enum.map(&scorefun.(forest, &1, batch_size))
      |> Enum.count(fn {[_ | _], score} -> score < anomaly_treshold end)

    n1 =
      ntest
      |> Enum.map(&scorefun.(forest, &1, batch_size))
      |> Enum.count(fn {[_ | _], score} -> score >= anomaly_treshold end)

    {r1, n1}
  end
end

# TODO: VYRESIT KAM TOTO PUSHNOUT

# TODO: TENTO SOUBOR BUDE SLOUZIT PRO NASTAVOVANI PARAMETRU ATP
# MUZE SE SPOUSTET FURT DOKOLA NA SPECIFIKOVANYCH DATASETECH A SPECIFIKOVANCYH robust funkcich

# TODO: pak bude dalsi soubor ktery bude uz experiment spoustet s parametry co si myslime ze jsou nejlepsi
# a s validacnim csv (vlastne jen vymenis ve funkci priponu pred csv)
# ten uz se spustit jen jednou a jeho vysledky pujdou do clanku

# TODO: VYRESIT kdyz je range {0,0}

# TODO: udelej nejaky for ve forku ktery to projde cele
# datasets = ["2_annthyroid", "..."]
{_, rtest, ntest} = tt = Preprocessor.preprocess("3_backdoor")
{r, n} = Preprocessor.experiment(tt, fn x, y -> Statistex.Robust.z_score(x, 3, y) end)
"regular #{rtest |> length}" |> IO.inspect()
r |> IO.inspect()

"novelty #{ntest |> length}" |> IO.inspect()
n |> IO.inspect()
