defmodule ServiceCommonTest do
  use ExUnit.Case

  test "minmax" do
    assert [[1], [2], [3], [4], [5], [6], [7], [8], [9], [10]] |> Service.Common.minmax(0) == {1,10}
  end

  test "findfun" do
    node = %INode{
      data: [[1], [2], [3], [4], [5], [6], [7], [8], [9], [10]],
      range: [{1,10}],
      left: INode.new([[1], [2], [3], [4], [5]], fn _ -> [{1,5}] end),
      right: INode.new([[6], [7], [8], [9], [10]], fn _ -> [{6,10}] end),
      depth: 0
    }

    assert Service.Common.findfun(node, [7],0) == 1
    assert Service.Common.findfun(node, [2],0) == 0
  end

  test "dimfun" do
    :rand.seed(:exsplus, {1224, 61890, 54321})
    assert Service.Common.dimfun(INode.new([[1], [2], [3], [4], [5]], &Service.Common.minmax(&1,0))) == 0
    assert Service.Common.dimfun(INode.new([[1,1], [2,2], [3,2], [4,2], [5,2]], &Service.Common.minmax(&1,0))) == 1
  end

  test "take dimension" do
    assert Service.Common.take_dimension([[1,2],[3,4],[4,5]],1) == [2,4,5]

  end
end
