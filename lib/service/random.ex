defmodule Service.RandomSeed do
  def generate(min, max) do
    random_value = :rand.uniform()
    scaled_value = min + random_value * (max - min)
    scaled_value
  end
end
