# MIX_ENV=example mix run example/adbench_roc.ex

Code.require_file("data_preparator/data_preparator.ex", __DIR__)
Code.require_file("array_splitter/array_splitter.ex", __DIR__)

# spocita roc a ulozi do csv/ pro kazdy dataset

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

  defp hfun(x) when x < 100, do: H.h(x)

  defp hfun(count) do
    :math.log2(count) + 1.333
  end

  # defp hfun(n) when n <= 1, do: 0.0

  # defp hfun(n) when n < 100 do
  #   h = Enum.reduce(1..(n - 1), 0.0, fn k, acc -> acc + 1.0 / k end)
  #   2 * h - (2 * (n - 1) / n)
  # end

  # defp hfun(n) do
  #   h = :math.log(n - 1) + 0.5772156649
  #   2 * h - (2 * (n - 1) / n)
  # end

  # recall, sensitivity
  defp tpr({tp, f_n, _fp, _tn}), do: tp / (tp + f_n)

  defp fpr({_tp, _f_n, fp, tn}), do: fp / (fp + tn)

  # precision
  defp ppv({tp, _f_n, fp, _tn}), do: tp / (tp + fp + 0.000001)

  defp for({_tp, f_n, _fp, tn}), do: f_n / (f_n + tn)

  # specificity
  defp tnr({_tp, _f_n, fp, tn}), do: tn / (fp + tn)

  defp fbeta(precision, recall, b) do
    (1 + b * b) * (precision * recall) / (b * b * precision + recall)
  end

  defp fbeta2({tp, f_n, fp, tn}, b) do
    (1 + b * b) * tp / ((1 + b * b) * tp + fp + 1.5 + b * b * f_n)
  end

  defp roc(tpr, fpr), do: tpr / (fpr + 0.000001)

  defp youden(tpr, fpr), do: tpr - fpr

  def preprocess(dataset_name) do
    %{"TE" => regular_test, "TR" => regular_train} =
      DataPreparator.adbench("example/data/adbench/csv/#{dataset_name}_TTV.csv", -2)

    %{"TE" => novelty_test} =
      DataPreparator.adbench("example/data/adbench/csv/#{dataset_name}_TV.csv", -2)

    {regular_train, regular_test, novelty_test, dataset_name}
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

  def auc(roc_data) do
    # ROC data je list tuple (FPR, TPR) seřazený podle FPR
    roc_data
    # Seřadíme podle FPR
    |> Enum.sort_by(fn {fpr, _} -> fpr end)
    # Vezmeme sousední dvojice
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [{fpr1, tpr1}, {fpr2, tpr2}] ->
      # Trapezoidální pravidlo: (b-a) * (f(a) + f(b)) / 2
      (fpr2 - fpr1) * (tpr1 + tpr2) / 2
    end)
    # Sečteme plochy pod křivkou
    |> Enum.sum()
  end

  def experiment(
        {train, rtest, ntest, dataset_name},
        robustfun,
        anomaly_treshold \\ 00000..10000//1 |> Enum.map(&(&1 / 10000)),
        tree_count \\ 100,
        scorefun \\ &anomaly_score_map/3,
        batch_size \\ min(1024, 1024)
      ) do
    # Inicializační rozsahy podle robustní funkce
    init_range =
      0..(length(Enum.at(train, 0)) - 1)
      |> Enum.map(&robustfun.(train, &1))

    nozero = init_range |> nonzeroindices
    f_train = train |> Enum.map(&take(&1, nozero))
    f_init_range = take(init_range, nozero)

    # Vytvoření lesa
    forest =
      Forest.init(
        tree_count,
        %{data: f_train, ranges: f_init_range, batch_size: batch_size},
        Service.Novelty.make_split(ceil(hfun(length(f_train)))),
        &Service.Novelty.batch/2
      )

    # Vyhodnocení skóre pro rtest
    r1 =
      rtest
      |> Enum.map(&scorefun.(forest, &1, batch_size))
      |> then(fn s ->
        Enum.map(anomaly_treshold, &{&1, Enum.count(s, fn {[_ | _], score} -> score < &1 end)})
      end)

    # Vyhodnocení skóre pro ntest
    n1 =
      ntest
      |> Enum.map(&scorefun.(forest, &1, batch_size))
      |> then(fn s ->
        Enum.map(anomaly_treshold, &{&1, Enum.count(s, fn {[_ | _], score} -> score < &1 end)})
      end)

    # Výpočet TPR, FPR a Youdenova indexu pro všechny thresholdy
    statfun =
      Enum.zip_with([r1, n1], fn [{threshold, r}, {threshold, n}] ->
        tp = r
        fp = n
        fn_ = length(rtest) - r
        tn = length(ntest) - n

        tpr = tpr({tp, fn_, fp, tn})
        fpr = fpr({tp, fn_, fp, tn})
        youden_index = youden(tpr, fpr)

        {threshold, youden_index}
      end)

    # Najdi nejlepší threshold podle Youdenova indexu
    {best_threshold, best_youden} = Enum.max_by(statfun, fn {_, y} -> y end)

    # Najdi hodnotu Youdenova indexu pro threshold = 0.5
    {_t_05, y_05} = Enum.at(statfun, 5000)

    # Zapiš výsledek do CSV řádku
    File.write!(
      "csv/youdens/summary_#{dataset_name}.csv",
      "#{dataset_name},#{best_threshold},#{best_youden},0.5,#{y_05}\n"
    )

    {"AUC", 0.5}
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
  # specify files to SKIP
  |> Enum.reject(fn dataset -> Enum.member?(["3_backdoor", "9_census"], dataset) end)
  |> IO.inspect()

# or specify your own
# datasets = ["1_ALOI", "2_annthyroid", "3_backdoor", "4_breastw"]

for dataset <- datasets do
  IO.inspect(dataset, label: "Dataset")
  {_, rtest, ntest, dataset_name} = tt = Preprocessor.preprocess(dataset)
  IO.inspect(dataset_name)

  # specify statistics
  {r, n} = Preprocessor.experiment(tt, fn x, y -> Statistex.Robust.z_score(x, 3, y) end)
  # {r, n} = Preprocessor.experiment(tt, fn x, y -> Statistex.Robust.adjusted_box(x, y) end)

  "regular #{rtest |> length}" |> IO.inspect()
  r |> IO.inspect()

  "novelty #{ntest |> length}" |> IO.inspect()
  n |> IO.inspect()
end
