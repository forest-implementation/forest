defmodule ServiceOutlierTest do
  use ExUnit.Case

  test "range functions" do
    :rand.seed(:exsplus, {12245, 67890, 54321})

    assert Service.Outlier.split_range(
             INode.new(
               [[1], [2], [3], [4], [5], [6], [7], [8], [9], [10]],
               fn _ -> [{1,10}] end
             ),
             0
           ) == {[{1, 3.475804989213391}], [{3.475804989213391, 10}]}
  end
end
