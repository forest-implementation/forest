defmodule ForestTest do
  use ExUnit.Case

  test "new node" do
    # with single element
    assert INode.new(5, & &1) == %INode{data: 5, range: 5, left: nil, right: nil}

    # with multiple elements
    assert INode.new([4, 5], &(Enum.min_max(&1) |> then(fn {a, b} -> a..b end))) == %INode{
             data: [4, 5],
             range: 4..5,
             left: nil,
             right: nil
           }
  end

  test "inorder" do
    node = %INode{data: 5, left: INode.new(4, & &1), right: INode.new(6, & &1)}
    assert INode.inorder(node) == [4, 5, 6]
  end

  def max_min(a, val) when a.data < val, do: %{false: val}
  def max_min(_, val), do: %{true: val}

  test "insert single minmax" do
    # with single element
    tree = INode.new(10, & &1)
    tree = INode.insert(tree, 5, &max_min/2, & &1)
    tree = INode.insert(tree, 2, &max_min/2, & &1)
    tree = INode.insert(tree, 1, &max_min/2, & &1)
    tree = INode.insert(tree, 3, &max_min/2, & &1)

    assert INode.inorder(tree) == [10, 5, 3, 2, 1]
  end

  def split_range(range) do
    min = Enum.min(range)
    max = Enum.max(range)
    midpoint = min + div(Enum.count(range), 2)
    {min..midpoint-1, midpoint..max}
  end

  def in_range(elements, range) do
    Enum.filter(elements, fn element ->
      element >= Enum.min(range) and element <= Enum.max(range)
    end)
  end

  test "range functions" do
    # ranges are inclusive:
    assert 1..5 |> Enum.to_list == [1,2,3,4,5]
    assert split_range(1..10) == {1..5,6..10}
    assert in_range([1,2,3,4,5,6,7,8,9,10], 1..5) == [1,2,3,4,5]
  end

  test "insert multi range" do
    minmax = &(Enum.min_max(&1) |> then(fn {a, b} -> a..b end))

    endcond = fn node ->
      Enum.count(node.range) <= 1 or Enum.empty?(node.data)
    end
    # zacnes nodem ve kterem je fura dat, node si vytvori svoji range (nyni davame minmax)
    tree = INode.new([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], minmax)
    INode.init(tree, &split_range/1, &in_range/2, endcond) |> IO.inspect(charlists: :as_lists)

    # INode.inorder(tree) |> IO.inspect
  end
end
