
# load packages:
if(!"pacman"%in%installed.packages()){
  install.packages("pacman")
}
pacman::p_load(rvest, tidyverse, stringr, httr, parallel, sf)

total_list <- read_rds("data/processed_html_data.rds")

hotel_data <- 
  total_list %>% 
  map(~ifelse(lengths(.x)!=1, NA, .x)) %>% 
  map(bind_rows) %>% 
  bind_rows()

# count of hotels
hotel_data %>% 
  mutate(City = str_replace_all(address_city, "[, ]|[A-Z][A-Z]|[0-9]+[-][0-9]+|[0-9]+","")) %>% 
  group_by(City) %>% 
  tally()

hotel_data <- hotel_data %>% mutate(City = str_replace_all(address_city, "[, ]|[A-Z][A-Z]|[0-9]+[-][0-9]+|[0-9]+",""))

# write_csv(hotel_data, 'data/export-to-carto.csv')

hotels_sf <- read_sf("data/import_from_carto.geojson")

atl <- hotels_sf %>% filter(city=="Atlanta")

atl %>% 
  