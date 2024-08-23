defmodule ForestTest do
  use ExUnit.Case

  test "new node" do
    # with single element
    assert INode.new(5, & &1) == %INode{data: 5, range: 5, left: nil, right: nil}

    # with multiple elements
    assert INode.new([[4], [5]], &Service.Common.minmax(&1, 0)) == %INode{
             data: [[4], [5]],
             range: {4, 5},
             left: nil,
             right: nil
           }
  end

  test "inorder" do
    node = %INode{data: 5, left: INode.new(4, & &1), right: INode.new(6, & &1)}
    assert INode.inorder(node) == [4, 5, 6]
  end

  test "sort init" do
    :rand.seed(:exsplus, {1224, 67892, 54321})
    tree = INode.new([[7], [5], [3], [4], [6], [2], [1]], fn _ -> [{1,7}] end)

    assert INode.init(
             tree,
             &Service.Outlier.split_range/2,
             &Service.Common.in_range/3,
             &Service.Common.endcond/1,
             &Service.Common.dimfun/1
           )
           |> INode.leaves() == [
             [[1]],
             [[2]],
             [[3]],
             [[4]],
             [[5]],
             [[6]],
             [[7]]
           ]
  end

  test "find element outlier" do
    :rand.seed(:exsplus, {12245, 67890, 54321})

    tree =
      INode.new(
        [[1], [2], [3], [4], [5], [6], [7], [8], [9], [10]],
        fn _ -> [{1,10}] end
      )

    tree =
      INode.init(
        tree,
        &Service.Outlier.split_range/2,
        &Service.Common.in_range/3,
        &Service.Common.endcond/1,
        &Service.Common.dimfun/1
      )

    assert INode.find(tree, [9], &Service.Common.findfun/3) == %INode{
             data: [[9]],
             range: [{8.93735942335424, 9.78667109630238}],
             left: nil,
             right: nil,
             depth: 4
           }
  end

  test "find element novelty" do
    tree = INode.new([[1], [2], [3], [4], [5], [6], [7], [8], [9], [10]], fn _ -> [{-100, 100}] end)

    tree =
      INode.init(
        tree,
        &Service.Novelty.split_range/2,
        &Service.Common.in_range/3,
        &Service.Common.endcond/1,
        &Service.Common.dimfun/1
      )

    assert INode.find(tree, [99], &Service.Common.findfun/3).depth == 2
    assert INode.find(tree, [5], &Service.Common.findfun/3).depth == 8
  end

  test "find element Outlier" do
    :rand.seed(:exsplus, {12245, 67890, 54321})

    tree =
      INode.new(
        [[1], [2], [3], [4], [5], [6], [7], [8], [9], [10]],
        fn _ -> [{1,10}] end
      )

    tree =
      INode.init(
        tree,
        &Service.Outlier.split_range/2,
        &Service.Common.in_range/3,
        &Service.Common.endcond/1,
        &Service.Common.dimfun/1
      ) # |> IO.inspect(charlists: :as_lists)

    assert INode.find(tree, [99], &Service.Common.findfun/3).depth == 4
    assert INode.find(tree, [5], &Service.Common.findfun/3).depth == 3
  end

  test "find element outlier multidim" do
    :rand.seed(:exsplus, {12245, 67890, 54321})

    tree =
      INode.new(
        [[1, 5], [2, 4], [3, 1], [4, 4], [5, 7], [6, 100], [7, 7], [8, 50], [9, 40], [10, 25]],
        fn _ -> [{1,10}, {1,100}] end
      )

    tree =
      INode.init(
        tree,
        &Service.Outlier.split_range/2,
        &Service.Common.in_range/3,
        &Service.Common.endcond/1,
        &Service.Common.dimfun/1
      )

    assert INode.find(tree, [99], &Service.Common.findfun/3).depth == 3
    assert INode.find(tree, [5], &Service.Common.findfun/3).depth == 3
  end
end
