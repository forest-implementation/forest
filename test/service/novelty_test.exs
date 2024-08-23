defmodule ServiceNoveltyTest do
  use ExUnit.Case

  test "range functions" do
    assert Service.Novelty.split_range(
             INode.new([[1,5], [2,6], [3,100]], fn _ -> [{0,2}, {5,100}] end),
             1
           ) == {[{0,2},{5,52.5}],[{0,2},{52.5,100}]}

    assert Service.Common.in_range([[1], [2], [3], [4], [5], [6], [7], [8], [9], [10]], [{1,5}],0) == [[1], [2], [3], [4], [5]]
  end
end
