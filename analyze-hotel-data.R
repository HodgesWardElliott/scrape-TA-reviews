
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
  mutate(City = str_replace_all(address_city, "[, ]|[A-Z][A-Z]|[0-9]+[-][0-9]+|[0-9]+","")) %>% 
  distinct(hotel_data, title, .keep_all = T) 
  

# count of hotels
hotel_data %>% 
  group_by(City) %>% 
  tally()

# don't geocode things that have already gone through
hotels_sf <- read_sf("data/import_from_carto.geojson")
not_yet_geocoded <- anti_join(hotel_data, hotels_sf, by = "title")

# SEND TO CARTO FOR GEOCODING
# write_csv(not_yet_geocoded, 'data/export-to-carto.csv')
addresses <- distinct(hotel_data, title, address_street, address_city, full_address, full_link)


  
# quartiles by rank  -------------------------------------------------

hotel_quads <- 
  hotel_data %>% 
  filter(count_of_reviews>0) %>%
  mutate(clickable_link = paste0("<a href=", full_link," target='window'>",title,"</a>")
  ) %>% 
  group_by(City) %>% 
  mutate(rank_in_city = as.numeric(Rank_in_city)) %>% 
  mutate(rank_quartile = ntile(Rank_in_city, 4)) %>% 
  ungroup()

hotel_quads %>% 
  select(title, City, full_address, rank_in_city, total_in_rank_list, 
         overall_rating:Terrible_count, full_link, rank_quartile) %>% 
  filter(rank_quartile%in%c(3,4)) %>% 
  group_by(City) %>% 
  top_n(15, rank_in_city) %>% 
  arrange(rank_in_city) %>% 
  write_csv("data/Hotel Review Quartiles.csv")


hotel_quads %>% filter(title=="Hotel Seattle") %>% glimpse()









