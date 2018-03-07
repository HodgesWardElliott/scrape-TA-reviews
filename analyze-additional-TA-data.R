

library(tidyverse)

base_link_global <- "https://www.tripadvisor.com"
all_links <- suppressMessages(read_csv("data/OUTPUT-hotel-link-list.csv"))

clean_links <- 
  all_links %>% 
  mutate(id = as.integer(gsub("property_","",id))
         , full_link = paste0(base_link_global, href)
         , total_rank = suppressWarnings(as.integer(str_replace_all(rank_text, "[#][0-9]+ Best Value of | hotels in *.*", "")))
         , rank = str_extract_all(rank_text, "[#][0-9]")
         , rank = as.integer(str_replace_all(rank, "[#]",""))
         , overall_stars = as.numeric(str_replace_all(star_text, " of [0-9] bubbles",""))
         , review_count = as.numeric(str_replace_all(review_count_text, "[,]| reviews| review",""))) %>% 
  select(-contains("_text")) 



# join rooms counts to original data and write to csv
room_counts <- suppressMessages(read_csv('data/in_progress_extracting_roomcounts.csv'))
data_with_room_counts <- left_join(clean_links, room_counts, by = "id")
data_with_room_counts %>% summary()
write_csv(data_with_room_counts, "FINAL-data-with-room-counts.csv")