
# scrape a list of hotels from TA

if(!"pacman"%in%installed.packages()){
  install.packages("pacman")
}
pacman::p_load(rvest, tidyverse, stringr, httr )

if(!dir.exists("data")){
  dir.create("data")
}

# input ase cities + base url's in this csv:
city_base_pages <- read_csv("INPUT-list-of-cities.csv")

# add "oa%s" to each URL foro paginating later
inject_sprintf <- function(string){
  first_part <- paste0(strsplit(string,"")[[1]][1:42], collapse = "")
  last_part <- paste0(strsplit(string,"")[[1]][43:length(strsplit(string,"")[[1]])], collapse = "")
  glued <- paste0(first_part, "oa%s-", last_part)
}

city_base_pages$modified_url <- map_chr(city_base_pages$Link, inject_sprintf)


# if a city has already been scraped, don't waste the time
if(file.exists("data/OUTPUT-hotel-link-list.csv")){
  already_scraped <- read_csv("data/OUTPUT-hotel-link-list.csv")
} else already_scraped <- data_frame("city" = NA)

city_base_pages_not_done <- city_base_pages %>% filter(!City %in% unique(already_scraped$city))

if(nrow(city_base_pages_not_done)==0) {
  stop("No new citites to scrape")
  }

# disply target cities
message("working on the following cities: "
        , "\n"
        , paste0(city_base_pages_not_done$City, sep = "\n")
)


out_frame <- data.frame()
for(jj in 1:nrow(city_base_pages_not_done)){ # one outer loop for each city
  
  # jj <- 1
  
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
        counter <- counter+1
        break("links repeating, ending loop...")
      }
    }
    
    all_results <- bind_rows(all_results, links_and_ids)
    counter <- counter+1
    
    if(counter-1>=length(all_page_offsets)) break
  }
  
  
  out_frame <- bind_rows(out_frame, all_results)
  
  message('writing to csv...')
  
  if(file.exists("data/OUTPUT-hotel-link-list.csv")){
    write_csv(all_results, "data/OUTPUT-hotel-link-list.csv", append = TRUE)
  } else write_csv(all_results, "data/OUTPUT-hotel-link-list.csv", append = FALSE)
  
}

# file.remove("data/OUTPUT-hotel-link-list.csv")

pat <- "[#][0-9]+ Best Value of | [hH]otels in *.*|[#][0-9]+ of "

# summarise and view the output:
#1 Best Value of 167 hotels in New Orlean
out_frame %>% 
  mutate(rank_text_mod = str_replace(rank_text, pat, "")) %>% 
  group_by(city, rank_text_mod) %>% 
  tally() 

nrow(out_frame)

out_frame %>% 
  group_by(id) %>% 
  summarise(count = n()) %>% 
  arrange(-count) %>% 
  count(count)



