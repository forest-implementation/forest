defmodule Helper.Statistics do
  def run_medcouple(arr) do
    {result, _exit_code} =
      System.cmd("Rscript", ["lib/helper/medcouple.R"] ++ (arr |> Enum.map(fn x -> "#{x}" end)))

    String.trim(result) |> String.to_float()
  end

  def quantile(list, q) do
    Statistex.percentiles(list, q)
  end

  def adjusted_box(input, index) do
    s = Enum.map(input, fn x -> Enum.at(x, index) end)
    sorted = Enum.sort(s)


    %{25 => fqr, 75 => tqr} = quantile(sorted, [25, 75])
    iqr = tqr - fqr
    med = run_medcouple(sorted)

    tolerance = fn par -> 1.5 * iqr * :math.exp(par * med) end

    lower_bound = fqr - tolerance.(if med >= 0, do: -4, else: -3)
    upper_bound = tqr + tolerance.(if med >= 0, do: 3, else: 4)

    {lower_bound, upper_bound}
  end
end
