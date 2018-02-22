
# load packages:
if(!"pacman"%in%installed.packages()){
  install.packages("pacman")
}
pacman::p_load(rvest, tidyverse, stringr, httr, parallel)

# flow control for file existenceL:
if(!file.exists("data/OUTPUT-hotel-link-list.csv")) stop("File require: OUTPUT-hotel-link-list.csv. Did you run scrape-tripadvisor-data.R yet?")
all_links <- suppressMessages(read_csv("data/OUTPUT-hotel-link-list.csv"))
if(length(dir('data/html_raw'))!=length(unique(all_links$href))) stop("You seem to be missing some links int he html_raw folder")


# cheeck to see if some of the pages have already been processed:
all_pages <- dir('data/html_raw')
if(file.exists("data/raw_html_already_processed.csv")) {
  already_processed <- suppressMessages(read_csv("data/raw_html_already_processed.csv"))
} else {
  already_processed <- data_frame("pages_of_interest" = NA)
}
yet_to_process <- all_pages[!all_pages %in% unique(already_processed$pages_of_interest)]

# extract data from the html files:
total_list <- list()
for(jj in 1:length(yet_to_process)){
  # jj <- 1
  page_of_interest <- yet_to_process[jj]
  message("Working on ",jj," of ",length(yet_to_process))
  
  raw_html <- read_html(paste0('data/html_raw/',page_of_interest))
  
  # extract data ------------------------------------------------------------
  
  data_list <- list()
  
  data_list$title <- 
    raw_html %>% 
    html_nodes("#HEADING") %>% 
    html_text()
  
  data_list$rating_of_five <- 
    raw_html %>% 
    html_nodes("#taplc_resp_hr_atf_hotel_info_0 .bubble_45") %>% 
    html_attr("alt") %>% 
    str_replace_all(" of 5 bubbles","") %>% 
    as.numeric()
  
  data_list$number_of_reviews <- 
    raw_html %>% 
    html_nodes(".reviewCount") %>% 
    html_text() %>% 
    str_replace_all(" reviews","") %>% 
    as.numeric()
  
  data_list$Rank_in_city <- 
    raw_html %>% 
    html_nodes(".rank") %>% 
    html_text() %>% 
    str_replace_all("[#]","") %>% 
    as.numeric()
  
  data_list$total_in_rank_list <- 
    raw_html %>% 
    html_nodes(".popIndexValidation") %>% 
    html_text() %>% 
    str_replace_all("[#][0-9]+ Best Value of | [hH]otels in *.*|[#][0-9]+ of ","") %>% 
    as.numeric()
  
  address_street <- 
    raw_html %>% 
    html_node(".street-address") %>% 
    html_text()
  
  data_list$address_street <- address_street
  
  address_city <- 
    raw_html %>% 
    html_node(".locality") %>% 
    html_text()
  
  data_list$address_city <- address_city
  
  data_list$full_address <- paste(address_street, address_city, sep = ", ")
  
  data_list$cert_of_excellence <- 
    raw_html %>% 
    html_node(".certificate-of-excellence") %>% 
    html_text()
  
  data_list$count_main_photos <- 
    raw_html %>% 
    html_node(".see_all_count .is-hidden-mobile") %>% 
    html_text() %>% 
    str_replace_all(" All photos [(]|[)]","") %>% 
    as.numeric()
  
  data_list$overall_rating <- 
    raw_html %>% 
    html_node(".overallRating") %>% 
    html_text() %>% 
    str_replace_all(" ","") %>% 
    as.numeric()
  
  
  data_list$count_of_reviews <- 
    raw_html %>% 
    html_node(".reviews_header_count") %>% 
    html_text() %>% 
    str_replace_all("[()]","") %>% 
    as.numeric()
  
  
  sub_ratings <- 
    raw_html %>% 
    html_node(".is-5 .choices") %>% 
    html_text()
  
  sub_choices <- str_split(sub_ratings, "[0-9]+") %>% .[[1]] %>% .[.!=""]
  sub_counts <- str_replace_all(sub_ratings, "Excellent|Very good|Average|Poor|Terrible| "," ") %>% str_split(" ") %>% .[[1]] %>% .[.!=""]
  
  data_list$Excellet_count <- as.numeric(sub_counts[1])
  data_list$VGood_count <- as.numeric(sub_counts[2])
  data_list$Average_count <- as.numeric(sub_counts[3])
  data_list$Poor_count <- as.numeric(sub_counts[4])
  data_list$Terrible_count <- as.numeric(sub_counts[5])
  
  total_list[[data_list$title]] <- data_list
  
  if(file.exists("data/raw_html_already_processed.csv")){
    write_csv(data_frame("pages_of_interest" = page_of_interest), "data/raw_html_already_processed.csv", append = TRUE)
    } else {
      write_csv(data_frame("pages_of_interest" = page_of_interest), "data/raw_html_already_processed.csv", append = FALSE)
      }
  write_rds(total_list, "data/processed_html_data.rds")
  }


# file.remove("data/raw_html_already_processed.csv")
# file.remove("data/processed_html_data.rds")

total_list %>% 
  head(10) %>% 
  map(~ifelse(lengths(.x)!=1, NA, .x)) %>% 
  map(bind_rows) %>% 
  bind_rows()













