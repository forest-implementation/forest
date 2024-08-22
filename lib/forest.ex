defmodule INode do
  defstruct data: nil, range: nil, left: nil, right: nil, depth: 0

  def new(data, rangefun) do
    %INode{data: data, range: rangefun.(data)}
  end

  def insert(nil, value, _comparefun, rangefun), do: new(value, rangefun)

  def insert(
        %INode{data: _, range: range, left: left, right: right} = node,
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
    {leftrange, rightrange} = split_range_fun.(node.range)

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
end

defmodule Forest do
end
