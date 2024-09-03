# Load the required library
library(robustbase)

# Capture the command line arguments as a numeric vector
args <- commandArgs(trailingOnly = TRUE)
arr <- as.list(args)
# Compute the medcouple using the mc function from robustbase
result <- mc(c(arr))
# Print the result to be captured by Elixir
cat(sprintf("%.10f", result))