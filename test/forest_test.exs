defmodule ForestTest do
  use ExUnit.Case
  doctest Forest

  test "greets the world" do
    assert Forest.hello() == :world
  end
end
