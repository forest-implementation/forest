defmodule ForestTest do
  use ExUnit.Case

  def minmax(x), do: Enum.min_max(x) |> then(fn {a, b} -> a..b end)

  test "new node" do
    # with single element
    assert INode.new(5, & &1) == %INode{data: 5, range: 5, left: nil, right: nil}

    # with multiple elements
    assert INode.new([4, 5], &minmax/1) == %INode{
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

  def sort_compare(a, val) when a.data < val, do: %{false: val}
  def sort_compare(_, val), do: %{true: val}

  test "insert single minmax sort" do
    # with single element
    tree = INode.new(10, & &1)
    tree = INode.insert(tree, 5, &sort_compare/2, & &1)
    tree = INode.insert(tree, 2, &sort_compare/2, & &1)
    tree = INode.insert(tree, 1, &sort_compare/2, & &1)
    tree = INode.insert(tree, 3, &sort_compare/2, & &1)

    assert INode.inorder(tree) == [10, 5, 3, 2, 1]
  end

  def split_range(node) do
    min = Enum.min(node.range)
    max = Enum.max(node.range)
    midpoint = min + div(Enum.count(node.range), 2)
    {min..(midpoint - 1), midpoint..max}
  end

  def in_range(elements, range) do
    Enum.filter(elements, fn element ->
      element >= Enum.min(range) and element <= Enum.max(range)
    end)
  end

  test "range functions" do
    # ranges are inclusive:
    assert 1..5 |> Enum.to_list() == [1, 2, 3, 4, 5]
    assert split_range(INode.new([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], &minmax/1)) == {1..5, 6..10}
    assert in_range([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 1..5) == [1, 2, 3, 4, 5]
  end

  def endcond(node), do: Enum.count(node.range) <= 1 or Enum.empty?(node.data)

  test "sort init" do
    tree = INode.new([1, 2, 3, 4, 5, 6, 7] |> Enum.shuffle(), &minmax/1)

    assert INode.init(tree, &split_range/1, &in_range/2, &endcond/1) |> INode.leaves() == [
             [1],
             [2],
             [3],
             [4],
             [5],
             [6],
             [7]
           ]
  end

  test "insert multi range" do
    tree = INode.new([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], &minmax/1)

    assert INode.init(tree, &split_range/1, &in_range/2, &endcond/1) == %INode{
             data: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
             range: 1..10,
             left: %INode{
               data: [1, 2, 3, 4, 5],
               range: 1..5,
               left: %INode{
                 data: [1, 2],
                 range: 1..2,
                 left: %INode{data: [1], range: 1..1, left: nil, right: nil, depth: 3},
                 right: %INode{data: [2], range: 2..2, left: nil, right: nil, depth: 3},
                 depth: 2
               },
               right: %INode{
                 data: [3, 4, 5],
                 range: 3..5,
                 left: %INode{data: [3], range: 3..3, left: nil, right: nil, depth: 3},
                 right: %INode{
                   data: [4, 5],
                   range: 4..5,
                   left: %INode{data: [4], range: 4..4, left: nil, right: nil, depth: 4},
                   right: %INode{data: [5], range: 5..5, left: nil, right: nil, depth: 4},
                   depth: 3
                 },
                 depth: 2
               },
               depth: 1
             },
             right: %INode{
               data: [6, 7, 8, 9, 10],
               range: 6..10,
               left: %INode{
                 data: [6, 7],
                 range: 6..7,
                 left: %INode{data: [6], range: 6..6, left: nil, right: nil, depth: 3},
                 right: %INode{data: [7], range: 7..7, left: nil, right: nil, depth: 3},
                 depth: 2
               },
               right: %INode{
                 data: [8, 9, 10],
                 range: 8..10,
                 left: %INode{data: [8], range: 8..8, left: nil, right: nil, depth: 3},
                 right: %INode{
                   data: [9, 10],
                   range: 9..10,
                   left: %INode{data: [9], range: 9..9, left: nil, right: nil, depth: 4},
                   right: %INode{
                     data: [10],
                     range: 10..10,
                     left: nil,
                     right: nil,
                     depth: 4
                   },
                   depth: 3
                 },
                 depth: 2
               },
               depth: 1
             },
             depth: 0
           }
  end

  def findfun(node, element) do
    if in_range([element], node.left.range) |> length == 0 do
      1
    else
      0
    end
  end

  test "find element" do
    node = %INode{
      data: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      range: 1..10,
      left: INode.new([1, 2, 3, 4, 5], &minmax/1),
      right: INode.new([6, 7, 8, 9, 10], &minmax/1),
      depth: 0
    }

    assert findfun(node, 7) == 1
    assert findfun(node, 2) == 0

    tree = INode.new([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], &minmax/1)
    tree = INode.init(tree, &split_range/1, &in_range/2, &endcond/1)

    assert INode.find(tree, 9, &findfun/2) == %INode{
             data: [9],
             range: 9..9,
             left: nil,
             right: nil,
             depth: 4
           }
  end
end
