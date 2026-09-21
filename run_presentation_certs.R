# Generates ONLY presentation (oral + poster) certificates.
# Run from the project root directory.
# Fixes: poster titles from "Presentation title poster", authors from "Authors  poster"

required_packages <- c("googlesheets4", "dplyr", "stringr", "pagedown", "htmltools", "base64enc")
missing <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]
if (length(missing) > 0) install.packages(missing)

# IMPORTANT: set before library(googlesheets4) so gargle picks it up non-interactively
options(gargle_oauth_email = "jakubstenc@gmail.com")

library(googlesheets4)
library(dplyr)
library(stringr)
library(htmltools)

# ── CONFIG ────────────────────────────────────────────────────────────────────
SHEET_URL <- "https://docs.google.com/spreadsheets/d/1zsfhYz32GoeKz8qzaHgDKsc-InRxitIsdnc9JWG-4OU/edit?usp=sharing"
OUTPUT_DIR <- "documents/certificates/generated"
LOGO_ECOFLOR <- normalizePath("images/IMG_1108.jpg", mustWork = FALSE)
LOGO_AEET <- normalizePath("images/logos/AEET.png", mustWork = FALSE)
SIGNATURE <- normalizePath("documents/certificates/singature.png", mustWork = FALSE)

img_to_base64 <- function(path) {
  if (!file.exists(path)) {
    return("")
  }
  ext <- tolower(tools::file_ext(path))
  mime <- switch(ext,
    png = "image/png",
    jpg = ,
    jpeg = "image/jpeg",
    "image/png"
  )
  raw <- readBin(path, "raw", file.info(path)$size)
  paste0("data:", mime, ";base64,", base64enc::base64encode(raw))
}

safe_name <- function(x) {
  x <- iconv(x, to = "ASCII//TRANSLIT")
  x <- str_replace_all(x, "[^A-Za-z0-9_-]", "_")
  x <- str_replace_all(x, "_+", "_")
  str_trim(x, "both")
}

# ── AUTH & DATA ───────────────────────────────────────────────────────────────
message("\nAuthenticating with Google Sheets...")
gs4_deauth() # sheet is publicly readable — no OAuth needed

message("Reading data from Google Sheet...")
data_raw <- read_sheet(SHEET_URL, col_types = "c")
message("  → ", nrow(data_raw), " rows, ", ncol(data_raw), " columns.")

# ── ENCODE IMAGES ─────────────────────────────────────────────────────────────
logo_ecoflor_b64 <- img_to_base64(LOGO_ECOFLOR)
logo_aeet_b64 <- img_to_base64(LOGO_AEET)
signature_b64 <- img_to_base64(SIGNATURE)

