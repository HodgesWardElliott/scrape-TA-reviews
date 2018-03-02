

library(RSelenium)
# debug version: sudo docker run -d -p 4445:4444 -p 5901:5900 selenium/standalone-firefox-debug:2.53.0
# IP:port is 127.0.0.1:5901
# password is 'secret'
# non-debug version: system("docker run -d -p 4445:4444 selenium/standalone-firefox:latest")

if(!"pacman"%in%installed.packages()){
  install.packages("pacman")
}

pacman::p_load(rvest, tidyverse, stringr, httr, parallel)


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
  already_scraped <- read_csv('data/in_progress_extracting_roomcounts.csv')
} else {
  already_scraped <- data_frame("id" = NA, "Room_count" = NA)
}


clean_links <- anti_join(clean_links, already_scraped, by = "id")
clean_links <- head(clean_links, 100)

# open driver
if(exists("remDr")){
  remDr$closeall()
  rm(remDr)
}

remDr <- remoteDriver(port = 4445L)
remDr$open(silent = TRUE)
remDr$setTimeout(type = "implicit", milliseconds = 10000)
remDr$setTimeout(type = "page load", milliseconds = 10000)

start_time <- Sys.time()
out_links <- data_frame()
for(ii in 1:nrow(clean_links)){
  # ii <- 18
  the_link <- as.character(clean_links[ii,"full_link"])
  the_id <- as.integer(clean_links[ii,"id"])
  try_counter <- 0
  message("\nWorking on ",ii," of ",nrow(clean_links)," ",the_link)
  
  for(jj in 1:3){
    # jj <- 1
    message("     try number: ",jj)
    
    # check if connection is still fresh:
    if(length(remDr$getCurrentUrl())==0){
      message("    re-establishing connection...")
      try({
        remDr$closeall()
        rm(remDr)
        remDr <- remoteDriver(port = 4445L)
        remDr$open(silent = TRUE)
        remDr$setTimeout(type = "implicit", milliseconds = 10000)
        remDr$setTimeout(type = "page load", milliseconds = 10000)
        }, silent = TRUE, finally = message("     ...connection re-established"))
    }
    
    # navigate to link
    message("     navigating to link...")
    remDr$navigate(the_link)
    message("     address found...")
    Sys.sleep(2)
    
    message("     testing cxn...")
    if(length(remDr$findElements("css", ".cta_more"))!=0){
      
      # find the expansion box:
      message("     extracting elements...")
      webElem <- tryCatch(remDr$findElement('css', ".cta_more"),  error = function(e) e, finally = message("     ...element found"))
      
      # click the link (and give it a minute to load)
      webElem$clickElement() # WORKS WORKS WORKS WORKS WORKS !!!!!!!!!!!!!!!!
      Sys.sleep(3)
      
      # source the page and extract room count
      raw_source <- remDr$getPageSource()[[1]]
      
      the_html <- raw_source %>% read_html() 
      
      the_node <- the_html %>% html_node("#ABOUT_TAB") 
      
      the_text <- the_node %>% html_text()
      
      our_text <- the_text %>% str_extract("Number of rooms[0-9]+")
      
      clean_text <- our_text %>% str_replace("Number of rooms","")
      
      room_count <- as.numeric(clean_text)
      
      message("     text found: ", our_text)
      message("     element extracted: ",room_count)
      
    } else {
      room_count <- NA
    }
    
    if(is.na(as.numeric(room_count)) | is.null(room_count)) room_count <- NA
    
    if(!is.na(room_count)) break
    }
  message("     breaking and moving to next")
  if(is.na(as.numeric(room_count)) | is.null(room_count)) room_count <- NA
  
  out <- data_frame("id" = the_id, "Room_count" = room_count)
  
  if(!file.exists('data/in_progress_extracting_roomcounts.csv')){
    write_csv(out, 'data/in_progress_extracting_roomcounts.csv', append = FALSE)
  } else {
    write_csv(out, 'data/in_progress_extracting_roomcounts.csv', append = TRUE)
  }
  
  out_links <- bind_rows(out_links, out)
  
  message("     length of output now ", nrow(out_links))
  
}
end_time <- Sys.time()
# file.remove('data/in_progress_extracting_roomcounts.csv')

remDr$close()

nrow(out_links);(tot_time <- end_time - start_time)
summary(out_links$Room_count)





