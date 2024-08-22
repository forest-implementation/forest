defmodule ServiceCommonTest do
  use ExUnit.Case

  test "minmax" do
    assert [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] |> Service.Common.minmax() == 1..10
  end

  test "range functions" do
    # ranges are inclusive:
    assert 1..5 |> Enum.to_list() == [1, 2, 3, 4, 5]

    assert Service.Common.split_range(
             INode.new([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], &Service.Common.minmax/1)
           ) == {1..5, 6..10}

    assert Service.Common.in_range([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 1..5) == [1, 2, 3, 4, 5]
  end

  test "findfun" do
    node = %INode{
      data: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      range: 1..10,
      left: INode.new([1, 2, 3, 4, 5], &Service.Common.minmax/1),
      right: INode.new([6, 7, 8, 9, 10], &Service.Common.minmax/1),
      depth: 0
    }

    assert Service.Common.findfun(node, 7) == 1
    assert Service.Common.findfun(node, 2) == 0
  end
end
