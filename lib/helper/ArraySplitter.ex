defmodule Helper.ArraySplitter do
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

    # Adjust the last size to ensure all elements are included (due to rounding issues)
    sizes = adjust_last_size(sizes, total)

    # Step 3: Split the array
    split_arrays(shuffled, sizes)
  end

  defp adjust_last_size(sizes, total) do
    sizes_but_last = Enum.slice(sizes, 0..-2)
    calculated_total = Enum.sum(sizes_but_last)
    last_size = total - calculated_total
    sizes_but_last ++ [last_size]
  end

  defp split_arrays(array, [size | rest_sizes]) do
    {part, rest} = Enum.split(array, size)
    [part | split_arrays(rest, rest_sizes)]
  end

  defp split_arrays(array, []), do: [array]
end
