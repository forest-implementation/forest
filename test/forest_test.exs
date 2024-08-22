defmodule ForestTest do
  use ExUnit.Case


  test "new node" do
    # with single element
    assert INode.new(5, & &1) == %INode{data: 5, range: 5, left: nil, right: nil}

    # with multiple elements
    assert INode.new([4, 5], &Service.Common.minmax/1) == %INode{
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

  test "sort init" do
    tree = INode.new([7, 5, 3, 4, 6, 2, 1], &Service.Common.minmax/1)

    assert INode.init(tree, &Service.Common.split_range/1, &Service.Common.in_range/2, &Service.Common.endcond/1) |> INode.leaves() == [
             [1],
             [2],
             [3],
             [4],
             [5],
             [6],
             [7]
           ]
  end

  test "init multi range" do
    tree = INode.new([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], &Service.Common.minmax/1)

    assert INode.init(tree, &Service.Common.split_range/1, &Service.Common.in_range/2, &Service.Common.endcond/1) == %INode{
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

  test "find element outlier" do
    tree = INode.new([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], &Service.Common.minmax/1)
    tree = INode.init(tree, &Service.Common.split_range/1, &Service.Common.in_range/2, &Service.Common.endcond/1)

    assert INode.find(tree, 9, &Service.Common.findfun/2) == %INode{
             data: [9],
             range: 9..9,
             left: nil,
             right: nil,
             depth: 4
           }
  end

  test "find element novelty" do
    tree = INode.new([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], fn _ -> -100..100 end)
    tree = INode.init(tree, &Service.Common.split_range/1, &Service.Common.in_range/2, &Service.Common.endcond/1)

    assert INode.find(tree, 99, &Service.Common.findfun/2).depth == 2
    assert INode.find(tree, 5, &Service.Common.findfun/2).depth == 8
  end
end
