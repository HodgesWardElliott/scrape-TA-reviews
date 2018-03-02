

# load packages:
source("~/toClip.R")
if(!"pacman"%in%installed.packages()){
  install.packages("pacman")
}
pacman::p_load(rvest, tidyverse, stringr, httr, parallel, sf)

batch_1 <- read_csv("Manual-roomcounts-TA batch v001.csv")
batch_2 <- read_csv("Manual-roomcounts--doneTA batch v002.csv")
all_batches <- bind_rows(batch_1, batch_2)
map_in_room_counts <- select(all_batches, title, full_address, `Room Count`)

total_list <- read_rds("data/processed_html_data.rds")
hotel_data <- 
  total_list %>% 
  map(~.[[1]]) %>% 
  map(~ifelse(lengths(.x)!=1, NA, .x)) %>% 
  map(bind_rows) %>% 
  bind_rows() %>% 
  mutate(City = str_replace_all(address_city, "[, ]|[A-Z][A-Z]|[0-9]+[-][0-9]+|[0-9]+","")) %>% 
  distinct(hotel_data, title, .keep_all = T) 


hotel_data <-
  hotel_data %>% 
  left_join(map_in_room_counts, by = c("title", "full_address")) %>% glimpse


review_data <- 
  hotel_data %>% 
  filter(count_of_reviews>0) %>%
  mutate(clickable_link = paste0("<a href=", full_link," target='window'>",title,"</a>")) %>% 
  group_by(City) %>% 
  mutate(rank_in_city = as.numeric(Rank_in_city)) %>% 
  mutate(rank_quartile = ntile(Rank_in_city, 4)) %>% 
  ungroup() %>% 
  select(title, City, full_address, rank_in_city, total_in_rank_list, 
         overall_rating:Terrible_count, full_link, rank_quartile, `Room Count`)
  
review_data %>% toClip()


not_yet_reviewed <- 
  review_data %>% 
  filter(rank_quartile%in%c(3,4)) %>% 
  anti_join(batch_1, by = c("title", "full_address")) %>% 
  group_by(City) %>% 
  top_n(20, rank_in_city) %>% 
  arrange(rank_in_city)

unique(not_yet_reviewed$City)
unique(batch_1$City)

# write_csv(not_yet_reviewed, "Manual-roomcounts-TA batch v002.csv")

