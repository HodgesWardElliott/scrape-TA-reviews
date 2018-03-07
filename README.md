# Scraping TA Hotel Reviews



Four scripts:

1) `scrape-tripadvisor-data.R`

2) `scrape-individual-hotels.R`

3) `extract-hotel-data.R`

3) `scrape-additional-data.R`

The first gathers a list of hotels and the associated links based on the `INPUT-list-of-cities.csv` file. 

The second script loops through the output of the first and downloads the html pages of individual hotel sites. 

The thirds script extracts data from the stored html pages. Fourth is for analyzing and producing results.


# Getting Room Counts
Here are some notes from the process of scraping room counts from TA

Issue: On each TA page, "Number Of Rooms" was typically available within the HTML only after a user had clicked the "See More" button under the "About Tab". Simple `rvest` html parsing would not suffice because the page needed to be interacted with before the HTML would be available. 

Solution: RSelenium (note: seleniumPipes package would have been a better alternative and should be used in the future). Load each page, grammatically click the "See More" button, download the resulting HTML and extract the room count.

An additional issue was that Selenium tended to hang, fall over or generally fail stochastically by virtue of the fact that loading webpages has a number of failure points that are outside your control. The challenge then was to make the script robust enough to fail frequently while still running. 

The solution I came to was to run the scrapping script as an Rscript from within crontab on ubuntu. The following line was added to the crontab file to make the script run every 5 minutes:


## crontab entry

open crontab on Ubuntu
`crontab -e`

add this line to the bottom (make sure there is a newline at the bottom, i.e., hit enter a few times after this line)

`*/5 * * * *     /bin/bash -c "timeout 250 /home/rstudio/scrape-TA-reviews/scrape-additional-data.R"`

The first part with the `*` denotes how often it should run. 5 spaces corresponding to min, hour,  day of month, month, and day of week. Using the `"*/"` syntax implies that crontab should run the script every 5 minutes.

The following command wraps an Rscript in a bash call. Note how absolute paths are necessary, as the crontab assumes everything is being run from the home directory of the user. This is also true of the Rscript itself: hence the `setwd()` command placed near the top of the script. Without `setwd()`, bash assumes the directories (for example, where to write the data) are relative to the home directory. When working in Rstudio Projects, it's easy to forget that bash does not honor the project's home directory. 

Note that there are likely alternatives to using `setwd()` that involve setting the HOME environment variable explicitly. 

## Monitoring crontab job output

Finally, monitoring progress of a cron job is essential. Crontab jobs output message to a mail server by default. Ubuntu does not come with one installed, so installing Postfix helps. Unless you want the output emailed to an actual email address, simply choose "Local Only" when the postfix setup screen comes up after installing. 

Install postfix:
`sudo apt-get update`
`sudo apt-get install postfix`

You can check that the cronjobs are running successfully by examining the syslog:

`tail -n 20 /var/log/syslog`

And once postfix is installed, you can read the output of the cronjobs at the internal mail location for the user:
`cat /var/mail/ubuntu`


An alternative to viewing the output via internal mail would be to pipe the output to a log file explicitly. For example, by modifying the above crontab entry as:


`*/5 * * * *     /bin/bash -c "timeout 250 /home/rstudio/scrape-TA-reviews/scrape-additional-data.R >> your_log_path 2>&1"`

"2>&1" simply means to send both output (1) and error messages (2) to the same place.




# Running in parallel

There is a technique to run Rselenium/seleniumPipes in parallel, although network constrictions may render this pointless.

See here: https://stackoverflow.com/questions/38950958/run-rselenium-in-parallel








