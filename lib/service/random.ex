defmodule Service.RandomSeed do
  def generate_float(min, max) do
    random_value = :rand.uniform()
    scaled_value = min + random_value * (max - min)
    scaled_value
  end

  def generate_int(min, max) do
    random_value = :rand.uniform()
    scaled_value = min + round(random_value * (max - min))
    scaled_value
  end
end
