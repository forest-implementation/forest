defmodule ServiceNoveltyTest do
  use ExUnit.Case

  test "from_data_Novelty" do
    :rand.seed(:exsplus, {12245, 67890, 54321})

    assert INode.from_data(%{:data => [[1]], :ranges => [{1, 3}]}, &Service.Novelty.split_data/1) ==
             %INode{
               carrier: %{data: [1], depth: 0, ranges: [{1, 3}]},
               left: nil,
               right: nil
             }

    assert INode.from_data(
             %{:data => [[1], [2], [3]], :ranges => [{1, 3}]},
             &Service.Novelty.split_data/1
           ) ==
             %INode{
               carrier: {0, 2},
               left: %INode{
                 carrier: %{data: [1], depth: 1, ranges: [{1, 2}]},
                 left: nil,
                 right: nil
               },
               right: %INode{
                 carrier: {0, 2.5},
                 left: %INode{
                   carrier: %{data: [2], depth: 2, ranges: [{2, 2.5}]},
                   left: nil,
                   right: nil
                 },
                 right: %INode{
                   carrier: %{data: [3], depth: 2, ranges: [{2.5, 3}]},
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

    forest =
      Forest.init(
        50,
        %{data: data, ranges: [{0, 110}, {-5, 105}], batch_size: length(data)},
        &Service.Novelty.split_data/1,
        &Service.Novelty.batch/2
      )
      |> IO.inspect()

    forest
    |> Forest.evaluate([105, 20], &Service.Outlier.decision/2)
    |> Enum.map(fn %{data: _, depth: d} -> d end)
    |> IO.inspect()

    forest
    |> Forest.evaluate([25, 20], &Service.Outlier.decision/2)
    |> Enum.map(fn %{data: _, depth: d} -> d end)
    |> IO.inspect()
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
        %{data: data, ranges: [{0, 110}, {-5, 105}], batch_size: length(data)},
        &Service.Novelty.split_data/1,
        &Service.Novelty.batch/2
      )
      |> IO.inspect()

    forest
    |> Forest.evaluate([105, 20], &Service.Outlier.decision/2)
    |> Enum.map(fn %{data: _, depth: d} -> d end)
    |> IO.inspect()

    forest
    |> Forest.evaluate([25, 20], &Service.Outlier.decision/2)
    |> Enum.map(fn %{data: _, depth: d} -> d end)
    |> IO.inspect()
  end
end
