library(googlesheets4)
library(tidyverse)

gs4_deauth()
sheet_url <- "https://docs.google.com/spreadsheets/d/1zsfhYz32GoeKz8qzaHgDKsc-InRxitIsdnc9JWG-4OU/edit?usp=sharing"
data_raw <- read_sheet(sheet_url, col_types = "c", n_max = 1)
print(names(data_raw))
