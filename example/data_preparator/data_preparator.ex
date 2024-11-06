Code.require_file("../csv_loader/csv_loader.ex", __DIR__)

defmodule DataPreparator do
  def adbench(filepath, droprows \\ -2, groupcolumn \\ -1) do
    CSVLoader.load_csv(filepath)
    |> Enum.group_by(
      fn row -> Enum.at(row, groupcolumn) end,
      fn val ->
        Enum.drop(val, droprows) |> Enum.map(&String.to_float/1)
      end
    )
  end
end
