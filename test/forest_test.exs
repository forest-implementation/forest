defmodule ForestTest do
  use ExUnit.Case


  test "new node" do
    # with single element
    assert INode.new(5, & &1) == %INode{data: 5, range: 5, left: nil, right: nil}

    # with multiple elements
    assert INode.new([4, 5], &Service.Common.minmax/1) == %INode{
             data: [4, 5],
             range: {4,5},
             left: nil,
             right: nil
           }
  end

  test "inorder" do
    node = %INode{data: 5, left: INode.new(4, & &1), right: INode.new(6, & &1)}
    assert INode.inorder(node) == [4, 5, 6]
  end

  test "sort init" do
    tree = INode.new([7, 5, 3, 4, 6, 2, 1], &Service.Common.minmax/1)

    assert INode.init(tree, &Service.Outlier.split_range/1, &Service.Common.in_range/2, &Service.Common.endcond/1) |> INode.leaves() == [
             [1],
             [2],
             [3],
             [4],
             [5],
             [6],
             [7]
           ]
  end

  test "find element outlier" do
    :rand.seed(:exsplus, {12245, 67890, 54321})
    tree = INode.new([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], &Service.Common.minmax/1)
    tree = INode.init(tree, &Service.Outlier.split_range/1, &Service.Common.in_range/2, &Service.Common.endcond/1)

    assert INode.find(tree, 9, &Service.Common.findfun/2) == %INode{
             data: [9],
             range: {9, 9.86400432751823},
             left: nil,
             right: nil,
             depth: 3
           }
  end

  test "find element novelty" do
    tree = INode.new([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], fn _ -> {-100,100} end)
    tree = INode.init(tree, &Service.Novelty.split_range/1, &Service.Common.in_range/2, &Service.Common.endcond/1)

    assert INode.find(tree, 99, &Service.Common.findfun/2).depth == 2
    assert INode.find(tree, 5, &Service.Common.findfun/2).depth == 8
  end

  test "find element Outlier" do
    :rand.seed(:exsplus, {12245, 67890, 54321})
    tree = INode.new([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], &Service.Common.minmax/1)
    tree = INode.init(tree, &Service.Outlier.split_range/1, &Service.Common.in_range/2, &Service.Common.endcond/1)

    assert INode.find(tree, 99, &Service.Common.findfun/2).depth == 3
    assert INode.find(tree, 5, &Service.Common.findfun/2).depth == 4
  end
end
