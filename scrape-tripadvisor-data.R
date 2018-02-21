
# scrape a list of hotels from TA

library(rvest)
library(tidyverse)
library(stringr)
library(httr)


# input ase cities + base url's in this csv:
city_base_pages <- read_csv("data/list-of-tripadvisor-city-basepages.csv")

# add "oa%s" to each URL foro paginating later
inject_sprintf <- function(string){
  first_part <- paste0(strsplit(string,"")[[1]][1:42], collapse = "")
  last_part <- paste0(strsplit(string,"")[[1]][43:length(strsplit(string,"")[[1]])], collapse = "")
  glued <- paste0(first_part, "oa%s-", last_part)
}

city_base_pages$modified_url <- map_chr(city_base_pages$Link, inject_sprintf)


# if a city has already been scraped, don't waste time
if(file.exists("data/hotel-name-list-scrape.csv")){
  already_scraped <- read_csv("data/hotel-name-list-scrape.csv")
} else already_scraped <- data_frame("city" = NA)

city_base_pages_not_done <- city_base_pages %>% filter(!City %in% unique(already_scraped$city))

# disply target cities
message("working on the following cities: "
        , "\n"
        , paste0(city_base_pages_not_done$City, sep = "\n")
)


out_frame <- data.frame()
for(jj in 1:nrow(city_base_pages_not_done)){ # one outer loop for each city
  
  # some constansts for the loop
  city <- city_base_pages_not_done$City[jj]
  base_link <- city_base_pages_not_done$Link[jj]
  base_link_mod <- city_base_pages_not_done$modified_url[jj]
  message("#==========> Now working on ",city,", ",jj," of ",nrow(city_base_pages_not_done),"\n")
  all_page_offsets <- 0:25 * 30 # TA delivers pages in multiples of 30 results per page. 25 should cover most situations (Houston had 22 pages, higest)
  all_results <- data_frame()
  counter <- 1
  
  while(counter>-1) {
    
    offset <- all_page_offsets[counter]
    message(city,", ",jj," of ",nrow(city_base_pages_not_done) ," Counter ", counter," of ",length(all_page_offsets)," offset ", offset)
    message()
    Sys.sleep(2)
    
    # our request url:
    request <- sprintf(base_link_mod, offset)
    message(request, " ...trying")
    response <- GET(request)
    
    if(response$status_code!=200) {
      message("Status code not 200, trying again in 5 seconds...")
      Sys.sleep(5)
      next()
    }
    message(response$url," ...found\n")
    
    
    
    # extract data: -----------------------------------------------------------
    
    the_html <- response %>% read_html() 
    
    # the_html <- read_html("https://www.tripadvisor.com/Hotels-g60898-Atlanta_Georgia-Hotels.html") 
    
    tryCatch({
      
      links_and_ids <- 
        the_html %>% 
        html_nodes(".prw_meta_hsx_responsive_listing.bottom-sep .prominent") %>% 
        html_attrs() %>% 
        map(bind_rows) %>% 
        bind_rows() %>% 
        select(href, id)
      
      links_and_ids$rank_text <- 
        the_html %>% 
        html_nodes(".popindex") %>% 
        html_text()
      
      links_and_ids$star_text <- 
        the_html %>% 
        html_nodes("div.metaListingWrapper span.ui_bubble_rating, div.prw_rup:nth-of-type(n+2) div.info-col span.ui_bubble_rating") %>% 
        html_attr("alt")
      
      links_and_ids$review_count_text<-
        the_html %>% 
        html_nodes("div.metaListingWrapper a.review_count, div.prw_rup:nth-of-type(n+2) a.review_count") %>% 
        html_text()
      
      links_and_ids$city <- city
    }, error = function(e) {
      e
      break
    }
    )
    
    
    
    links_and_ids$base_link <- base_link
    links_and_ids$base_link_mod <- base_link_mod
    links_and_ids$offset <- offset
    
    
    if(counter>1){
      if(sum(!links_and_ids$id%in%all_results$id) <10) {
        message("links repeating, ending loop...")
        break
      }
    }
    
    all_results <- bind_rows(all_results, links_and_ids)
    counter <- counter+1
    
    if(counter-1>=length(all_page_offsets)) break
  }
  
  
  out_frame <- bind_rows(out_frame, all_results)
  
  message('writing to csv...')
  
  if(file.exists("data/hotel-name-list-scrape.csv")){
    write_csv(out_frame, "data/hotel-name-list-scrape.csv", append = TRUE)
  } else write_csv(out_frame, "data/hotel-name-list-scrape.csv", append = FALSE)
  
}

# file.remove("hotel-name-list-scrape.csv")




pat <- "[#][0-9]+ Best Value of | hotels in *.*"

out_frame %>% 
  mutate(rank_text_mod = str_replace(rank_text, pat, "")) %>% 
  group_by(city, rank_text_mod) %>% 
  tally() 

nrow(out_frame)






