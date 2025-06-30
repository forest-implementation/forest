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

  defp cfun(0), do: 0
  defp cfun(x) when x < 100, do: H.h(x)

  defp cfun(count) do
    :math.log2(count) + 1.332
  end

  # jen pokus, zkusime jak to vyjde se starym c
  def harmonic_num(n) do
    1..n |> Stream.map(&(1.0 / &1)) |> Enum.sum()
  end

  def old_c_fun(n) when n < 2, do: 0
  def old_c_fun(2), do: 1

  def old_c_fun(batch_size) do
    2 * harmonic_num(batch_size - 1) - 2 * (batch_size - 1) / batch_size
  end

  # recall, sensitivity
  defp tpr({tp, f_n, _fp, _tn}), do: tp / (tp + f_n)

  defp fpr({_tp, _f_n, fp, tn}), do: fp / (fp + tn)

  # precision
  defp ppv({tp, _f_n, fp, _tn}), do: tp / (tp + fp)

  defp for({_tp, f_n, _fp, tn}), do: f_n / (f_n + tn)

  # specificity
  defp tnr({_tp, _f_n, fp, tn}), do: tn / (fp + tn)

  defp fbeta(precision, recall, b) do
    (1 + b * b) * (precision * recall) / (b * b * precision + recall)
  end

  defp fbeta2({tp, f_n, fp, tn}, b) do
    (1 + b * b) * tp / ((1 + b * b) * tp + fp + 1.5 + b * b * f_n)
  end

  def f1_score({tn, f_n, fp, tp}) do
    precision = if tp + fp > 0, do: tp / (tp + fp), else: 0.0
    recall = if tp + f_n > 0, do: tp / (tp + f_n), else: 0.0

    if precision + recall > 0 do
      2 * (precision * recall) / (precision + recall)
    else
      0.0
    end
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
      %{data: data, depth: depth} -> depth + cfun(length(data))
    end)
    |> Service.Novelty.anomaly_score(batch_size, &cfun/1)
    |> then(fn res -> {x, res} end)
  end

def auc(roc_data) do
  # ROC data je list tuple (FPR, TPR) seřazený podle FPR
  roc_data
  |> Enum.sort_by(fn {fpr, _} -> fpr end)  # Seřadíme podle FPR
  |> Enum.chunk_every(2, 1, :discard)  # Vezmeme sousední dvojice
  |> Enum.map(fn [{fpr1, tpr1}, {fpr2, tpr2}] ->
    # Trapezoidální pravidlo: (b-a) * (f(a) + f(b)) / 2
    (fpr2 - fpr1) * (tpr1 + tpr2) / 2
  end)
  |> Enum.sum()  # Sečteme plochy pod křivkou
end

def experiment(
        {train, rtest, ntest, dataset_name},
        robustfun,
        anomaly_treshold \\ 00000..2000//1 |> Enum.map(&(&1 / 100)),
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
        # TODO: SET DEPTH FIXED
        Service.Novelty.make_split(16),
        # Service.Novelty.make_split(ceil(old_c_fun(length(f_train)))),
        &Service.Novelty.batch/2
      )

    r1 =
      rtest
      |> Enum.map(&scorefun.(forest, &1, batch_size))
      |> then(fn s ->
        Enum.map(anomaly_treshold, &{&1, Enum.count(s, fn {[_ | _], score} -> score < &1 end)})
      end)

    n1 =
      ntest
      |> Enum.map(&scorefun.(forest, &1, batch_size))
      |> then(fn s ->
        Enum.map(anomaly_treshold, &{&1, Enum.count(s, fn {[_ | _], score} -> score < &1 end)})
      end)

    roc =
      Enum.zip_with([r1, n1], fn [{threshold, r}, {threshold, n}] ->
        tp = r
        fp = n
        f_n = (rtest |> length) - r
        tn = (ntest |> length) - n
        ctverice = {tp, f_n, fp, tn}

        tpr = tpr(ctverice)
        fpr = fpr(ctverice)
        {threshold, fbeta2(ctverice, 2), tpr, fpr}
      end)
      |> Enum.map(fn {_thresh, _fb, tpr, fpr} -> {fpr, tpr} end)

    auc_value = auc(roc)

    results =
      Enum.zip_with([r1, n1], fn [{threshold, r}, {threshold, n}] ->
        tp = r
        fp = n
        f_n = (rtest |> length) - r
        tn = (ntest |> length) - n
        ctverice = {tp, f_n, fp, tn}
        {threshold, f1_score(ctverice), f_n, fp, tp}
      end)

    File.write!("csv/fbeta_new/threshold_fbeta_#{dataset_name}.csv",
      results
      |> Enum.map(fn {threshold, fbeta, f_n,fp, tp} -> "#{threshold},#{f_n},#{fp},#{tp},#{fbeta}" end)
      |> Enum.join("\n")
    )

    {"AUC", auc_value}
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

  # {r, n} = Preprocessor.experiment(tt, fn x, y -> Statistex.Robust.mad(x, 12, y) end)
  {r, n} = Preprocessor.experiment(tt, fn x, y -> Statistex.Robust.z_score(x, 3, y) end)
  # {r, n} = Preprocessor.experiment(tt, fn x, y -> Statistex.Robust.adjusted_box(x, y) end)
  # bootstrap trva hrozne dlouho
  # {r, n} = Preprocessor.experiment(tt, fn x, y -> Statistex.Robust.Bootstrap.extrapolate(x, 100, 0.3 ,y) end)

  "regular #{rtest |> length}" |> IO.inspect()
  r |> IO.inspect()

  "novelty #{ntest |> length}" |> IO.inspect()
  n |> IO.inspect()
end
