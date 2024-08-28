defmodule ServiceOutlierTest do
  use ExUnit.Case

  test "split_data_one_element" do
    assert [[5], [6]] |> Service.Outlier.make_split(5).() ==
             {{0, 5.046691108058286}, %{data: [[5]], depth: 1}, %{data: [[6]], depth: 1}}

    assert [[5]] |> Service.Outlier.make_split(5).() == {%{data: [5], depth: 0}}
  end

  test "from_data_outlier" do
    assert INode.from_data([[1]], Service.Outlier.make_split(10)) == %INode{
             carrier: %{data: [1], depth: 0},
             left: nil,
             right: nil
           }

    assert INode.from_data([[1], [2], [3]], Service.Outlier.make_split(20)) ==
             %INode{
               carrier: {0, 1.4974679567297466},
               left: %INode{carrier: %{data: [1], depth: 1}, left: nil, right: nil},
               right: %INode{
                 carrier: {0, 2.6275690828317555},
                 left: %INode{carrier: %{data: [2], depth: 2}, left: nil, right: nil},
                 right: %INode{carrier: %{data: [3], depth: 2}, left: nil, right: nil}
               }
             }
  end

  test "find" do
    tree = INode.from_data([[1], [2], [3]], Service.Outlier.make_split(20))
    assert INode.find([1], tree, &Service.Outlier.decision/2).data == [1]
  end

  test "sort init" do
    assert INode.from_data(
             %{data: [[7], [2], [4], [1]], max_depth: 10},
             Service.Outlier.make_split(20)
           )
           |> INode.leaves()
           |> Enum.map(fn %{data: x, depth: _} -> x end) == [
             [1],
             [2],
             [4],
             [7]
           ]
  end

  test "outlier forest" do
    assert Forest.init(
             5,
             %{data: [[7], [2], [4], [1], [8], [9]], max_depth: 100},
             Service.Outlier.make_split(20)
           )
           |> Forest.evaluate([7], &Service.Outlier.decision/2)
           |> Enum.map(fn %{data: _, depth: d} -> d end) ==
             [3, 3, 2, 4, 4]

    assert Forest.init(
             5,
             %{data: [[7, 5], [2, 4], [4, 3], [1, 1], [8, 11], [9, 6]], max_depth: 100},
             Service.Outlier.make_split(20)
           )
           |> Forest.evaluate([7, 2], &Service.Outlier.decision/2)
           |> Enum.map(fn %{data: _, depth: d} -> d end) ==
             [4, 2, 4, 3, 4]
  end

  test "clanek data" do
    # :rand.seed(:exsplus, {1224, 64892, 54321})

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
        Service.Outlier.make_split(20),
        &Service.Outlier.batch/2
      )

    # inliner
    assert forest
           |> Forest.evaluate([105, 20], &Service.Outlier.decision/2)
           |> Enum.map(fn %{data: _, depth: d} -> d end) ==
             [
               2,
               7,
               3,
               5,
               4,
               6,
               2,
               7,
               5,
               5,
               7,
               3,
               2,
               5,
               4,
               4,
               3,
               2,
               4,
               2,
               4,
               6,
               5,
               3,
               4,
               3,
               5,
               3,
               4,
               5,
               2,
               3,
               4,
               4,
               2,
               1,
               3,
               5,
               3,
               1,
               2,
               2,
               4,
               3,
               2,
               4,
               4,
               4,
               4,
               4
             ]

    # anomaly - is more normal than inliner - thats bull****
    assert forest
           |> Forest.evaluate([25, 20], &Service.Outlier.decision/2)
           |> Enum.map(fn %{data: _, depth: d} -> d end) ==
             [
               5,
               5,
               5,
               5,
               4,
               6,
               4,
               5,
               4,
               5,
               7,
               4,
               4,
               4,
               5,
               4,
               5,
               4,
               4,
               5,
               5,
               5,
               4,
               6,
               7,
               4,
               4,
               4,
               4,
               4,
               5,
               4,
               4,
               4,
               5,
               5,
               6,
               6,
               6,
               5,
               5,
               4,
               4,
               5,
               5,
               4,
               5,
               4,
               4,
               5
             ]
  end

  test "clanek data anomaly score" do
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
      [90, 10]
    ]

    batch_size = length(data)

    forest =
      Forest.init(
        50,
        %{data: data, batch_size: batch_size},
        Service.Outlier.make_split(20),
        &Service.Outlier.batch/2
      )

    # inliner - is > 0.6
    assert forest
           |> Forest.evaluate([105, 20], &Service.Outlier.decision/2)
           |> Enum.map(fn %{data: _, depth: d} -> d end)
           |> Service.Outlier.anomaly_score(batch_size) > 0.5

    # inline - is < 0.6
    assert forest
           |> Forest.evaluate([25, 20], &Service.Outlier.decision/2)
           |> Enum.map(fn %{data: _, depth: d} -> d end)
           |> Service.Outlier.anomaly_score(batch_size) < 0.6
  end

  test "data NOT UNIQUE" do
    # :rand.seed(:exsplus, {1224, 64892, 54321})
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
        Service.Outlier.make_split(20),
        &Service.Outlier.batch/2
      )

    # inliner
    assert forest
           |> Forest.evaluate([105, 20], &Service.Outlier.decision/2)
           |> Enum.map(fn %{data: _, depth: d} -> d end)
           # this should not be
           |> Service.Outlier.anomaly_score(batch_size) > 0.5

    assert forest
           |> Forest.evaluate([25, 20], &Service.Outlier.decision/2)
           |> Enum.map(fn %{data: _, depth: d} -> d end)
           |> Service.Outlier.anomaly_score(batch_size) < 0.6
  end
end
