#!/usr/bin/Rscript --default-packages=methods,datasets,utils,grDevices,graphics,stats

# note the extra Rscript arguments above. Rscript does not load methods by default, for example, which will cause the script to fail

## install docker: https://cran.r-project.org/web/packages/RSelenium/vignettes/RSelenium-docker.html
## run docker image from console: 
# stable debug version: sudo docker run -d -p 4445:4444 -p 5901:5900 selenium/standalone-firefox-debug:3.1.0
# IP:port is 127.0.0.1:5901
# password is 'secret'
# non-debug version: sudo docker run -d -p 4445:4444 selenium/standalone-firefox:3.1.0


## This entry in crontab runs the script every 5 minutes with a ~5 minute timeout. No other modifications to cron tab are needed on ubuntu (path, etc)
#*/5 * * * *     /bin/bash -c "timeout 250 /home/rstudio/scrape-TA-reviews/scrape-additional-data.R"

# Note when running on cron tab, Rstudio project home directories do not work (for example write_csv(data,"data/data_out.csv")) will fail
# because it is a relative path. So, it is wise to manually setwd() or add a HOME path variable
setwd("/home/rstudio/scrape-TA-reviews")


# checks to see if docker is running and starts one, if not
avail_containers <- system("docker ps", intern = TRUE)
if(length(avail_containers)<2){
  message("starting a fresh docker container...")
  system('docker run -d -p 4445:4444 selenium/standalone-firefox:3.1.0')
  Sys.sleep(10)
} else message("docker container already running")


if(!"pacman"%in%installed.packages()){
  install.packages("pacman")
}
pacman::p_load(rvest, tidyverse, stringr, httr, parallel, RSelenium)
require(rvest)
require(tidyverse)
require(stringr)
require(httr)
require(parallel)
require(RSelenium)
require(methods)


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


if(file.exists('data/in_progress_extracting_roomcounts.csv')){
  already_scraped <- suppressMessages(read_csv('data/in_progress_extracting_roomcounts.csv'))
} else {
  already_scraped <- data_frame("id" = NA, "Room_count" = NA)
}


clean_links <- anti_join(clean_links, already_scraped, by = "id")
(left_to_scrape_count <- nrow(clean_links))

write_csv(data.frame("MRR" = paste0("Most recent run: ", format(Sys.time(), tz = "EST")," EST. Left: ", left_to_scrape_count)), 'MRR.txt', append = T)
message("Total left to scrape: ", left_to_scrape_count)
# clean_links <- head(clean_links, 20)

# connect to server
remDr <- remoteDriver(port = 4445L, browserName = "firefox")
# remDr$open(silent = TRUE)



start_time <- Sys.time()
out_links <- data_frame()
for(ii in 1:nrow(clean_links)) {
  # ii <- 50
  the_link <- as.character(clean_links[ii,"full_link"])
  the_id <- as.integer(clean_links[ii,"id"])
  try_counter <- 0
  message("\nWorking on ",ii," of ",nrow(clean_links)," ",the_link)
  message("     Time elapsed: ", round(Sys.time()-start_time, 2), units(Sys.time()-start_time))
  
  message("     opening browser...")
  remDr$open(silent = TRUE)
  
  # navigate to link
  message("     navigating to link...")
  remDr$navigate(the_link)
  Sys.sleep(5)
  
  # sometimes room count is visibile on top
  message("     testing for room count on top")
  loaded_page <- remDr$getPageSource()[[1]] 

  test_for_more_button <- 
    loaded_page %>% 
    read_html() %>% 
    html_node(".cta_more") %>% 
    as.character()
  
  if(!is.na(test_for_more_button)){
    message("     locating the load more button...")
    webElem <- remDr$findElement('css', ".cta_more")
    Sys.sleep(2)
    
    message("     clicking the load more button...")
    webElem$clickElement() # WORKS !!!!!!!!!!!!!
    Sys.sleep(5)
    loaded_page <- remDr$getPageSource()[[1]]
    }
  
  
  
  message("     extracting room count...")
  # if the element doesn't exist, it will return NA
  
  about_tab <- 
    loaded_page %>% 
    read_html() %>% 
    html_node("#ABOUT_TAB") %>% 
    html_text()
  
  clean_text <- 
    about_tab %>% 
    str_extract("Number of rooms[0-9]+") %>% 
    str_replace("Number of rooms","")
  
  if(!is.na(clean_text)){
    room_count <- as.numeric(clean_text)
  } else {
    room_count <- as.numeric(NA)
  }
  
  message("     about tab text found: ", substr(about_tab,1,50))
  message("     element extracted: ", room_count)
  
  if(is.na(as.numeric(room_count)) | is.null(room_count)) room_count <- as.numeric(NA)
  out <- data_frame("id" = the_id, "Room_count" = room_count)
  
  if(!file.exists('data/in_progress_extracting_roomcounts.csv')){
    write_csv(out, 'data/in_progress_extracting_roomcounts.csv', append = FALSE)
  } else {
    write_csv(out, 'data/in_progress_extracting_roomcounts.csv', append = TRUE)
  }
  
  out_links <- bind_rows(out_links, out)
  remDr$quit()
  
}

message("stopping docker selenium server...")
remDr$quit()
system('docker stop $(docker ps -q)')
end_time <- Sys.time()
# file.remove('data/in_progress_extracting_roomcounts.csv')

nrow(out_links);(tot_time <- end_time - start_time)
summary(out_links$Room_count)





