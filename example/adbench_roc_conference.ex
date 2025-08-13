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
      _anomaly_treshold \\ nil,   # prahy bereme z reálných skóre
      tree_count \\ 100,
      scorefun \\ &anomaly_score_map/3,
      batch_size \\ min(1024, 1024),
      orientation \\ :gt          # :lt => score < threshold je novelty; :gt => score > threshold
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
      Service.Novelty.make_split(ceil(cfun(length(f_train)))),
      &Service.Novelty.batch/2
    )

  # --- skóre dopředu ---
  r_scores =
    rtest
    |> Enum.map(&scorefun.(forest, &1, batch_size))
    |> Enum.map(fn {_, score} -> score end)

  n_scores =
    ntest
    |> Enum.map(&scorefun.(forest, &1, batch_size))
    |> Enum.map(fn {_, score} -> score end)

  r_total = length(r_scores)
  n_total = length(n_scores)

  safe_div = fn
    _num, 0 -> 0.0
    num, den -> num / den
  end

  # --- monotónní sweep přes unikátní skóre ---
  # Pokud je orientation :lt (score<th => novelty), třídíme vzestupně.
  # Pokud je :gt (score>th => novelty), třídíme sestupně.
  combined =
    Enum.map(r_scores, &{&1, :r}) ++ Enum.map(n_scores, &{&1, :n})

  sorted =
    case orientation do
      :lt -> Enum.sort_by(combined, fn {s, _} -> s end, :asc)
      :gt -> Enum.sort_by(combined, fn {s, _} -> s end, :desc)
    end

  groups = Enum.chunk_by(sorted, fn {s, _} -> s end)

  # start: nic ještě není „pozitivní“ (pod/přes práh podle orientation)
  init = %{tp: 0, fp: 0, fn_: n_total, tn: r_total, pts: [], rows: []}

  acc =
    Enum.reduce(groups, init, fn grp, acc0 ->
      {r_cnt, n_cnt} =
        Enum.reduce(grp, {0, 0}, fn
          {_s, :r}, {rr, nn} -> {rr + 1, nn}
          {_s, :n}, {rr, nn} -> {rr, nn + 1}
        end)

      # přelití celého bloku do „pozitivních“
      tp2 = acc0.tp + n_cnt
      fp2 = acc0.fp + r_cnt
      fn2 = acc0.fn_ - n_cnt
      tn2 = acc0.tn - r_cnt

      tpr = safe_div.(tp2, tp2 + fn2)
      fpr = safe_div.(fp2, fp2 + tn2)
      th  = elem(hd(grp), 0)

      %{
        tp: tp2, fp: fp2, fn_: fn2, tn: tn2,
        pts: acc0.pts ++ [{th, fpr, tpr}],
        rows: acc0.rows ++ [{th, fp2, tp2, fn2, tn2}]
      }
    end)

  # sentinely + deduplikace sousedů
  roc_pts =
    ([{0.0, 0.0, 0.0}] ++ acc.pts ++ [{1.0, 1.0, 1.0}])
    |> Enum.reduce([], fn {th, fpr, tpr}, out ->
      case out do
        [] -> [{th, fpr, tpr}]
        [{_, pf, pt} | _] = a when pf == fpr and pt == tpr -> a
        _ -> out ++ [{th, fpr, tpr}]
      end
    end)

  auc_value =
    roc_pts
    |> Enum.map(fn {_th, fpr, tpr} -> {fpr, tpr} end)
    |> auc()

  # --- výstupy do CSV ---
  File.mkdir_p!("conference/csv_our2/roc_curves")
  File.mkdir_p!("conference/csv_our2/auc")
  File.mkdir_p!("conference/csv_our2/confusion")

  roc_by_fpr = roc_pts |> Enum.sort_by(fn {_th, fpr, _tpr} -> fpr end)
  File.write!("conference/csv_our2/roc_curves/#{dataset_name}.csv",
    (["threshold,fpr,tpr"] ++ Enum.map(roc_by_fpr, fn {th, fpr, tpr} -> "#{th},#{fpr},#{tpr}" end))
    |> Enum.join("\n")
  )

  roc_by_th = roc_pts |> Enum.sort_by(fn {th, _fpr, _tpr} -> th end)
  File.write!("conference/csv_our2/roc_curves/#{dataset_name}_by_threshold.csv",
    (["threshold,fpr,tpr"] ++ Enum.map(roc_by_th, fn {th, fpr, tpr} -> "#{th},#{fpr},#{tpr}" end))
    |> Enum.join("\n")
  )

  File.write!("conference/csv_our2/auc/#{dataset_name}.csv", "auc\n#{auc_value}\n")

  conf_rows =
    Enum.map(acc.rows, fn {th, fp, tp, fn_, tn} ->
      tpr_val = safe_div.(tp, tp + fn_)
      fpr_val = safe_div.(fp, fp + tn)
      precision = safe_div.(tp, tp + fp)
      recall    = tpr_val
      f1 = f1_score({tn, fn_, fp, tp})
      "#{th},#{tp},#{fp},#{fn_},#{tn},#{tpr_val},#{fpr_val},#{precision},#{recall},#{f1}"
    end)

  File.write!("conference/csv_our2/confusion/#{dataset_name}.csv",
    (["threshold,tp,fp,fn,tn,tpr,fpr,precision,recall,f1"] ++ conf_rows)
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
