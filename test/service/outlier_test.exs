defmodule ServiceOutlierTest do
  use ExUnit.Case

  test "split_data_one_element" do
    assert [[5]] |> Service.Outlier.split_data() == {%{data: [5], depth: 0}}
    :rand.seed(:exsplus, {12245, 67890, 54321})

    assert [[5], [6], [7]] |> Service.Outlier.split_data() ==
             {{0, 5.7850339582840675}, %{data: [[5]], depth: 1, max_depth: 2.0}, %{data: [[6], [7]], depth: 1, max_depth: 2.0}}

    assert %{:data => [[5], [6], [7]],:max_depth => 8, :depth => 7} |> Service.Outlier.split_data() ==
             {{0, 6.217725558581396}, %{data: [[5], [6]], depth: 8, max_depth: 8}, %{data: [[7]], depth: 8, max_depth: 8}}
  end

  test "from_data_outlier" do
    :rand.seed(:exsplus, {12245, 67890, 54321})

    assert INode.from_data([[1]], &Service.Outlier.split_data/1) == %INode{
             carrier: %{data: [1], depth: 0},
             left: nil,
             right: nil
           }

    assert INode.from_data([[1], [2], [3]], &Service.Outlier.split_data/1) ==
             %INode{
               carrier: {0, 1.785033958284068},
               left: %INode{carrier: %{data: [1], depth: 1}, left: nil, right: nil},
               right: %INode{
                 carrier: {0, 2.608862779290698},
                 left: %INode{carrier: %{data: [2], depth: 2}, left: nil, right: nil},
                 right: %INode{carrier: %{data: [3], depth: 2}, left: nil, right: nil}
               }
             }
  end

  test "find" do
    tree = INode.from_data([[1], [2], [3]], &Service.Outlier.split_data/1)
    assert INode.find([1], tree, &Service.Outlier.decision/2).data == [1]
  end

  test "sort init" do
    :rand.seed(:exsplus, {1224, 67892, 54321})

    assert INode.from_data(%{data: [[7], [2], [4], [1]], max_depth: 10}, &Service.Outlier.split_data/1)
           |> INode.leaves()
           |> Enum.map(fn %{data: x, depth: _} -> x end) == [
             [1],
             [2],
             [4],
             [7]
           ]
  end

  test "outlier forest" do
    :rand.seed(:exsplus, {1224, 64892, 54321})

    assert Forest.init(
             5,
             %{data: [[7], [2], [4], [1], [8], [9]], max_depth: 100},
             &Service.Outlier.split_data/1
           )
           |> Forest.evaluate([7], &Service.Outlier.decision/2)
           |> Enum.map(fn %{data: _, depth: d} -> d end) ==
             [4, 2, 3, 4, 3]

    assert Forest.init(
             5,
             %{data: [[7, 5], [2, 4], [4, 3], [1, 1], [8, 11], [9, 6]], max_depth: 100},
             &Service.Outlier.split_data/1
           )
           |> Forest.evaluate([7, 2], &Service.Outlier.decision/2)
           |> Enum.map(fn %{data: _, depth: d} -> d end) ==
             [1, 2, 4, 3, 3]
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

    forest =
      Forest.init(
        50,
        %{data: data, batch_size: length(data)},
        &Service.Outlier.split_data/1,
        &Service.Outlier.batch/2
      )

    # inliner
    forest
    |> Forest.evaluate([105, 20], &Service.Outlier.decision/2)
    |> Enum.map(fn %{data: _, depth: d} -> d end)
    |> IO.inspect()

    # anomaly - is more normal than inliner - thats bull****
    forest
    |> Forest.evaluate([25, 20], &Service.Outlier.decision/2)
    |> Enum.map(fn %{data: _, depth: d} -> d end)
    |> IO.inspect()
  end

  test "clanek data anomaly score" do
    :rand.seed(:exsplus, {1224, 64892, 54321})
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
        %{data: data, batch_size: batch_size},
        &Service.Outlier.split_data/1,
        &Service.Outlier.batch/2
      )

    # inliner - is > 0.6
    assert forest
    |> Forest.evaluate([105, 20], &Service.Outlier.decision/2)
    |> Enum.map(fn %{data: _, depth: d} -> d end)
    |> Service.Outlier.anomaly_score(batch_size) > 0.6

    # inline - is < 0.6
    assert forest
    |> Forest.evaluate([25, 20], &Service.Outlier.decision/2)
    |> Enum.map(fn %{data: _, depth: d} -> d end)
    |> Service.Outlier.anomaly_score(batch_size) < 0.6
  end

  test "data NOT UNIQUE" do
    #:rand.seed(:exsplus, {1224, 64892, 54321})
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
        %{data: data},
        &Service.Outlier.split_data/1,
        &Service.Outlier.batch/2
        )

    # inliner
    assert forest
    |> Forest.evaluate([105, 20], &Service.Outlier.decision/2)
    |> Enum.map(fn %{data: _, depth: d} -> d end)
    |> Service.Outlier.anomaly_score(batch_size) > 0.6 # this should not be

    assert forest
    |> Forest.evaluate([25, 20], &Service.Outlier.decision/2)
    |> Enum.map(fn %{data: _, depth: d} -> d end)
    |> Service.Outlier.anomaly_score(batch_size) < 0.6
  end
end
