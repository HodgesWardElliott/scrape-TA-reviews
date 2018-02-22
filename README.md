---
title: "Scraping TA Hotel Reviews"
output:
  html_document:
    keep_md: yes
---



Four scripts:

1) `scrape-tripadvisor-data.R`

2) `scrape-individual-hotels.R`

3) `extract-hotel-data.R`

3) `extract-hotel-data`

The first gathers a list of hotels and the associated links based on the `INPUT-list-of-cities.csv` file. 

The second script loops through the output of the first and downloads the html pages of individual hotel sites. 

The thirds script extracts data from the stored html pages. Fourth is for analyzing and producing results.
