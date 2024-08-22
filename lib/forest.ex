defmodule INode do
  defstruct data: nil, range: nil, left: nil, right: nil, depth: 0

  def new(data, rangefun) do
    %INode{data: data, range: rangefun.(data)}
  end

  def insert(nil, value, _comparefun, rangefun), do: new(value, rangefun)

  def insert(
        %INode{data: _, range: _, left: left, right: right} = node,
        value,
        comparefun,
        rangefun
      ) do
    case comparefun.(node, value) do
      %{false: leftdata} -> %INode{node | left: insert(left, leftdata, comparefun, rangefun)}
      %{true: rightdata} -> %INode{node | right: insert(right, rightdata, comparefun, rangefun)}
      # for now, we do not insert duplicates
      0 -> node
    end
  end

  def init(node, split_range_fun, filterrangefun, endcond) do
    {leftrange, rightrange} = split_range_fun.(node)

    {leftdata, rightdata} =
      {filterrangefun.(node.data, leftrange), filterrangefun.(node.data, rightrange)}

    if endcond.(node) == true do
      %INode{data: node.data, range: node.range, depth: node.depth}
    else
      %INode{
        node
        | left:
            init(
              %INode{data: leftdata, range: leftrange, depth: node.depth + 1},
              split_range_fun,
              filterrangefun,
              endcond
            ),
          right:
            init(
              %INode{data: rightdata, range: rightrange, depth: node.depth + 1},
              split_range_fun,
              filterrangefun,
              endcond
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

  def find(%INode{range: range, left: left, right: right} = node, element, find_fun) do
    if Enum.min(range) == Enum.max(range) do
      node
    else
      case find_fun.(node, element) do
        0 -> find(left, element, find_fun)
        1 -> find(right, element, find_fun)
      end
    end
  end
end

defmodule Forest do
end
