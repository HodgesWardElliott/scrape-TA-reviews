
# load packages:
if(!"pacman"%in%installed.packages()){
  install.packages("pacman")
}
pacman::p_load(rvest, tidyverse, stringr, httr, parallel, sf)

total_list <- read_rds("data/processed_html_data.rds")

hotel_data <- 
  total_list %>% 
  map(~.[[1]]) %>% 
  map(~ifelse(lengths(.x)!=1, NA, .x)) %>% 
  map(bind_rows) %>% 
  bind_rows() %>% 
  mutate(City = str_replace_all(address_city, "[, ]|[A-Z][A-Z]|[0-9]+[-][0-9]+|[0-9]+",""))

# count of hotels
hotel_data %>% 
  group_by(City) %>% 
  tally()



# Geo-coded via carto -----------------------------------------------------
# write_csv(hotel_data, 'data/export-to-carto.csv')
hotels_sf <- read_sf("data/import_from_carto.geojson")

hotels_sf <- 
  hotels_sf %>% 
  mutate_at(vars(title:terrible_count), function(x) ifelse(x=="NA",0,x)) %>% 
  mutate_at(vars(count_main_photos:terrible_count), function(x) ifelse(x=="NA",0,x)) %>% 
  mutate_at(vars(count_main_photos:terrible_count), as.numeric)


write_sf(hotels_sf, "data/TA-review-data.geojson")
  

library(spdep)
nb <- dnearneigh(st_coordinates(hotels_sf), 0, 500, na.)






