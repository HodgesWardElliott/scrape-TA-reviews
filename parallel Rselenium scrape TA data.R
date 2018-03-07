##!/usr/bin/Rscript

if(!"pacman"%in%installed.packages()){
  install.packages("pacman")
}
pacman::p_load(seleniumPipes, rvest, magrittr, stringr, httr, doParallel, foreach)


system("docker stop $(docker ps -q)")
avail_containers <- system("docker ps", intern = TRUE)
if(length(avail_containers)<2){
  message("starting docker container")
  system("docker run -d -p 4445:4444 -p 5901:5900 selenium/standalone-firefox:3.1.0")
} else message("docker container already running")


URLsPar <- c("http://www.bbc.com/", "http://www.cnn.com", "http://www.google.com",
             "http://www.yahoo.com", "http://www.twitter.com")

(cl <- (detectCores()/2) %>%  makeCluster) %>% registerDoParallel
# registerDoSEQ()

# open a remoteDriver for each node on the cluster
clusterEvalQ(cl, {
  library(seleniumPipes)
  remDr <- remoteDr(browserName = "firefox", port = 4445L, silent = TRUE)
})
myTitles <- c()
ws <- foreach(x = 1:length(URLsPar), .packages = c("rvest", "magrittr", "seleniumPipes"))  %dopar%  {
  remDr %>% go(URLsPar[x])
  remDr %>% getTitle()[[1]]
}

# close browser on each node
clusterEvalQ(cl, {
  remDr$close()
})

stopImplicitCluster()
stopCluster(cl)
# stop Selenium Server


