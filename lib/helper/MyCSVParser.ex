NimbleCSV.define(MyParser, separator: ",", escape: "\"")

defmodule Helper.MyCSVParser do
  def load_csv(file_path) do
    file_path
    |> File.stream!(read_ahead: 100_000)
    |> MyParser.parse_stream
    |> Enum.map(& &1)
  end
end
