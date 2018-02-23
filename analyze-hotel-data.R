
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

addresses <- distinct(hotel_data, title, address_street, address_city, full_address, full_link)

# Geo-coded via carto -----------------------------------------------------
# write_csv(hotel_data, 'data/export-to-carto.csv')
hotels_sf <- read_sf("data/import_from_carto.geojson")
  
hotels_sf_dist <- 
  hotels_sf %>% 
  mutate_at(vars(title:terrible_count), function(x) ifelse(x=="NA",0,x)) %>% 
  mutate_at(vars(count_main_photos:terrible_count), function(x) ifelse(x=="NA",0,x)) %>% 
  mutate_at(vars(count_main_photos:terrible_count), as.numeric) %>% 
  left_join(addresses, by = c("title", "address_street", "address_city", "full_address")) %>% 
  mutate(id = 1:n()) %>% 
  bind_cols(as_data_frame(st_coordinates(hotels_sf))) %>% 
  rename("lat" = Y, "lon" = X) %>% 
  distinct(lat, lon, .keep_all = T)

library(spdep)

hotels_sf_dist_located <- hotels_sf_dist %>% filter(!is.na(lat),!is.na(lon)) %>% st_transform(32618) #32618
coords <- hotels_sf_dist_located %>% select(lat,lon,id) %>% st_set_geometry(NULL) %>% as.matrix()
row.names(coords) <- coords[,3]
coords <- coords[,1:2]
nb <- knn2nb(knearneigh(coords, 20))
nb_dist <- dnearneigh(as_Spatial(st_geometry(hotels_sf_dist_located)), 0, 2000)
weights <- nb2listw(nb_dist, zero.policy = TRUE)


  hotel_quads <- 
  hotels_sf_dist_located %>% 
  st_set_geometry(NULL) %>% 
  filter(count_of_reviews>0) %>%
  mutate(clickable_link = paste0("<a href=", full_link," target='window'>",title,"</a>")
         ) %>% 
  group_by(city) %>% 
  nest() %>% 
  mutate(coords = map(data, ~as.matrix(data_frame("lon" = .x$lon, "lat" = .x$lat)))
          #coords = map(data, ~as_Spatial(st_geometry(st_as_sf(data_frame("lon" = .x$lon, "lat"=.x$lat), coords = c("lon","lat")))))
         , nb = map(coords, ~knn2nb(knearneigh(.x, 25)))
         #, nb = map(coords, ~dnearneigh(.x, 0, 0.5))
         , weights = map(nb, ~nb2listw(.x))
         , data = map(data, ~.x %>% mutate(scaled_overall_rating = scale(overall_rating)))
         , data = map2(weights, data, ~.y %>% mutate(lag = lag.listw(.x, .y$scaled_overall_rating)))
  ) %>% 
  unnest(data) %>% 
  mutate(cluster = ifelse(scaled_overall_rating >= 0 & lag >= 0, "High Cluster", "Other")
         ,cluster = ifelse(scaled_overall_rating >= 0 & lag <= 0, "Overperformer", cluster)
         ,cluster = ifelse(scaled_overall_rating <= 0 & lag >= 0, "Underperformer", cluster)
         ,cluster = ifelse(scaled_overall_rating <= 0 & lag <= 0, "Low Cluster", cluster)
  ) 

hotel_quads %>% 
  ggplot()+
  aes(x = scaled_overall_rating, y = lag, group = city, color = cluster)+
  geom_jitter()+
  geom_smooth(method = "lm", se = F)+
  facet_wrap(~city)

lm_model <- function(scaled_overall_rating, lag)  {
  summary(lm(scaled_overall_rating~lag))$r.squared
}

hotel_quads %>% 
  group_by(city) %>% 
  nest() %>% 
  mutate(linear = map_dbl(data, ~lm_model(.x$scaled_overall_rating, .x$lag))) %>% 
  mutate(total_av = mean(linear)) %>% 
  arrange(city)




st_as_sf(hotel_quads, coords = c("lon","lat")) %>% 
  write_sf("data/hotel-review-clustering.geojson", delete_dsn = TRUE)

hotel_quads %>% 
  select(title, city, full_address, rank_in_city, total_in_rank_list, overall_rating:terrible_count, full_link, lon, lat, scaled_overall_rating, "Neighbor Score" = lag, cluster) %>% 
  write_csv("data/Hotel Review Clusters.csv")












