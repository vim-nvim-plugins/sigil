limit <- 3
scale <- function(value, factor) {
  total <- value * factor
  for (i in seq_len(limit)) {
    total <- total + i
  }
  total
}
twice <- function(value) {
  total <- value * 2  # total in a comment
  total
}
print(paste("total limit", scale(limit, 2)))
