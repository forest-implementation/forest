defmodule StatisticsTest do
  use ExUnit.Case

  test "medcouple" do
    arr = [1.0, 2.0, 3.0, 3.0, 4.0]
    assert Helper.Statistics.run_medcouple(arr) == -0.1666666667
  end

  test "quantile" do
    assert Helper.Statistics.quantile([1, 2, 3, 4, 5, 6, 7, 8], [25, 75]) == %{
             25 => 2.25,
             75 => 6.75
           }
  end

  test "adjusted box" do
    assert Helper.Statistics.adjusted_box([[1], [2], [3], [4], [5], [6], [7]], 0) ==
             {2.5 - 4.5, 5.5 + 4.5}
  end
end
