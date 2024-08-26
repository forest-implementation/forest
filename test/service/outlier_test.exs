defmodule ServiceOutlierTest do
  use ExUnit.Case

  test "split_data_one_element" do
    assert %{:data => [[5]]} |> Service.Outlier.split_data() == {%{data: [5], depth: 0}}
    :rand.seed(:exsplus, {12245, 67890, 54321})

    assert %{:data => [[5], [6], [7]]} |> Service.Outlier.split_data() ==
             {{0, 5.7850339582840675}, %{data: [[5]], depth: 1}, %{data: [[6], [7]], depth: 1}}

    assert %{:data => [[5], [6], [7]], :depth => 7} |> Service.Outlier.split_data() ==
             {{0, 6.217725558581396}, %{data: [[5], [6]], depth: 8}, %{data: [[7]], depth: 8}}
  end

  test "from_data_outlier" do
    :rand.seed(:exsplus, {12245, 67890, 54321})

    assert INode.from_data(%{:data => [[1]]}, &Service.Outlier.split_data/1) == %INode{
             carrier: %{data: [1], depth: 0},
             left: nil,
             right: nil
           }

    assert INode.from_data(%{:data => [[1], [2], [3]]}, &Service.Outlier.split_data/1) ==
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
    tree = INode.from_data(%{:data => [[1], [2], [3]]}, &Service.Outlier.split_data/1)
    assert INode.find([1], tree, &Service.Outlier.decision/2).data == [1]
  end

  test "sort init" do
    :rand.seed(:exsplus, {1224, 67892, 54321})

    assert INode.from_data(%{:data => [[7], [2], [4], [1]]}, &Service.Outlier.split_data/1)
           |> INode.leaves()
           |> Enum.map(fn %{data: x, depth: _} -> x end) == [
             [1],
             [2],
             [4],
             [7]
           ]
  end

  test "outlier forest" do
    :rand.seed(:exsplus, {1224, 67892, 54321})
    Forest.init(5, [[7], [2], [4], [1], [8], [9]], &Service.Outlier.split_data/1)
    |> Forest.evaluate([7], &Service.Outlier.decision/2) |> IO.inspect(charlists: :as_lists)
    Forest.init(25, [[7,5], [2,4], [4,3], [1,1], [8,11], [9,6]], &Service.Outlier.split_data/1)
    |> Forest.evaluate([7,2], &Service.Outlier.decision/2) |> IO.inspect(charlists: :as_lists)
  end
end
