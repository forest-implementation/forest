# MIX_ENV=example mix run example/totospust.ex

Code.require_file("data_preparator/data_preparator.ex", __DIR__)
Code.require_file("array_splitter/array_splitter.ex", __DIR__)

# ============================================================
#  Generates ROC CSVs for Python plotter:
#    csv/adjusted/<dataset>_<tag>.csv
#    csv/mad/<dataset>_<tag>.csv
#    csv/zscore_more_trees/<dataset>_<tag>.csv
#
#  Each CSV: two columns without header: FPR,TPR
#  Default trees: 100 for ALL methods (as requested)
# ============================================================

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

  def harmonic_num(n), do: 1..n |> Stream.map(&(1.0 / &1)) |> Enum.sum()

  def cfun(n) when n < 2, do: 0
  def cfun(2), do: 1

  def cfun(batch_size) do
    2 * harmonic_num(batch_size - 1) - 2 * (batch_size - 1) / batch_size
  end

  # confusion helpers (kept for potential reuse)
  def f1_score({tn, f_n, fp, tp}) do
    precision = if tp + fp > 0, do: tp / (tp + fp), else: 0.0
    recall = if tp + f_n > 0, do: tp / (tp + f_n), else: 0.0

    if precision + recall > 0 do
      2 * (precision * recall) / (precision + recall)
    else
      0.0
    end
  end

  def preprocess(dataset_name) do
    %{"TA" => regular_test, "TR" => regular_train} =
      DataPreparator.adbench("example/data/adbench/csv/#{dataset_name}_TTV.csv", -2)

    %{"TE" => novelty_test} =
      DataPreparator.adbench("example/data/adbench/csv/#{dataset_name}_TV.csv", -2)

    {regular_train, regular_test, novelty_test, dataset_name}
  end

  # MUST be public so we can pass it as a function reference
  def anomaly_score_map(forest, x, batch_size) do
    forest
    |> Forest.evaluate(x, &Service.Novelty.decision/2)
    |> Enum.map(fn
      %{data: data, depth: depth} -> depth + cfun(length(data))
    end)
    |> Service.Novelty.anomaly_score(batch_size, &cfun/1)
    |> then(fn res -> {x, res} end)
  end

  def auc(roc_data) do
    roc_data
    |> Enum.sort_by(fn {fpr, _} -> fpr end)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [{fpr1, tpr1}, {fpr2, tpr2}] ->
      (fpr2 - fpr1) * (tpr1 + tpr2) / 2
    end)
    |> Enum.sum()
  end

  # ============================================================
  # Experiment
  #   Exports ROC to: csv/<method_key>/<dataset_name>_<run_tag>.csv
  #   Format: 2 cols, no header: FPR,TPR
  # ============================================================
  def experiment(
        {train, rtest, ntest, dataset_name},
        robustfun,
        _anomaly_treshold \\ nil,
        tree_count \\ 100,
        scorefun \\ &__MODULE__.anomaly_score_map/3,
        batch_size \\ 1024,
        orientation \\ :gt,
        out_dir \\ "csv",
        method_key \\ "method",
        run_tag \\ "t100"
      ) do
    IO.inspect(dataset_name, label: "dataset")

	dim_count = length(Enum.at(train, 0)) - 1

	ranges =
	  0..dim_count
	  |> Enum.map(fn j ->
	    col = Enum.map(train, &Enum.at(&1, j))
	    uniq = col |> Enum.uniq()

	    cond do
	      # binární dimenze → explicitně [0,1]
	      uniq == [0, 1] or uniq == [1, 0] ->
		{0.0, 1.0}

	      # konstantní dimenze → zahodíme později
	      length(uniq) == 1 ->
		{hd(uniq), hd(uniq)}

	      # normální spojitá dimenze → robustní range
	      true ->
		robustfun.(train, j)
	    end
	  end)

	nozero =
	  ranges
	  |> nonzeroindices()
	  |> IO.inspect(label: "beru pouze dimenze:")

	f_train = train |> Enum.map(fn row -> take(row, nozero) end)
	f_init_range = take(ranges, nozero)


    forest =
      Forest.init(
        tree_count,
        %{data: f_train, ranges: f_init_range, batch_size: batch_size},
        Service.Novelty.make_split(ceil(cfun(length(f_train)))),
        &Service.Novelty.batch/2
      )

    # --- scores ---
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

    # --- monotonic sweep over unique scores ---
    combined = Enum.map(r_scores, &{&1, :r}) ++ Enum.map(n_scores, &{&1, :n})

    sorted =
      case orientation do
        :lt -> Enum.sort_by(combined, fn {s, _} -> s end, :asc)
        :gt -> Enum.sort_by(combined, fn {s, _} -> s end, :desc)
      end

    groups = Enum.chunk_by(sorted, fn {s, _} -> s end)

    init = %{tp: 0, fp: 0, fn_: n_total, tn: r_total, pts: [], rows: []}

    acc =
      Enum.reduce(groups, init, fn grp, acc0 ->
        {r_cnt, n_cnt} =
          Enum.reduce(grp, {0, 0}, fn
            {_s, :r}, {rr, nn} -> {rr + 1, nn}
            {_s, :n}, {rr, nn} -> {rr, nn + 1}
          end)

        tp2 = acc0.tp + n_cnt
        fp2 = acc0.fp + r_cnt
        fn2 = acc0.fn_ - n_cnt
        tn2 = acc0.tn - r_cnt

        tpr = safe_div.(tp2, tp2 + fn2)
        fpr = safe_div.(fp2, fp2 + tn2)
        th = elem(hd(grp), 0)

        %{
          tp: tp2,
          fp: fp2,
          fn_: fn2,
          tn: tn2,
          pts: acc0.pts ++ [{th, fpr, tpr}],
          rows: acc0.rows ++ [{th, fp2, tp2, fn2, tn2}]
        }
      end)

    # sentinels + neighbor dedup
    roc_pts =
      ([{0.0, 0.0, 0.0}] ++ acc.pts ++ [{1.0, 1.0, 1.0}])
      |> Enum.reduce([], fn {th, fpr, tpr}, out ->
        case out do
          [] -> [{th, fpr, tpr}]
          [{_, pf, pt} | _] = a when pf == fpr and pt == tpr -> a
          _ -> out ++ [{th, fpr, tpr}]
        end
      end)

    # (optional) compute AUC (not required by your ROC plotter)
    _auc_value =
      roc_pts
      |> Enum.map(fn {_th, fpr, tpr} -> {fpr, tpr} end)
      |> auc()

    # ============================================================
    # Export for Python plotter (two columns, no header)
    # ============================================================
    method_dir = Path.join([out_dir, method_key])
    File.mkdir_p!(method_dir)

    roc_by_fpr =
      roc_pts
      |> Enum.sort_by(fn {_th, fpr, _tpr} -> fpr end)

    body =
      roc_by_fpr
      |> Enum.map(fn {_th, fpr, tpr} -> "#{fpr},#{tpr}" end)
      |> Enum.join("\n")

    out_path = Path.join(method_dir, "#{dataset_name}_#{run_tag}.csv")
    File.write!(out_path, body)

    IO.puts("Saved ROC: #{out_path}")

    :ok
  end
