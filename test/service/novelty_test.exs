defmodule ServiceNoveltyTest do
  use ExUnit.Case

  test "make split" do
    assert %{data: [[5]], ranges: {-10, 10}} |> Service.Novelty.make_split(5).() ==
             {%{data: [[5]], ranges: {-10, 10}, depth: 0}}

    assert [[5], [6]] |> Service.Outlier.make_split(5).() ==
             {{0, 5.811948033218323}, %{data: [[5]], depth: 1}, %{data: [[6]], depth: 1}}
  end

  test "from_data_Novelty" do
    assert INode.from_data(%{:data => [[1]], :ranges => [{1, 3}]}, Service.Novelty.make_split(50)) ==
             %INode{
               carrier: %{data: [[1]], depth: 0, ranges: [{1, 3}]},
               left: nil,
               right: nil
             }

    assert INode.from_data(
             %{:data => [[1], [2], [3]], :ranges => [{1, 3}]},
             Service.Novelty.make_split(50)
           ) ==
             %INode{
               carrier: {0, 2},
               left: %INode{
                 carrier: %{data: [[1]], depth: 1, ranges: [{1, 2}]},
                 left: nil,
                 right: nil
               },
               right: %INode{
                 carrier: {0, 2.5},
                 left: %INode{
                   carrier: %{data: [[2]], depth: 2, ranges: [{2, 2.5}]},
                   left: nil,
                   right: nil
                 },
                 right: %INode{
                   carrier: %{data: [[3]], depth: 2, ranges: [{2.5, 3}]},
                   left: nil,
                   right: nil
                 }
               }
             }
  end

  test "clanek data" do
    data = [
      [25, 100],
      [30, 90],
      [20, 90],
      [35, 85],
      [25, 85],
      [15, 85],
      [105, 20],
      [95, 25],
      [95, 15],
      [90, 30],
      [90, 20],
      [90, 10]
    ]

    batch_size = length(data)

    forest =
      Forest.init(
        50,
        %{data: data, ranges: [{0, 110}, {-5, 105}], batch_size: batch_size},
        Service.Novelty.make_split(50),
        &Service.Novelty.batch/2
      )

    assert forest
           |> Forest.evaluate([105, 20], &Service.Outlier.decision/2)
           |> Enum.map(fn %{data: _, depth: d} -> d end)
           |> Service.Novelty.anomaly_score(batch_size) < 0.5

    assert forest
           |> Forest.evaluate([25, 20], &Service.Outlier.decision/2)
           |> Enum.map(fn %{data: _, depth: d} -> d end)
           |> Service.Novelty.anomaly_score(batch_size) > 0.6
  end

  test "clanek data NOT UNIQUE" do
    data = [
      [25, 100],
      [30, 90],
      [20, 90],
      [35, 85],
      [25, 85],
      [15, 85],
      [105, 20],
      [95, 25],
      [95, 15],
      [90, 30],
      [90, 20],
      [90, 10],
      [90, 10]
    ]

    batch_size = length(data)

    forest =
      Forest.init(
        50,
        %{data: data, ranges: [{0, 110}, {-5, 105}], batch_size: batch_size},
        Service.Novelty.make_split(50),
        &Service.Novelty.batch/2
      )

    assert forest
           |> Forest.evaluate([25, 85], &Service.Outlier.decision/2)
           |> Enum.map(fn
             %{data: [], depth: depth} -> depth - 1
             %{data: data, depth: depth} -> depth + H.h(length(data))
           end)
           |> Service.Novelty.anomaly_score(batch_size)
           |> IO.inspect() < 0.5

    # 0.40 < 0.454H

    assert forest
           |> Forest.evaluate([25, 20], &Service.Outlier.decision/2)
           |> Enum.map(fn
             %{data: [], depth: depth} -> depth - 1
             %{data: data, depth: depth} -> depth + H.h(length(data))
           end)
           |> Service.Novelty.anomaly_score(batch_size)
           |> IO.inspect() > 0.6

    forest2 =
      Forest.init(
        50,
        %{data: data, ranges: [{0, 110}, {-5, 105}], batch_size: batch_size},
        Service.Novelty.make_split(50),
        &Service.Novelty.batch/2
      )

    assert forest2
           |> Forest.evaluate([105, 20], &Service.Outlier.decision/2)
           |> Enum.map(fn
             %{data: [], depth: depth} -> depth - 1
             %{data: data, depth: depth} -> depth + H.h(length(data))
           end)
           |> Service.Novelty.anomaly_score(batch_size)
           |> IO.inspect() < 0.5

    assert forest2
           |> Forest.evaluate([25, 20], &Service.Outlier.decision/2)
           |> Enum.map(fn
             %{data: [], depth: depth} -> depth - 1
             %{data: data, depth: depth} -> depth + H.h(length(data))
           end)
           |> Service.Novelty.anomaly_score(batch_size)
           |> IO.inspect() > 0.6

    # 0.636 < 0.673H
  end

  def anomaly_score_map(forest, x, batch_size) do
    forest
    |> Forest.evaluate(x, &Service.Outlier.decision/2)
    |> Enum.map(fn
      %{data: [], depth: depth} -> depth - 1
      %{data: data, depth: depth} -> depth + H.h(length(data))
    end)
    |> Service.Novelty.anomaly_score(batch_size)
    |> then(fn res -> {x, res} end)
  end

  test "score vsech bodu co mame" do
    :rand.seed(:exsplus, {13999, 2352, 15231})

    input_data = [
      [25, 100],
      [30, 90],
      [20, 90],
      [35, 85],
      [25, 85],
      [15, 85],
      [105, 20],
      [95, 25],
      [95, 15],
      [90, 30],
      [90, 20],
      [90, 10]
    ]

    batch_size = length(input_data)

    forest =
      Forest.init(
        50,
        %{data: input_data, ranges: [{0, 110}, {-5, 105}], batch_size: batch_size},
        Service.Novelty.make_split(ceil(H.h(length(input_data)))),
        &Service.Novelty.batch/2
      )

    test_data = [
      [25, 100],
      [30, 90],
      [20, 90],
      [35, 85],
      [25, 85],
      [15, 85],
      [105, 20],
      [95, 25],
      [95, 15],
      [90, 30],
      [90, 20],
      [90, 10],
      # novelty
      [25, 20],
      # novelty
      [55, 50],
      [100, 95],
      [35, 95]
    ]

    test_data
    |> Enum.map(&anomaly_score_map(forest, &1, batch_size))
    |> IO.inspect(charlists: :as_lists)
  end

  test "csv data" do
    %{"0" => regular, "1" => novelty} =
      Helper.MyCSVParser.load_csv("data/Banknote_Authentication.csv")
      |> Enum.group_by(fn row -> Enum.at(row, -1) end, fn val ->
        Enum.drop(val, -1) |> Enum.map(&String.to_float/1)
      end)

    [r70, r20, r10, _] = Helper.ArraySplitter.split(regular, [70, 20, 10])
    [n80, n20, _] = Helper.ArraySplitter.split(novelty, [80, 20])

    {length(r70), length(r20), length(r10), length(r70 ++ r20 ++ r10)}
    {length(n80), length(n20), length(n80 ++ n20)}

    # 10% of data
    batch_size = div(length(r70), 10)

    init_range =
      0..(length(Enum.at(r70, 0)) - 1)
      |> Enum.map(&Helper.Statistics.adjusted_box(r70, &1))

    forest =
      Forest.init(
        50,
        %{data: r70, ranges: init_range, batch_size: batch_size},
        Service.Novelty.make_split(ceil(H.h(length(r70)))),
        &Service.Novelty.batch/2
      )

    "novelty #{n80 |> length}" |> IO.inspect()

    n80
    |> Enum.map(&anomaly_score_map(forest, &1, batch_size))
    |> Enum.count(fn {[_|_], score} -> score > 0.6 end)
    |> IO.inspect(charlists: :as_lists)

    "regular #{r20 |> length}" |> IO.inspect()

    r20
    |> Enum.map(&anomaly_score_map(forest, &1, batch_size))
    |> Enum.count(fn {[_|_], score} -> score < 0.6 end)
    |> IO.inspect(charlists: :as_lists)
  end
end
