defmodule INode do
  defstruct data: nil, range: nil, dim: 0, sp: 0, depth: 0, left: nil, right: nil

  def new(data, rangefun) do
    %INode{data: data, range: rangefun.(data)}
  end

  def init(node, split_range_fun, filterrangefun, endcond, dim_fun) do
    {leftrange, rightrange} = split_range_fun.(node, node.dim)

    {leftdata, rightdata} =
      {filterrangefun.(node.data, leftrange, node.dim),
       filterrangefun.(node.data, rightrange, node.dim)}

    if endcond.(node) == true do
      %INode{data: node.data, range: node.range, depth: node.depth, dim: node.dim, sp: node.sp}
    else
      %INode{
        node
        | left:
            init(
              %INode{
                data: leftdata,
                range: leftrange,
                depth: node.depth + 1,
                dim: dim_fun.(node)
              },
              split_range_fun,
              filterrangefun,
              endcond,
              dim_fun
            ),
          right:
            init(
              %INode{
                data: rightdata,
                range: rightrange,
                depth: node.depth + 1,
                dim: dim_fun.(node)
              },
              split_range_fun,
              filterrangefun,
              endcond,
              dim_fun
            )
      }
    end
  end

  def inorder(nil), do: []

  def inorder(%INode{data: value, left: left, right: right}) do
    inorder(left) ++ [value] ++ inorder(right)
  end

  def leaves(nil), do: []

  def leaves(%INode{data: value, left: left, right: right}) do
    case left == nil and right == nil do
      true -> [value]
      false -> leaves(left) ++ leaves(right)
    end
  end

  def find(%INode{range: _, left: left, right: right} = node, element, find_fun) do
    if left == nil and right == nil do
      node
    else
      case find_fun.(node, element, node.dim) do
        0 -> find(left, element, find_fun)
        1 -> find(right, element, find_fun)
      end
    end
  end
end

defmodule Forest do
  def init(n, data, initrangefun, splitfun, decisionfun, endcond, dimfun) do
    Enum.map(1..n, fn _ ->
      tree =
        INode.new(
          data,
          initrangefun
        )

      INode.init(
        tree,
        splitfun,
        decisionfun,
        endcond,
        dimfun
      )
    end)
  end

  def evaluate(forest, item, findfun) do
    forest |> Enum.map(fn tree -> INode.find(tree, item, findfun) end)
  end
end
