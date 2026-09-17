# Duke Farms Detection Explorer

An R/Shiny app for exploring BirdNET detections — by species, time and location —
built for the Duke Farms PAM workshop.

Unlike the other tools here, this one needs R. It cannot run on GitHub Pages.

## Running it

1. Install [R](https://cran.r-project.org) and, optionally,
   [RStudio](https://posit.co/download/rstudio-desktop/).
2. Install the packages it uses:

   ```r
   install.packages(c("shiny","dplyr","ggplot2","lubridate","readr",
                      "stringr","tidyr","leaflet","DT"))
   ```

3. Open `app.R` in RStudio and press **Run App**, or from an R console:

   ```r
   shiny::runApp("path/to/duke-farms-explorer")
   ```

## Data

The app expects BirdNET output and a site table. Check the top of `app.R` for the
file paths and column names it assumes, and point them at your own data.

## If you want this in the browser instead

The browser tools in this repo cover a different job (validating and labelling).
An HTML version of *this* app — detections by species, site and time, no R
required — would make it shareable by link like the others. Worth doing if you
teach with it more than once a year.
