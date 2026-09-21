@echo off

:: Render Czech version
cd "C:/Users/jakub/ownCloud/muj_web/jakubstenc/cz"
rename _quarto_cz.yml _quarto.yml
quarto render
rename _quarto.yml _quarto_cz.yml

:: Render English version
cd "C:/Users/jakub/ownCloud/muj_web/jakubstenc/en"
rename _quarto_en.yml _quarto.yml
quarto render
rename _quarto.yml _quarto_en.yml