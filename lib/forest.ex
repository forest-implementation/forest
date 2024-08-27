defmodule INode do
  defstruct carrier: nil, left: nil, right: nil

  def from_data(data, split_data_fun) do
    case split_data_fun.(data) do
      {carrier, left_data, right_data} ->
        %INode{
          carrier: carrier,
          left: from_data(left_data, split_data_fun),
          right: from_data(right_data, split_data_fun)
        }

      {carrier} ->
        %INode{carrier: carrier, left: nil, right: nil}
    end
  end

  def inorder(nil), do: []

  def inorder(%INode{carrier: value, left: left, right: right}) do
    inorder(left) ++ [value] ++ inorder(right)
  end

  def leaves(nil), do: []
  def leaves(%INode{carrier: value, left: nil, right: nil}), do: [value]
  def leaves(%INode{carrier: _value, left: left, right: right}), do: leaves(left) ++ leaves(right)

  def find(_, %INode{carrier: carry, left: nil, right: nil}, _), do: carry

  def find(element, %INode{carrier: carry, left: left, right: right}, decisionfun) do
    case decisionfun.(element, carry) do
      true -> find(element, left, decisionfun)
      false -> find(element, right, decisionfun)
    end
  end
end

defmodule Forest do
  def init(n, data, splitfun), do: init(n, data, splitfun, fn x, _ -> x end)

  def init(n, data, splitfun, batchfun) do
    Enum.map(1..n, fn i ->
      INode.from_data(
        batchfun.(data, i),
        splitfun
      )
    end)
  end

  def evaluate(forest, item, decisionfun) do
    forest |> Enum.map(fn tree -> INode.find(item, tree, decisionfun) end)
  end
end
