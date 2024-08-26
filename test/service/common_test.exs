defmodule ServiceCommonTest do
  use ExUnit.Case

  test "take dimension" do
    assert Service.Common.take_dimension([[1,2],[3,4],[4,5]],1) == [2,4,5]

  end
end