# ── HTML TEMPLATE ─────────────────────────────────────────────────────────────
build_certificate_html <- function(body_html, logo_ecoflor_b64, logo_aeet_b64, signature_b64) {
  sig_html <- if (nchar(signature_b64) > 0) {
    paste0('<img src="', signature_b64, '" alt="Signature" style="height:28px; margin-bottom:0;">')
  } else {
    ""
  }

  paste0('<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<style>
  @import url("https://fonts.googleapis.com/css2?family=EB+Garamond:ital,wght@0,400;0,600;1,400&family=Montserrat:wght@300;600;700&display=swap");

  * { box-sizing: border-box; margin: 0; padding: 0; }
  @page { size: A4 landscape; margin: 0; }

  body {
    width: 297mm; height: 210mm;
    font-family: "EB Garamond", Georgia, serif;
    background: #fff; color: #2c2c2c;
    display: flex; flex-direction: column;
    align-items: center; justify-content: space-between;
    padding: 0; overflow: hidden;
  }

  .border-outer { position: absolute; inset: 8mm;  border: 2.5px solid #C8882A; pointer-events: none; }
  .border-inner  { position: absolute; inset: 11mm; border: 0.8px  solid #C8882A; pointer-events: none; }

  /* HEADER */
  .header {
    width: 100%; flex-shrink: 0;
    display: flex; align-items: center; justify-content: space-between;
    padding: 8mm 15mm 3mm;
    border-bottom: 1px solid #e0cba0;
  }
  .header img.logo-ecoflor { height: 48mm; max-width: 85mm; object-fit: contain; }
  .header img.logo-aeet    { height: 28mm; max-width: 52mm; object-fit: contain; }
  .header-center { text-align: center; flex: 1; padding: 0 10mm; }
  .conference-label { font-family: "Montserrat", sans-serif; font-weight: 300; font-size: 9pt; letter-spacing: 3px; text-transform: uppercase; color: #888; margin-bottom: 3px; }
  .conference-name  { font-family: "Montserrat", sans-serif; font-weight: 700; font-size: 14pt; color: #C8882A; letter-spacing: 1px; }
  .conference-sub   { font-size: 8pt; color: #666; font-style: italic; margin-top: 2px; }

  /* CONTENT */
  .content {
    flex: 1; min-height: 0; overflow: hidden;
    display: flex; flex-direction: column;
    align-items: center; justify-content: center;
    padding: 1mm 28mm; text-align: center; line-height: 1.45;
  }
  .cert-title {
    font-family: "Montserrat", sans-serif; font-weight: 600;
    font-size: 10.5pt; letter-spacing: 3px; text-transform: uppercase;
    color: #C8882A; margin-bottom: 2.5mm;
    border-bottom: 1px solid #e0cba0; padding-bottom: 1.5mm; width: 80%;
  }
  .cert-body      { font-size: 10.5pt; color: #333; max-width: 90%; }
  .cert-name      { font-size: 14pt; font-weight: 600; color: #1a1a1a; font-style: italic; display: block; margin: 2mm 0; }
  .cert-institution { font-size: 10pt; color: #555; font-style: italic; }
  .cert-pres-title  { font-size: 10pt; font-style: italic; color: #2c2c2c; font-weight: 600; }
  .cert-type-badge {
    display: inline-block; background: #C8882A; color: #fff;
    font-family: "Montserrat", sans-serif; font-weight: 600;
    font-size: 7.5pt; letter-spacing: 2px; padding: 2px 9px;
    border-radius: 2px; margin: 1.5mm 0; text-transform: uppercase;
  }

  /* FOOTER — compact */
  .footer {
    width: 100%; flex-shrink: 0;
    display: flex; align-items: flex-end; justify-content: center;
    padding: 2mm 22mm 20mm;
    border-top: 1px solid #e0cba0;
  }
  .signature-block { text-align: center; }
  .signature-block img { height: 28px; margin-bottom: 0; display: block; margin-left: auto; margin-right: auto; }
  .sig-name       { font-weight: 600; font-size: 7.5pt;   color: #1a1a1a; }
  .sig-role       { font-size: 6pt; color: #666; font-style: italic; }
  .location-date  { font-size: 6pt; color: #999; font-style: italic; margin-bottom: 1.5mm; }
</style>
</head>
<body>

<div class="border-outer"></div>
<div class="border-inner"></div>

<div class="header">
  <img src="', logo_ecoflor_b64, '" alt="ECOFLOR 2026" class="logo-ecoflor">
  <div class="header-center">
    <div class="conference-label">Certificate</div>
    <div class="conference-name">ECOFLOR 2026</div>
    <div class="conference-sub">23rd Meeting of the Spanish Society for Pollination Ecology</div>
  </div>
  <img src="', logo_aeet_b64, '" alt="AEET" class="logo-aeet">
</div>

<div class="content">
', body_html, '
</div>

<div class="footer">
  <div class="signature-block">
    <div class="location-date">Tortosa, Catalonia, Spain · 11–14 February 2026</div>
', sig_html, '
    <div class="sig-name">Carlos Hernández-Castellano</div>
    <div class="sig-role">On behalf of the Scientific Committee</div>
  </div>
</div>

</body>
</html>')
}

generate_pdf <- function(html_content, output_path) {
  tmp_html <- tempfile(fileext = ".html")
  writeLines(html_content, tmp_html, useBytes = TRUE)
  tryCatch(
    {
      pagedown::chrome_print(
        input = tmp_html, output = output_path, wait = 3,
        options = list(
          printBackground = TRUE, landscape = TRUE,
          paperWidth = 11.69, paperHeight = 8.27,
          marginTop = 0, marginBottom = 0, marginLeft = 0, marginRight = 0
        )
      )
      message("  ✓ ", basename(output_path))
    },
    error = function(e) {
      message("  ✗ FAILED: ", basename(output_path), " — ", conditionMessage(e))
    }
  )
  unlink(tmp_html)
}

# ── RESOLVE COLUMN NAMES ──────────────────────────────────────────────────────
col <- names(data_raw)

name_col <- intersect(c("Names", "Name"), col)[1]
pres_type_col <- intersect(c("Presentation"), col)[1]

# Oral title vs poster title — separate columns in this sheet
title_oral_col <- intersect(c("Presentation_title", "Presentation title"), col)[1]
title_poster_col <- intersect(c("Presentation title poster", "Presentation_title_poster"), col)[1]

# Authors — separate columns too
authors_oral_col <- intersect(c("Authors"), col)[1]
authors_poster_col <- intersect(c("Authors  poster", "Authors poster", "Authors_poster"), col)[1]

message("\nColumn mapping:")
message("  name:          ", name_col)
message("  pres_type:     ", pres_type_col)
message("  title_oral:    ", title_oral_col)
message("  title_poster:  ", title_poster_col)
message("  authors_oral:  ", authors_oral_col)
message("  authors_poster:", authors_poster_col)

# ── BUILD PRESENTATION DATA ───────────────────────────────────────────────────
pres_data <- data_raw %>%
  filter(
    !is.na(.data[[pres_type_col]]),
    nzchar(.data[[pres_type_col]]),
    str_detect(.data[[pres_type_col]], regex("oral|poster", ignore_case = TRUE))
  ) %>%
  mutate(
    name = .data[[name_col]],
    pres_type = .data[[pres_type_col]],
    is_poster = str_detect(pres_type, regex("poster", ignore_case = TRUE)),

    # Pick title from the correct column per type
    pres_title = ifelse(
      is_poster,
      if (!is.na(title_poster_col)) .data[[title_poster_col]] else NA_character_,
      if (!is.na(title_oral_col)) .data[[title_oral_col]] else NA_character_
    ),

    # Pick authors from the correct column per type
    authors = ifelse(
      is_poster,
      if (!is.na(authors_poster_col)) .data[[authors_poster_col]] else NA_character_,
      if (!is.na(authors_oral_col)) .data[[authors_oral_col]] else NA_character_
    )
  ) %>%
  select(name, pres_type, is_poster, pres_title, authors) %>%
  filter(!is.na(name), nzchar(name))

message("\n--- Presentation Certificates ---")
message("  Oral:   ", sum(!pres_data$is_poster))
message("  Poster: ", sum(pres_data$is_poster))
message("  Total:  ", nrow(pres_data))

# Sanity check: show poster titles
message("\n  Poster title sample:")
poster_check <- pres_data %>%
  filter(is_poster) %>%
  select(name, pres_title) %>%
  head(5)
for (i in seq_len(nrow(poster_check))) {
  message("    ", poster_check$name[i], " → ", substr(poster_check$pres_title[i], 1, 60))
}

# ── GENERATE PDFs ─────────────────────────────────────────────────────────────
pres_dir <- file.path(OUTPUT_DIR, "2_presentations")
dir.create(pres_dir, showWarnings = FALSE, recursive = TRUE)

for (i in seq_len(nrow(pres_data))) {
  row <- pres_data[i, ]
  name <- row$name
  ptype <- toupper(trimws(row$pres_type))
  title <- if (!is.na(row$pres_title) && nzchar(row$pres_title)) row$pres_title else "(untitled)"
  auths <- if (!is.na(row$authors) && nzchar(row$authors)) row$authors else name

  body <- paste0(
    '<div class="cert-title">Certificate of Presentation</div>
    <div class="cert-body">
      For any purpose it deems appropriate, we hereby certify that,
      <span class="cert-name">', htmlEscape(name), '</span>
      <span class="cert-type-badge">', htmlEscape(ptype), '</span>
      <br>
      has presented a contribution entitled<br>
      <span class="cert-pres-title">&ldquo;', htmlEscape(title), "&rdquo;</span>
      <br><br>
      scheduled within the <strong>23rd ECOFLOR Meeting</strong>,<br>
      held from <strong>11th to 14th February 2026</strong>, in <strong>Tortosa, Catalonia, Spain</strong>.
      <br><br>
      <small><em>Authors of the contribution:</em><br>", htmlEscape(auths), "</small>
    </div>"
  )

  html <- build_certificate_html(body, logo_ecoflor_b64, logo_aeet_b64, signature_b64)
  out <- file.path(pres_dir, paste0(tolower(ptype), "_", safe_name(name), ".pdf"))
  generate_pdf(html, out)
}

message("\n=== Done! ", nrow(pres_data), " PDFs in: ", normalizePath(pres_dir))
