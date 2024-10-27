defmodule ArraySplitter do
  def split(array, percentages) do
    # Ensure the percentages sum to 100
    if Enum.sum(percentages) != 100 do
      raise ArgumentError, "Percentages must sum to 100"
    end

    # Step 1: Shuffle the array
    shuffled = Enum.shuffle(array)

    # Step 2: Calculate the sizes for each part based on percentages
    total = length(shuffled)
    sizes = Enum.map(percentages, fn percentage -> div(total * percentage, 100) end)

    # Step 3: Split the array
    split_arrays(shuffled, sizes)
  end

  defp split_arrays(array, [size | rest_sizes]) do
    {part, rest} = Enum.split(array, size)
    [part | split_arrays(rest, rest_sizes)]
  end

  defp split_arrays(array, []), do: [array]
end
