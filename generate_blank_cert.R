library(pagedown)
library(htmltools)
library(base64enc)
library(stringr)

OUTPUT_DIR <- "documents/certificates/generated/3_workshops"
LOGO_ECOFLOR <- normalizePath("images/IMG_1108.jpg", mustWork = FALSE)
LOGO_AEET <- normalizePath("images/logos/AEET.png", mustWork = FALSE)
SIGNATURE <- normalizePath("documents/certificates/singature.png", mustWork = FALSE)

img_to_base64 <- function(path) {
  if (!file.exists(path)) return("")
  ext <- tolower(tools::file_ext(path))
  mime <- switch(ext, png = "image/png", jpg = , jpeg = "image/jpeg", "image/png")
  raw <- readBin(path, "raw", file.info(path)$size)
  paste0("data:", mime, ";base64,", base64enc::base64encode(raw))
}

logo_ecoflor_b64 <- img_to_base64(LOGO_ECOFLOR)
logo_aeet_b64 <- img_to_base64(LOGO_AEET)
signature_b64 <- img_to_base64(SIGNATURE)

sig_html <- if (nchar(signature_b64) > 0) {
  paste0('<img src="', signature_b64, '" alt="Signature" style="height:60px; margin-bottom:2px;">')
} else { "" }

html_content <- paste0('<!DOCTYPE html>
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
  .border-outer { position: absolute; inset: 8mm; border: 2.5px solid #C8882A; pointer-events: none; }
  .border-inner { position: absolute; inset: 11mm; border: 0.8px solid #C8882A; pointer-events: none; }
  .header {
    width: 100%; flex-shrink: 0; display: flex; align-items: center;
    justify-content: space-between; padding: 12mm 20mm 4mm;
    border-bottom: 1px solid #e0cba0;
  }
  .header img { height: 42mm; max-width: 70mm; object-fit: contain; }
  .header-center { text-align: center; flex: 1; padding: 0 10mm; }
  .conference-label { font-family: "Montserrat", sans-serif; font-weight: 300; font-size: 9pt; letter-spacing: 3px; text-transform: uppercase; color: #888; margin-bottom: 3px; }
  .conference-name { font-family: "Montserrat", sans-serif; font-weight: 700; font-size: 14pt; color: #C8882A; letter-spacing: 1px; }
  .conference-sub { font-size: 8pt; color: #666; font-style: italic; margin-top: 2px; }
  .content { flex: 1; min-height: 0; overflow: hidden; display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 2mm 30mm; text-align: center; line-height: 1.6; }
  .footer { width: 100%; flex-shrink: 0; display: flex; align-items: flex-end; justify-content: center; padding: 3mm 22mm 12mm; border-top: 1px solid #e0cba0; }
  .signature-block { text-align: center; }
  .signature-block img { height: 60px; margin-bottom: 1mm; display: block; margin-left: auto; margin-right: auto; }
  .sig-name { font-weight: 600; font-size: 10pt; color: #1a1a1a; }
  .sig-role { font-size: 8.5pt; color: #666; font-style: italic; }
  .location-date { font-size: 8pt; color: #999; font-style: italic; margin-bottom: 3mm; }
</style>
</head>
<body>
<div class="border-outer"></div>
<div class="border-inner"></div>
<div class="header">
  <img src="', logo_ecoflor_b64, '" alt="ECOFLOR 2026">
  <div class="header-center">
    <div class="conference-label">Certificate</div>
    <div class="conference-name">ECOFLOR 2026</div>
    <div class="conference-sub">23rd Meeting of the Spanish Society for Pollination Ecology</div>
  </div>
  <img src="', logo_aeet_b64, '" alt="AEET">
</div>
<div class="content"></div>
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

tmp_html <- tempfile(fileext = ".html")
writeLines(html_content, tmp_html, useBytes = TRUE)
pdf_out <- file.path(OUTPUT_DIR, "blank_certificate.pdf")
png_out <- file.path(OUTPUT_DIR, "blank_certificate.png")

dir.create(OUTPUT_DIR, showWarnings=FALSE, recursive=TRUE)

pagedown::chrome_print(
  input = tmp_html,
  output = pdf_out,
  wait = 3,
  options = list(
    printBackground = TRUE, landscape = TRUE,
    paperWidth = 11.69, paperHeight = 8.27,
    marginTop = 0, marginBottom = 0, marginLeft = 0, marginRight = 0
  )
)

# Render to PNG using chrome_print (which uses headless chrome)
pagedown::chrome_print(
  input = tmp_html,
  output = png_out,
  wait = 3,
  format = "png",
  options = list(
    printBackground = TRUE, landscape = TRUE,
    paperWidth = 11.69, paperHeight = 8.27,
    marginTop = 0, marginBottom = 0, marginLeft = 0, marginRight = 0
  )
)

unlink(tmp_html)
