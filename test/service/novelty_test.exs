defmodule ServiceNoveltyTest do
  use ExUnit.Case

  test "from_data_Novelty" do
    :rand.seed(:exsplus, {12245, 67890, 54321})

    assert INode.from_data(%{:data => [[1]], :ranges => [{1,3}]}, &Service.Novelty.split_data/1) == %INode{
             carrier: %{data: [1], depth: 0, ranges: [{1,3}]},
             left: nil,
             right: nil
           }

    assert INode.from_data(%{:data => [[1], [2], [3]], :ranges=>[{1,3}]}, &Service.Novelty.split_data/1) ==
             %INode{
               carrier: {0, 2},
               left: %INode{carrier: %{data: [1], depth: 1, ranges: [{1,2}]}, left: nil, right: nil},
               right: %INode{
                 carrier: {0, 2.5},
                 left: %INode{carrier: %{data: [2], depth: 2, ranges: [{2,2.5}]}, left: nil, right: nil},
                 right: %INode{carrier: %{data: [3], depth: 2, ranges: [{2.5,3}]}, left: nil, right: nil}
               }
             }
  end
end
