

if(!file.exists("data/OUTPUT-hotel-link-list.csv")) stop("File require: OUTPUT-hotel-link-list.csv. Did you run scrape-tripadvisor-data.R yet?")

if(!dir.exists("data/html_raw")){
  dir.create("data/html_raw")
}

if(!"pacman"%in%installed.packages()){
  install.packages("pacman")
}

pacman::p_load(rvest, tidyverse, stringr, httr, parallel)


base_link_global <- "https://www.tripadvisor.com"
all_links <- read_csv("data/OUTPUT-hotel-link-list.csv")

clean_links <- 
  all_links %>% 
  mutate(id = as.integer(gsub("property_","",id))
         , full_link = paste0(base_link_global, href)
         , total_rank = as.integer(str_replace_all(rank_text, "[#][0-9]+ Best Value of | hotels in *.*", ""))
         , rank = str_extract_all(rank_text, "[#][0-9]")
         , rank = as.integer(str_replace_all(rank, "[#]",""))
         , overall_stars = as.numeric(str_replace_all(star_text, " of [0-9] bubbles",""))
         , review_count = as.numeric(str_replace_all(review_count_text, "[,]| reviews| review",""))) %>% 
  select(-contains("_text")) 


full_links <- clean_links$full_link
links_not_downloaded <- full_links[!basename(full_links) %in% dir('data/html_raw')]
writeLines(links_not_downloaded, 'data/links_not_downloaded.txt')

message("Downloading html pages in parallel using xargs at ",Sys.time())
system(paste0("cat 'data/links_not_downloaded.txt'| xargs -n 1 -P ", ceiling(parallel::detectCores()/2)," wget -c -P 'data/html_raw'")
       , ignore.stdout = T
       , ignore.stderr = T
       , wait = T)

message("     ...html files downloaded")


