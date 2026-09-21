library(googlesheets4)
library(dplyr)
library(stringr)

gs4_auth()

SHEET_URL <- "https://docs.google.com/spreadsheets/d/1zsfhYz32GoeKz8qzaHgDKsc-InRxitIsdnc9JWG-4OU/edit?usp=sharing"
data_raw <- read_sheet(SHEET_URL, col_types = "c")

# Print ALL column names with their index so we can see exact names
cat("\n=== ALL COLUMN NAMES ===\n")
for (i in seq_along(names(data_raw))) {
    cat(sprintf("[%2d] '%s'\n", i, names(data_raw)[i]))
}

# Show poster rows: Presentation, Presentation title, Presentation title poster
cat("\n=== POSTER ROWS (Presentation, title, poster_title) ===\n")
poster_rows <- data_raw %>%
    filter(str_detect(Presentation, regex("poster", ignore_case = TRUE)))

cat("Number of poster rows:", nrow(poster_rows), "\n\n")

pres_title_cols <- names(data_raw)[str_detect(names(data_raw), regex("title|presentation", ignore_case = TRUE))]
cat("Columns matching 'title' or 'presentation':\n")
for (c in pres_title_cols) cat(" •", sprintf("'%s'\n", c))

cat("\n=== Poster titles (first 10 rows) ===\n")
poster_rows %>%
    select(
        Names, Presentation,
        any_of(c(
            "Presentation_title", "Presentation title",
            "Presentation title poster", "Presentation_title_poster"
        ))
    ) %>%
    head(10) %>%
    print(width = 200)