end

# ============================================================
# Discover datasets
# ============================================================
datasets =
  File.ls("example/data/adbench/csv")
  |> then(fn
    {:ok, filenames} ->
      filenames
      |> Stream.map(&Regex.run(~r/^((\d+)_[a-zA-Z.]+)\.csv$/, &1))
      |> Stream.reject(&is_nil/1)
      |> Enum.sort_by(&String.to_integer(Enum.at(&1, 2)))
      |> Enum.map(&Enum.at(&1, 1))

    _ ->
      []
  end)
  |> Enum.reject(fn dataset -> Enum.member?(["3_backdoor", "9_census"], dataset) end)
  #|> Enum.filter(fn dataset -> Enum.member?(["8_celeba"], dataset) end)
  |> IO.inspect(label: "datasets")

# ============================================================
# Runs (ALL with 100 trees as requested)
# Folder structure matches the Python plotter:
#   csv/adjusted
#   csv/mad
#   csv/zscore_more_trees
# File name pattern: <dataset>_<tag>.csv
# ============================================================
runs = [
  %{
    key: "adjusted",
    tag: "t100",
    trees: 100,
    robust: fn x, y -> Statistex.Robust.adjusted_box(x, y) end
  },
  %{
    key: "mad",
    tag: "t100",
    trees: 100,
    robust: fn x, y -> Statistex.Robust.mad(x, 12, y) end
  },
  %{
    key: "zscore_more_trees",
    tag: "t100",
    trees: 100,
    robust: fn x, y -> Statistex.Robust.z_score(x, 3, y) end
  }
]

# ============================================================
# Execute
# ============================================================
for dataset <- datasets do
  IO.inspect(dataset, label: "Dataset")
  tt = Preprocessor.preprocess(dataset)

  for r <- runs do
    IO.inspect({dataset, r.key, r.tag, r.trees}, label: "RUN")

    Preprocessor.experiment(
      tt,
      r.robust,
      nil,
      r.trees,
      &Preprocessor.anomaly_score_map/3,
      1024,
      :gt,
      "csv",
      r.key,
      r.tag
    )
  end
end
