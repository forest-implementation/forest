defmodule ServiceNoveltyTest do
  use ExUnit.Case

  test "range functions" do
    # ranges are inclusive:
    assert 1..5 |> Enum.to_list() == [1, 2, 3, 4, 5]

    assert Service.Novelty.split_range(
             INode.new([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], &Service.Common.minmax/1)
           ) == {{1,5.5}, {5.5,10}}

    assert Service.Common.in_range([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], {1,5}) == [1, 2, 3, 4, 5]
  end
end
