library(officer)
doc <- read_pptx()
doc <- add_slide(doc, layout = "Title Slide", master = "Office Theme")
doc <- ph_with(x = doc, value = external_img("documents/certificates/generated/3_workshops/blank_certificate.png"), location = ph_location_fullsize())
doc <- ph_with(x = doc, value = "C E R T I F I C A T E   O F   A T T E N D A N C E\n\nT O   W O R K S H O P", location = ph_location_type(type="ctrTitle"))
doc <- ph_with(x = doc, value = "We hereby certify that,\n\n[Name]\n\nhas attended the Workshop\n\n“[Workshop Name]”\n\nwith a total duration of 3 teaching hours,\nheld on Wednesday, February 11, 2026,\nas part of the Scientific program of the 23rd ECOFLOR Meeting,\nheld from 11th to 14th February 2026, in Tortosa, Catalonia, Spain.", location = ph_location_type(type="subTitle"))
print(doc, target = "documents/certificates/generated/3_workshops/blank_certificate.pptx")

