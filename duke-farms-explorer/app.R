# =============================================================================
# BirdNET Detection Explorer — Duke Farms PAM Workshop
# =============================================================================

library(shiny)
library(dplyr)
library(ggplot2)
library(lubridate)
library(readr)
library(stringr)
library(tidyr)
library(leaflet)
library(vegan)
library(RColorBrewer)

setwd('/Users/blg85/Documents/Cornell/Duke Farms/Ecological_Applications')
# =============================================================================
# DATA LOADING
# =============================================================================

detections_raw  <- read_csv("data/raw_birdnet_detections_june_2025.csv", show_col_types = FALSE)
thresholds_raw  <- read_csv("data/threshold_scores.csv",                  show_col_types = FALSE)
covariates_raw  <- read_csv("data/site_covariates.csv",                   show_col_types = FALSE)
weather_raw     <- read_csv("data/site_weather_june_2025.csv",            show_col_types = FALSE)
traits_raw      <- read_csv("data/species_traits.csv",                    show_col_types = FALSE)
site_coords     <- read_csv("data/site_coords_filt.csv",                   show_col_types = FALSE) %>%
  select(site, latitude, longitude) %>%
  filter(site %in% unique(detections_raw$site))   # only sites with recordings

species_code_map <- tibble(
  thresh_code = c("amwo","bars","bhco","bobo","ccsp","eabl","eame","ewpw",
                  "grsp","gwwa","hofi","hola","hosp","modo","oven","piwo",
                  "puma","rbgr","rnph","savs","sewr","spsa","witu"),
  Common_Name = c("American Woodcock","Barn Swallow","Brown-headed Cowbird",
                  "Bobolink","Clay-colored Sparrow","Eastern Bluebird",
                  "Eastern Meadowlark","Eastern Whip-poor-will",
                  "Grasshopper Sparrow","Golden-winged Warbler","House Finch",
                  "Horned Lark","House Sparrow","Mourning Dove","Ovenbird",
                  "Pileated Woodpecker","Purple Martin","Rose-breasted Grosbeak",
                  "Ring-necked Pheasant","Savannah Sparrow","Sedge Wren",
                  "Spotted Sandpiper","Wild Turkey")
)

thresholds <- thresholds_raw %>%
  rename(thresh_code = species) %>%
  left_join(species_code_map, by = "thresh_code") %>%
  select(Common_Name, thresh_code,
         `85%` = cutoff85.c, `90%` = cutoff90.c,
         `95%` = cutoff95.c, `98%` = cutoff98.c, `99%` = cutoff99.c)

thresh_long <- thresholds %>%
  pivot_longer(c(`85%`,`90%`,`95%`,`98%`,`99%`),
               names_to = "spec_level", values_to = "thresh_val") %>%
  mutate(thresh_val = case_when(
    is.na(thresh_val)  ~ 0.5,
    thresh_val > 1.0   ~ 2.0,
    thresh_val < 0.0   ~ 0.0,
    TRUE               ~ thresh_val
  ))

# Pre-join ALL threshold levels into a wide table for fast per-species lookup
thresh_wide <- thresh_long %>%
  mutate(col = paste0(".t", gsub("%", "", spec_level))) %>%
  select(Common_Name, col, thresh_val) %>%
  pivot_wider(names_from = col, values_from = thresh_val)

site_meta <- covariates_raw %>%
  select(site, Region, management, specific_landuse) %>%
  mutate(habitat_group = case_when(
    str_starts(specific_landuse, "solar") ~ "Solar",
    str_starts(specific_landuse, "bmp")   ~ "BMP Grassland",
    specific_landuse == "hay"             ~ "Hay",
    str_starts(specific_landuse, "row")   ~ "Row Crop",
    TRUE                                  ~ "Other"
  ))

detections <- detections_raw %>%
  mutate(
    date         = mdy(date),
    file_hhmmss  = gsub(".*_(\\d{6}).*", "\\1", source_file),
    file_start_s = as.integer(substr(file_hhmmss, 1, 2)) * 3600L +
      as.integer(substr(file_hhmmss, 3, 4)) * 60L +
      as.integer(substr(file_hhmmss, 5, 6)),
    true_time_s  = file_start_s + `Begin Time (s)`,
    hour         = as.integer(round(true_time_s / 3600)) %% 24L,
    bin10        = as.integer(floor(true_time_s / 600)) %% 144L
  ) %>%
  left_join(site_meta,   by = "site") %>%
  left_join(thresh_wide, by = "Common_Name")   # pre-join thresholds for fast filtering

# Daily weather averaged across all sites
daily_weather <- weather_raw %>%
  mutate(date = as.Date(date)) %>%
  group_by(date) %>%
  summarise(temp_mean_c   = mean(temp_mean_c,   na.rm = TRUE),
            precip_sum_mm = mean(precip_sum_mm, na.rm = TRUE),
            .groups = "drop")

# Traits: recode Migration to readable labels
traits <- traits_raw %>%
  rename(Common_Name = common_name) %>%
  mutate(Migration = case_when(
    Migration == 1 ~ "Sedentary",
    Migration == 2 ~ "Short-distance",
    Migration == 3 ~ "Long-distance",
    TRUE           ~ NA_character_
  )) %>%
  select(Common_Name, Primary_lifestyle, Trophic_niche, Trophic_level,
         Habitat, Migration, PopulationTrend2019)

species_list       <- sort(unique(detections$Common_Name))
habitat_choices    <- sort(unique(detections$habitat_group))
region_choices     <- sort(unique(detections$Region))
spec_level_choices <- c("85%", "90%", "95%", "98%", "99%")

trait_color_choices <- c(
  "None (single color)"  = "none",
  "Species"              = "Common_Name",
  "Primary lifestyle"    = "Primary_lifestyle",
  "Trophic niche"        = "Trophic_niche",
  "Habitat type"         = "Habitat",
  "Population trend"     = "PopulationTrend2019",
  "Migration strategy"   = "Migration"
)

# Rolling mean using base R stats::filter (centered, no extra packages needed)
roll_mean <- function(x, k) {
  as.numeric(stats::filter(x, rep(1 / k, k), sides = 2))
}

hour_labels <- function(h) {
  ifelse(h == 0,  "12 AM",
         ifelse(h < 12,  paste0(h, " AM"),
                ifelse(h == 12, "12 PM",
                       paste0(h - 12, " PM"))))
}

apply_threshold <- function(data, spec_level_choice) {
  # Use pre-joined threshold column — no join needed, ~5x faster
  col <- paste0(".t", gsub("%", "", spec_level_choice))
  data %>%
    filter(Confidence >= coalesce(.data[[col]], 0.5))
}

# =============================================================================
# UI
# =============================================================================

ui <- fluidPage(
  tags$head(tags$style(HTML("
    body { font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;
           background-color: #f8f9fa; }
    .well { background-color: #ffffff; border: 1px solid #dee2e6; }
    h2 { color: #1a3c2e; font-weight: 700; margin-bottom: 4px; }
    .subtitle { color: #555; font-size: 14px; margin-bottom: 20px; }
    .thresh-ok   { background: #eaf4ef; border-left: 4px solid #2d6a4f;
                   padding: 10px 14px; border-radius: 4px; font-size: 13px; margin-top: 10px; }
    .thresh-warn { background: #fff8e1; border-left: 4px solid #f0a500;
                   padding: 10px 14px; border-radius: 4px; font-size: 13px; margin-top: 10px; }
    .info-box    { background: #e8f4fd; border-left: 4px solid #3a86c8;
                   padding: 10px 14px; border-radius: 4px; font-size: 12px; margin-top: 10px; }
    .section-label { font-weight: 600; color: #1a3c2e; margin-top: 16px;
                     margin-bottom: 4px; font-size: 13px; }
    .note { font-size: 12px; color: #666; }
  "))),
  
  div(style = "padding: 16px 24px 0 24px;",
      h2("🎵 BirdNET Detection Explorer"),
      div(class = "subtitle",
          "Duke Farms PAM Workshop · Ecological Applications Module · June 2026")
  ),
  hr(style = "margin: 10px 24px;"),
  
  tabsetPanel(id = "main_tabs",
              
              # =========================================================================
              # TAB 1 — Species Explorer
              # =========================================================================
              tabPanel("Species Explorer", br(),
                       sidebarLayout(
                         sidebarPanel(width = 3,
                                      div(class = "section-label", "Species"),
                                      selectInput("species", label = NULL, choices = species_list, selected = "Bobolink"),
                                      div(class = "section-label", "Confidence threshold (specificity)"),
                                      radioButtons("spec_level", label = NULL,
                                                   choices = spec_level_choices, selected = "90%", inline = TRUE),
                                      uiOutput("threshold_box"),
                                      div(class = "section-label", "Hours of day to include"),
                                      sliderInput("hour_range", label = NULL,
                                                  min = 0, max = 23, value = c(4, 10), step = 1, ticks = FALSE),
                                      div(class = "note", textOutput("hour_label_text")),
                                      
                                      div(class = "section-label", "Compare by"),
                                      radioButtons("sp_group", label = NULL,
                                                   choices = c("None"            = "none",
                                                               "Management type" = "management",
                                                               "Habitat group"   = "habitat_group"),
                                                   selected = "none"),
                                      div(class = "note",
                                          "Overlays a line per group showing relative detection patterns.")
                         ),
                         mainPanel(width = 9,
                                   div(style="text-align:right;margin-bottom:4px;",
                                       downloadButton("dl_diel","💾 Save plot",class="btn btn-sm btn-default")),
                                   plotOutput("diel_plot", height = "420px"),
                                   hr(),
                                   fluidRow(
                                     column(4, div(class = "section-label", "Detection summary"),
                                            tableOutput("summary_table")),
                                     column(8, div(class = "section-label", "Detections by date"),
                                            plotOutput("date_plot", height = "200px"))
                                   )
                         )
                       )
              ),
              
              # =========================================================================
              # TAB 2 — Community Heatmap
              # =========================================================================
              tabPanel("Community Heatmap", br(),
                       sidebarLayout(
                         sidebarPanel(width = 3,
                                      div(class = "section-label", "View"),
                                      radioButtons("heat_view", label = NULL,
                                                   choices  = c("Diel (10-min bins)" = "diel",
                                                                "Phenology (by day)" = "pheno"),
                                                   selected = "diel"),
                                      
                                      div(class = "section-label", "Color scale"),
                                      radioButtons("heat_norm", label = NULL,
                                                   choices  = c("Normalized per species (0–1)" = "norm",
                                                                "Raw counts (log scale)"       = "raw"),
                                                   selected = "norm"),
                                      
                                      div(class = "section-label", "Confidence threshold (specificity)"),
                                      radioButtons("heat_spec", label = NULL,
                                                   choices = spec_level_choices, selected = "85%", inline = TRUE),
                                      
                                      checkboxInput("heat_smooth", "Smooth (rolling average)", value = FALSE),
                                      
                                      conditionalPanel(condition = "input.heat_view == 'diel'",
                                                       div(class = "section-label", "Hour range"),
                                                       sliderInput("heat_hours", label = NULL,
                                                                   min = 0, max = 23, value = c(4, 10), step = 1, ticks = FALSE),
                                                       div(class = "note", textOutput("heat_hour_label"))
                                      ),
                                      
                                      div(class = "section-label", "Species order (y-axis)"),
                                      radioButtons("heat_order", label = NULL,
                                                   choices  = c("Peak detection time" = "peak",
                                                                "Total detections"    = "total",
                                                                "Alphabetical"        = "alpha"),
                                                   selected = "peak"),
                                      
                                      hr(),
                                      div(class = "section-label", "Filter: Habitat type"),
                                      checkboxGroupInput("heat_habitat", label = NULL,
                                                         choices = habitat_choices, selected = habitat_choices),
                                      div(class = "section-label", "Filter: Region"),
                                      checkboxGroupInput("heat_region", label = NULL,
                                                         choices = region_choices, selected = region_choices),
                                      br(),
                                      div(class = "note",
                                          "Species-specific thresholds applied. Values exceeding 1.0 fall back to 0.5.")
                         ),
                         mainPanel(width = 9,
                                   div(style="text-align:right;margin-bottom:4px;",
                                       downloadButton("dl_heatmap","💾 Save plot",class="btn btn-sm btn-default")),
                                   plotOutput("heatmap_plot", height = "640px"),
                                   br(),
                                   div(class = "note", textOutput("heatmap_caption"))
                         )
                       )
              ),
              
              # =========================================================================
              # TAB 3 — Behavioral Associations
              # =========================================================================
              tabPanel("Behavioral Associations", br(),
                       sidebarLayout(
                         sidebarPanel(width = 3,
                                      
                                      div(class = "section-label", "Weather variable (x-axis)"),
                                      radioButtons("wx_var", label = NULL,
                                                   choices  = c("Daily mean temperature (°C)" = "temp_mean_c",
                                                                "Daily precipitation (mm)"    = "precip_sum_mm"),
                                                   selected = "temp_mean_c"),
                                      
                                      div(class = "section-label", "Y-axis scale"),
                                      radioButtons("wx_yscale", label = NULL,
                                                   choices  = c("Raw count"   = "raw",
                                                                "Log scale"   = "log"),
                                                   selected = "raw"),
                                      
                                      div(class = "section-label", "Color points by"),
                                      selectInput("wx_color", label = NULL,
                                                  choices  = trait_color_choices,
                                                  selected = "Primary_lifestyle"),
                                      
                                      checkboxInput("wx_zeros", "Include zero-detection days", value = FALSE),
                                      checkboxInput("wx_jitter", "Jitter points on x-axis", value = TRUE),
                                      
                                      div(class = "section-label", "Trend line"),
                                      radioButtons("wx_smooth", label = NULL,
                                                   choices = c("GAM"   = "gam",
                                                               "LOESS" = "loess",
                                                               "None"  = "none"),
                                                   selected = "gam", inline = TRUE),
                                      
                                      div(class = "section-label", "Confidence threshold (specificity)"),
                                      radioButtons("wx_spec", label = NULL,
                                                   choices = spec_level_choices, selected = "85%", inline = TRUE),
                                      
                                      div(class = "section-label", "Filter species"),
                                      fluidRow(
                                        column(6, actionButton("wx_select_all", "Select all",
                                                               class="btn btn-xs btn-default", style="width:100%;font-size:11px;")),
                                        column(6, actionButton("wx_clear_all",  "Clear",
                                                               class="btn btn-xs btn-default", style="width:100%;font-size:11px;"))
                                      ),
                                      br(),
                                      selectizeInput("wx_species", label = NULL,
                                                     choices  = species_list,
                                                     selected = species_list,
                                                     multiple = TRUE,
                                                     options  = list(placeholder = "Select species...",
                                                                     plugins = list("remove_button"))),
                                      
                                      br(),
                                      div(class = "info-box",
                                          "⚠️ ", tags$b("Interpretation note."),
                                          " Temperature and day-of-season are correlated in this dataset
               (early June was colder). Apparent temperature effects may partly
               reflect seasonal phenology rather than direct behavioral responses
               to weather. Precipitation values are daily totals at each site.")
                         ),
                         mainPanel(width = 9,
                                   div(style="text-align:right;margin-bottom:4px;",
                                       downloadButton("dl_wx","💾 Save plot",class="btn btn-sm btn-default")),
                                   plotOutput("wx_plot", height = "500px"),
                                   br(),
                                   div(class = "note", textOutput("wx_caption")),
                                   br(),
                                   div(
                                     checkboxInput("wx_show_weather", "Show site × date weather context", value = FALSE),
                                     conditionalPanel(
                                       condition = "input.wx_show_weather",
                                       plotOutput("wx_weather_plot", height = "520px"),
                                       div(class = "note",
                                           "Each row = one site, each column = one day. Sites sorted by region then habitat.
                   Useful for understanding the environmental landscape your detections are drawn from.")
                                     )
                                   )
                         )
                       )
              )
              ,
              
              # =========================================================================
              # TAB 4 — Species Map
              # =========================================================================
              tabPanel("Species Map", br(),
                       sidebarLayout(
                         sidebarPanel(width = 3,
                                      
                                      div(class = "section-label", "Species"),
                                      selectInput("map_species", label = NULL,
                                                  choices = species_list, selected = "Bobolink"),
                                      
                                      div(class = "section-label", "Confidence threshold (specificity)"),
                                      radioButtons("map_spec", label = NULL,
                                                   choices = spec_level_choices, selected = "85%", inline = TRUE),
                                      
                                      div(class = "section-label", "Time period"),
                                      radioButtons("map_mode", label = NULL,
                                                   choices = c("All days (total)" = "total",
                                                               "Single day"       = "day"),
                                                   selected = "total"),
                                      
                                      conditionalPanel(
                                        condition = "input.map_mode == 'day'",
                                        sliderInput("map_date_idx", label = NULL,
                                                    min = 1, max = 30, value = 1, step = 1, ticks = FALSE,
                                                    animate = animationOptions(interval = 350, loop = TRUE)),
                                        div(class = "note", textOutput("map_date_label"))
                                      ),
                                      
                                      br(),
                                      div(class = "note",
                                          "Fill color = detection count (darker = more detections, log scale).
               Border color = habitat type.
               Grey circles = no detections at that site.")
                         ),
                         mainPanel(width = 9,
                                   leafletOutput("species_map", height = "580px"),
                                   br(),
                                   div(class = "note", textOutput("map_caption"))
                         )
                       )
              ),
              
              # =========================================================================
              # TAB 5 — Community Composition (NMDS)
              # =========================================================================
              tabPanel("Community Composition", br(),
                       sidebarLayout(
                         sidebarPanel(width = 3,
                                      
                                      div(class = "section-label", "Color sites by"),
                                      radioButtons("nmds_color", label = NULL,
                                                   choices = c("Management type" = "management",
                                                               "Region"          = "Region",
                                                               "Habitat group"   = "habitat_group"),
                                                   selected = "management"),
                                      
                                      div(class = "section-label", "Overlay species vectors"),
                                      checkboxInput("nmds_vectors", "Show species vectors", value = TRUE),
                                      
                                      div(class = "section-label", "Overlay habitat vectors"),
                                      checkboxInput("nmds_habitat", "Show habitat vectors", value = FALSE),
                                      
                                      div(class = "section-label", "Show group ellipses"),
                                      checkboxInput("nmds_ellipse", "95% confidence ellipses", value = TRUE),
                                      
                                      div(class = "section-label", "Confidence threshold (specificity)"),
                                      radioButtons("nmds_spec", label = NULL,
                                                   choices = spec_level_choices, selected = "85%", inline = TRUE),
                                      
                                      br(),
                                      div(class = "note",
                                          "NMDS on Bray-Curtis dissimilarity using total detections per species per site.
               Only sites with at least 1 detection included.
               PERMANOVA p-value shown in subtitle.")
                         ),
                         mainPanel(width = 9,
                                   div(style="text-align:right;margin-bottom:4px;",
                                       downloadButton("dl_nmds","💾 Save plot",class="btn btn-sm btn-default")),
                                   plotOutput("nmds_plot", height = "580px"),
                                   br(),
                                   div(class = "note", textOutput("nmds_caption"))
                         )
                       )
              ),
              
              # =========================================================================
              # TAB 6 — Singing Windows
              # =========================================================================
              tabPanel("Singing Windows", br(),
                       sidebarLayout(
                         sidebarPanel(width = 3,
                                      div(class = "section-label", "Confidence threshold (specificity)"),
                                      radioButtons("sw_spec", label = NULL,
                                                   choices = spec_level_choices, selected = "85%", inline = TRUE),
                                      div(class = "section-label", "Hour range to consider"),
                                      sliderInput("sw_hours", label = NULL,
                                                  min = 0, max = 23, value = c(4, 10), step = 1, ticks = FALSE),
                                      div(class = "note", "Only detections within this window are used."),
                                      br(),
                                      div(class = "section-label", "Minimum detections per species"),
                                      sliderInput("sw_min_n", label = NULL,
                                                  min = 5, max = 100, value = 20, step = 5, ticks = FALSE),
                                      div(class = "note", "Species with fewer detections are excluded (unreliable percentiles)."),
                                      br(),
                                      div(class = "section-label", "Color by"),
                                      radioButtons("sw_color", label = NULL,
                                                   choices = c("Total detections"   = "n_det",
                                                               "Window width (hrs)" = "window"),
                                                   selected = "window"),
                                      br(),
                                      div(class = "note",
                                          "Bar spans 10th–90th percentile of detection time.
               Dot = median. Sorted by earliest onset (10th percentile).
               Narrower bars = more temporally concentrated singing.")
                         ),
                         mainPanel(width = 9,
                                   div(style="text-align:right;margin-bottom:4px;",
                                       downloadButton("dl_sw", "💾 Save plot", class="btn btn-sm btn-default")),
                                   plotOutput("sw_plot", height = "580px"),
                                   br(),
                                   div(class = "note", textOutput("sw_caption"))
                         )
                       )
              ),
              
              # =========================================================================
              # TAB 7 — Habitat Effects
              # =========================================================================
              tabPanel("Habitat Effects", br(),
                       sidebarLayout(
                         sidebarPanel(width = 3,
                                      div(class = "section-label", "View"),
                                      radioButtons("hab_view", label = NULL,
                                                   choices = c("Occupancy heatmap (all species)"  = "occ",
                                                               "Detection rate (single species)"   = "rate",
                                                               "Rank abundance by habitat"         = "rank"),
                                                   selected = "occ"),
                                      div(class = "section-label", "Group sites by"),
                                      radioButtons("hab_group", label = NULL,
                                                   choices = c("Management type" = "management",
                                                               "Habitat group"   = "habitat_group"),
                                                   selected = "management"),
                                      conditionalPanel(
                                        condition = "input.hab_view == 'occ'",
                                        div(class = "section-label", "Color = "),
                                        radioButtons("hab_metric", label = NULL,
                                                     choices = c("% sites occupied"            = "pct_occ",
                                                                 "Mean detections / site-day"  = "det_rate"),
                                                     selected = "pct_occ"),
                                        div(class = "section-label", "Species order (y-axis)"),
                                        radioButtons("hab_order", label = NULL,
                                                     choices = c("Overall occupancy" = "occ",
                                                                 "Alphabetical"      = "alpha"),
                                                     selected = "occ")
                                      ),
                                      conditionalPanel(
                                        condition = "input.hab_view == 'rate'",
                                        div(class = "section-label", "Species"),
                                        selectInput("hab_species", label = NULL,
                                                    choices = species_list, selected = "Bobolink")
                                      ),
                                      conditionalPanel(
                                        condition = "input.hab_view == 'rank'",
                                        div(class = "section-label", "Show top N species"),
                                        sliderInput("hab_top_n", label = NULL,
                                                    min = 3, max = 20, value = 10, step = 1, ticks = FALSE),
                                        div(class = "section-label", "Plot type"),
                                        radioButtons("hab_rank_type", label = NULL,
                                                     choices = c("Bar chart (top N per habitat)"  = "bar",
                                                                 "Rank abundance curves"          = "curve"),
                                                     selected = "bar"),
                                        div(class = "note",
                                            "Bar: detection rate of top N species per habitat.
                 Curve: all species ranked by abundance — slope shows dominance, width shows richness.")
                                      ),
                                      div(class = "section-label", "Confidence threshold (specificity)"),
                                      radioButtons("hab_spec", label = NULL,
                                                   choices = spec_level_choices, selected = "85%", inline = TRUE),
                                      br(),
                                      div(class = "note",
                                          "Occupancy = ≥ 1 detection at a site during June 2025.
               Detection rate = total detections ÷ active site-days.
               Error bars show 95% bootstrap CI (1,000 resamples).")
                         ),
                         mainPanel(width = 9,
                                   div(style="text-align:right;margin-bottom:4px;",
                                       downloadButton("dl_hab", "💾 Save plot", class="btn btn-sm btn-default")),
                                   plotOutput("hab_plot", height = "580px"),
                                   br(),
                                   div(class = "note", textOutput("hab_caption"))
                         )
                       )
              ),
              
              # =========================================================================
              
  )
)

# =============================================================================
# SERVER
# =============================================================================

server <- function(input, output, session) {
  
  # ---------------------------------------------------------------------------
  # TAB 1 — Species Explorer
  # ---------------------------------------------------------------------------
  
  species_threshold <- reactive({
    row <- thresholds %>% filter(Common_Name == input$species)
    if (nrow(row) == 0) return(list(value = 0.5, valid = TRUE, note = ""))
    val <- row[[input$spec_level]][1]
    if (is.na(val) || val > 1)
      list(value = 0.5, valid = FALSE,
           note  = paste0(input$spec_level, " specificity unreachable — using 0.5"))
    else
      list(value = val, valid = TRUE, note = "")
  })
  
  output$threshold_box <- renderUI({
    t <- species_threshold()
    div(class = if (t$valid) "thresh-ok" else "thresh-warn",
        if (t$valid) paste0("Threshold: ", round(t$value, 3), " (", input$spec_level, " specificity)")
        else         paste0("⚠️ ", t$note))
  })
  
  output$hour_label_text <- renderText({
    paste0(hour_labels(input$hour_range[1]), " – ", hour_labels(input$hour_range[2]))
  })
  
  filtered_data <- reactive({
    thresh <- species_threshold()$value
    detections %>%
      filter(Common_Name == input$species,
             Confidence  >= thresh,
             hour >= input$hour_range[1], hour <= input$hour_range[2])
  })
  
  # Reactive plot object — shared between renderPlot and downloadHandler
  diel_plot_obj <- reactive({
    df <- filtered_data(); thresh <- species_threshold()$value; hr <- input$hour_range
    grp <- input$sp_group
    
    if (grp == "none") {
      hour_counts <- df %>% count(hour) %>%
        right_join(tibble(hour = hr[1]:hr[2]), by = "hour") %>%
        mutate(n = replace_na(n, 0L))
      
      p <- ggplot(hour_counts, aes(x = hour, y = n)) +
        annotate("rect", xmin=hr[1]-0.5, xmax=min(3.5,hr[2]+0.5), ymin=-Inf,ymax=Inf,fill="#f5c842",alpha=0.12) +
        annotate("rect", xmin=max(10.5,hr[1]-0.5), xmax=hr[2]+0.5, ymin=-Inf,ymax=Inf,fill="#f5c842",alpha=0.12) +
        geom_col(fill="#2d6a4f", color="white", width=0.85, alpha=0.9) +
        scale_y_continuous(labels=scales::comma, expand=expansion(mult=c(0,0.05)))
      
    } else {
      # One line per group, normalized to each group's peak for comparability
      hour_counts <- df %>%
        count(.data[[grp]], hour) %>%
        group_by(.data[[grp]]) %>%
        mutate(prop = n / max(n, na.rm=TRUE)) %>% ungroup() %>%
        complete(!!sym(grp) := unique(df[[grp]]),
                 hour = hr[1]:hr[2], fill = list(prop = 0))
      
      p <- ggplot(hour_counts, aes(x=hour, y=prop,
                                   color=.data[[grp]], group=.data[[grp]])) +
        annotate("rect", xmin=hr[1]-0.5, xmax=min(3.5,hr[2]+0.5), ymin=-Inf,ymax=Inf,fill="#f5c842",alpha=0.08) +
        annotate("rect", xmin=max(10.5,hr[1]-0.5), xmax=hr[2]+0.5, ymin=-Inf,ymax=Inf,fill="#f5c842",alpha=0.08) +
        geom_line(linewidth=1.2, alpha=0.9) +
        geom_point(size=2.2, alpha=0.8) +
        scale_color_brewer(palette="Set2",
                           name=if(grp=="management") "Management" else "Habitat") +
        scale_y_continuous(labels=scales::percent, expand=expansion(mult=c(0,0.05)))
    }
    
    p +
      scale_x_continuous(breaks=hr[1]:hr[2], labels=hour_labels(hr[1]:hr[2])) +
      labs(title = paste("Diel activity pattern:", input$species),
           subtitle = paste0("Confidence ≥ ", round(thresh,3), " (", input$spec_level,
                             " specificity)  ·  ", scales::comma(nrow(df)), " detections  ·  June 2025",
                             if (grp != "none") paste0("  ·  by ", grp) else ""),
           x = "Hour of day",
           y = if (grp=="none") "Number of detections" else "Relative activity (% of group peak)",
           caption = "Yellow shading = reduced sampling effort (5 min/hr outside 4–10 AM)") +
      theme_minimal(base_size=14) +
      theme(plot.title=element_text(face="bold",color="#1a3c2e"),
            plot.subtitle=element_text(color="#555555",size=12),
            axis.text.x=element_text(angle=45,hjust=1),
            panel.grid.major.x=element_blank(), panel.grid.minor=element_blank())
  })
  
  output$diel_plot <- renderPlot({ diel_plot_obj() })
  
  output$date_plot <- renderPlot({
    df <- filtered_data()
    df %>% count(date) %>%
      complete(date=seq(min(detections$date), max(detections$date), by="day"), fill=list(n=0L)) %>%
      ggplot(aes(x=date, y=n)) +
      geom_col(fill="#52b788", alpha=0.85) +
      scale_x_date(date_labels="%b %d", date_breaks="1 week") +
      scale_y_continuous(labels=scales::comma, expand=expansion(mult=c(0,0.05))) +
      labs(x=NULL, y="Detections") +
      theme_minimal(base_size=11) +
      theme(axis.text.x=element_text(angle=30,hjust=1), panel.grid.minor=element_blank())
  })
  
  output$summary_table <- renderTable({
    df <- filtered_data()
    if (nrow(df)==0) return(data.frame(Metric="No detections", Value="—"))
    df %>%
      summarise(`Total detections`=as.character(n()),
                `Sites detected`  =as.character(n_distinct(site)),
                `Days detected`   =as.character(n_distinct(date)),
                `Mean confidence` =as.character(round(mean(Confidence),3)),
                `Peak hour`       =hour_labels(as.integer(names(which.max(table(hour)))))) %>%
      pivot_longer(everything(), names_to="Metric", values_to="Value")
  }, striped=TRUE, hover=TRUE, bordered=FALSE, width="100%")
  
  # ---------------------------------------------------------------------------
  # TAB 2 — Community Heatmap
  # ---------------------------------------------------------------------------
  
  output$heat_hour_label <- renderText({
    paste0(hour_labels(input$heat_hours[1]), " – ", hour_labels(input$heat_hours[2]))
  })
  
  heat_data <- reactive({
    df <- apply_threshold(detections, input$heat_spec) %>%
      filter(habitat_group %in% input$heat_habitat,
             Region        %in% input$heat_region)
    if (nrow(df) == 0) return(NULL)
    
    # Per-species total detections (used for alpha in normalized view)
    sp_totals <- df %>% count(Common_Name, name = "sp_total")
    
    if (input$heat_view == "diel") {
      hr <- input$heat_hours
      df <- df %>% filter(hour >= hr[1], hour <= hr[2])
      all_bins <- (hr[1]*6L):(min(hr[2]*6L+5L, 143L))
      
      agg <- df %>% count(Common_Name, bin10) %>%
        complete(Common_Name=species_list, bin10=all_bins, fill=list(n=0L))
      
      # Normalize per species — join approach (safe with factors)
      if (input$heat_norm == "norm") {
        sp_max <- agg %>% group_by(Common_Name) %>%
          summarise(sp_max=max(n, na.rm=TRUE), .groups="drop")
        agg <- agg %>% left_join(sp_max, by="Common_Name") %>%
          mutate(n=if_else(sp_max>0, as.double(n)/sp_max, 0)) %>% select(-sp_max)
      }
      
      # Optional rolling average (k=4 bins = 40 minutes)
      if (input$heat_smooth) {
        agg <- agg %>% group_by(Common_Name) %>% arrange(bin10) %>%
          mutate(n=roll_mean(n, k=4)) %>% ungroup()
      }
      
      order_vec <- switch(input$heat_order,
                          peak  = { agg %>% group_by(Common_Name) %>%
                              summarise(pk=bin10[which.max(replace_na(n,0))], .groups="drop") %>%
                              arrange(pk) %>% pull(Common_Name) },
                          total = { agg %>% group_by(Common_Name) %>%
                              summarise(tot=sum(n,na.rm=TRUE), .groups="drop") %>%
                              arrange(desc(tot)) %>% pull(Common_Name) },
                          alpha = sort(species_list)
      )
      
      agg %>%
        left_join(sp_totals, by="Common_Name") %>%
        mutate(Common_Name=factor(Common_Name, levels=rev(order_vec)),
               x_val=bin10,
               x_label=sprintf("%02d:%02d", bin10%/%6L, (bin10%%6L)*10L))
      
    } else {
      all_dates <- seq(min(detections$date), max(detections$date), by="day")
      
      agg <- df %>% count(Common_Name, date) %>%
        complete(Common_Name=species_list, date=all_dates, fill=list(n=0L))
      
      if (input$heat_norm == "norm") {
        sp_max <- agg %>% group_by(Common_Name) %>%
          summarise(sp_max=max(n, na.rm=TRUE), .groups="drop")
        agg <- agg %>% left_join(sp_max, by="Common_Name") %>%
          mutate(n=if_else(sp_max>0, as.double(n)/sp_max, 0)) %>% select(-sp_max)
      }
      
      # Optional rolling average (k=3 days)
      if (input$heat_smooth) {
        agg <- agg %>% group_by(Common_Name) %>% arrange(date) %>%
          mutate(n=roll_mean(n, k=3)) %>% ungroup()
      }
      
      order_vec <- switch(input$heat_order,
                          peak  = { agg %>% group_by(Common_Name) %>%
                              summarise(pk=as.numeric(date)[which.max(replace_na(n,0))], .groups="drop") %>%
                              arrange(pk) %>% pull(Common_Name) },
                          total = { agg %>% group_by(Common_Name) %>%
                              summarise(tot=sum(n,na.rm=TRUE), .groups="drop") %>%
                              arrange(desc(tot)) %>% pull(Common_Name) },
                          alpha = sort(species_list)
      )
      
      agg %>%
        left_join(sp_totals, by="Common_Name") %>%
        mutate(Common_Name=factor(Common_Name, levels=rev(order_vec)),
               x_val=as.numeric(date),
               x_label=format(date, "%b %d"))
    }
  })
  
  output$heatmap_plot <- renderPlot({
    agg <- heat_data()
    if (is.null(agg)) {
      return(ggplot() + annotate("text",x=0.5,y=0.5,label="No data — check filters",
                                 size=6,color="grey50") + theme_void())
    }
    
    norm <- input$heat_norm == "norm"
    view <- input$heat_view
    
    if (view == "diel") {
      hr <- input$heat_hours
      hour_bins <- seq(hr[1]*6L, hr[2]*6L, by=6L)
      x_breaks <- hour_bins; x_labels <- hour_labels(hour_bins%/%6L)
    } else {
      all_x <- sort(unique(agg$x_val))
      x_breaks <- all_x[seq(1,length(all_x),by=7)]
      x_labels <- format(as.Date(x_breaks, origin="1970-01-01"), "%b %d")
    }
    
    # Alpha: in normalized view, scale by log(total detections) so species
    # with very few total detections (e.g. Golden-winged Warbler, n=4) remain
    # visually faint even at their "peak" — preventing false-prominence artifacts.
    if (norm && "sp_total" %in% names(agg)) {
      agg <- agg %>%
        mutate(alpha_val = scales::rescale(log1p(replace_na(sp_total, 0)),
                                           to = c(0.15, 1.0),
                                           from = c(0, log1p(max(sp_total, na.rm=TRUE)))))
    } else {
      agg <- agg %>% mutate(alpha_val = 1.0)
    }
    
    # For raw view: pre-transform n → log1p so we can use a LINEAR scale
    # with explicit break labels showing original counts.
    # This avoids scale_fill_gradient(trans=) which clips colors unreliably.
    if (!norm) {
      raw_max    <- max(agg$n, na.rm = TRUE)
      raw_breaks <- if (raw_max <= 10)    c(0, 1, 3, 7, raw_max)
      else if (raw_max <= 100)   c(0, 5, 20, 50, raw_max)
      else if (raw_max <= 1000)  c(0, 25, 100, 400, raw_max)
      else if (raw_max <= 10000) c(0, 100, 500, 2000, raw_max)
      else                       c(0, 500, 2000, 10000, raw_max)
      raw_breaks <- unique(as.integer(raw_breaks))
      agg <- agg %>% mutate(fill_val = log1p(replace_na(n, 0)))
      fill_max <- log1p(raw_max)
    } else {
      agg <- agg %>% mutate(fill_val = n)
    }
    
    p <- ggplot(agg, aes(x=x_val, y=Common_Name, fill=fill_val, alpha=alpha_val)) +
      geom_tile(color="white", linewidth=0.25) +
      guides(alpha="none") +
      scale_x_continuous(breaks=x_breaks, labels=x_labels, expand=expansion(0)) +
      scale_y_discrete(expand=expansion(0)) +
      labs(title = if (view=="diel") "Community diel activity (10-min bins)"
           else "Community phenology (daily detections)",
           subtitle = paste0(input$heat_spec, " specificity  ·  ",
                             paste(input$heat_habitat, collapse=", "), "  ·  ",
                             paste(input$heat_region, collapse=", "),
                             if (input$heat_smooth) "  ·  smoothed" else ""),
           x = if (view=="diel") "Time of day" else NULL,
           y = NULL) +
      theme_minimal(base_size=13) +
      theme(plot.title=element_text(face="bold",color="#1a3c2e",size=15),
            plot.subtitle=element_text(color="#555555",size=10),
            axis.text.x=element_text(angle=45,hjust=1,size=10),
            axis.text.y=element_text(size=11),
            panel.grid=element_blank(),
            legend.position="right",
            legend.key.height=unit(1.4,"cm"))
    
    if (norm) {
      p <- p + scale_fill_gradient(low="#f0f9f0", high="#1b4332",
                                   name="Relative\nactivity",
                                   limits=c(0,1), labels=scales::percent,
                                   na.value="grey92")
    } else {
      # Linear scale on pre-transformed (log1p) fill values.
      # Breaks at log1p-transformed positions, labelled with original counts.
      # Using viridis "magma" for strong visual contrast across the full range.
      p <- p + scale_fill_viridis_c(
        name   = paste0("Detections\n(max=", scales::comma(raw_max), ")"),
        option = "magma", direction = -1,   # dark=many, light=few
        limits = c(0, fill_max),
        breaks = log1p(raw_breaks),
        labels = scales::comma(raw_breaks),
        na.value = "grey92"
      )
    }
    p
  })
  
  output$heatmap_caption <- renderText({
    agg <- heat_data(); if (is.null(agg)) return("")
    norm <- input$heat_norm == "norm"
    paste0(
      if (norm)
        "Each row independently normalized: 100% = that species' peak. Opacity reflects total detections — faded rows (e.g. Golden-winged Warbler, n=4) have few total detections and should be interpreted cautiously. "
      else
        "Log scale: compresses dominant species so rarer ones are visible. Legend shows raw detection counts. ",
      "Showing ", nrow(agg), " species–",
      if (input$heat_view=="diel") "bin" else "day", " combinations."
    )
  })
  
  # ---------------------------------------------------------------------------
  # TAB 3 — Behavioral Associations
  # ---------------------------------------------------------------------------
  
  # Select-all / clear buttons for species filter
  observeEvent(input$wx_select_all, {
    updateSelectizeInput(session, "wx_species", selected = species_list)
  })
  observeEvent(input$wx_clear_all, {
    updateSelectizeInput(session, "wx_species", selected = character(0))
  })
  
  wx_data <- reactive({
    # Guard: selectizeInput can be NULL before first render or after "Clear"
    selected_sp <- input$wx_species
    if (is.null(selected_sp) || length(selected_sp) == 0) return(NULL)
    
    # Active site-dates: any date where that site had recordings
    active <- detections %>% distinct(site, date)
    
    # Species-filtered detections above threshold
    df_thresh <- apply_threshold(detections, input$wx_spec) %>%
      filter(Common_Name %in% selected_sp)
    
    site_weather <- weather_raw %>%
      mutate(date = as.Date(date)) %>%
      select(site, date, temp_mean_c, precip_sum_mm)
    
    # Non-zero detection counts per species × site × date
    sp_counts <- df_thresh %>%
      count(Common_Name, site, date, name = "n_detections")
    
    # Complete grid: ALL active site-days × selected species (zeros included)
    full_grid <- crossing(
      Common_Name = selected_sp,
      active
    ) %>%
      left_join(sp_counts, by = c("Common_Name", "site", "date")) %>%
      mutate(n_detections = replace_na(n_detections, 0L)) %>%
      left_join(site_weather, by = c("site", "date")) %>%
      left_join(traits, by = "Common_Name") %>%
      filter(!is.na(temp_mean_c))
    
    if (nrow(full_grid) == 0) return(NULL)
    full_grid
  })
  
  output$wx_plot <- renderPlot({
    df <- wx_data()
    if (is.null(df) || nrow(df) == 0) {
      return(ggplot() + annotate("text",x=0.5,y=0.5,
                                 label="No data — check filters",size=6,color="grey50") + theme_void())
    }
    
    # Optionally hide zero-detection days
    if (!input$wx_zeros) df <- df %>% filter(n_detections > 0)
    if (nrow(df) == 0) {
      return(ggplot() + annotate("text",x=0.5,y=0.5,
                                 label="No detections pass filters",size=6,color="grey50") + theme_void())
    }
    
    x_var     <- input$wx_var
    color_var <- input$wx_color
    x_label   <- if (x_var=="temp_mean_c") "Daily mean temperature (°C)"
    else "Daily precipitation (mm)"
    
    # Jitter amount: small relative to axis range
    jitter_w <- if (input$wx_jitter) {
      if (x_var=="temp_mean_c") 0.25 else 0.15
    } else 0
    
    use_color <- color_var != "none"
    if (use_color) {
      df <- df %>% mutate(color_group = as.character(.data[[color_var]]))
      n_groups   <- n_distinct(df$color_group, na.rm=TRUE)
      color_name <- names(trait_color_choices)[trait_color_choices == color_var]
      fill_scale <- if (color_var == "Common_Name" || n_groups > 8)
        scale_color_viridis_d(name=color_name, option="turbo", na.value="grey70")
      else
        scale_color_brewer(name=color_name, palette="Set2", na.value="grey70")
    }
    
    pt_pos <- position_jitter(width=jitter_w, height=0, seed=42)
    
    p <- if (use_color) {
      ggplot(df, aes(x=.data[[x_var]], y=n_detections, color=color_group)) +
        geom_point(alpha=0.35, size=1.8, position=pt_pos) + fill_scale
    } else {
      ggplot(df, aes(x=.data[[x_var]], y=n_detections)) +
        geom_point(alpha=0.35, size=1.8, color="#2d6a4f", position=pt_pos)
    }
    
    # Trend line
    smooth_method <- input$wx_smooth
    if (smooth_method != "none") {
      m      <- smooth_method   # "gam" or "loess"
      f      <- if (m=="gam") y~s(x, k=6) else y~x
      sm_col <- "#1b4332"
      if (use_color) {
        p <- p + geom_smooth(aes(group=color_group), method=m, formula=f,
                             se=TRUE, alpha=0.12, linewidth=0.9, show.legend=FALSE)
      } else {
        p <- p + geom_smooth(method=m, formula=f, se=TRUE,
                             alpha=0.12, linewidth=1, color=sm_col, show.legend=FALSE)
      }
    }
    
    p <- p +
      scale_y_continuous(
        trans  = if (input$wx_yscale=="log") "log1p" else "identity",
        labels = scales::comma,
        expand = expansion(mult=c(0.02,0.05))
      ) +
      labs(title    = paste("Vocal detections vs.", tolower(x_label)),
           subtitle = paste0(input$wx_spec, " specificity  ·  ",
                             n_distinct(df$Common_Name), " species  ·  ",
                             if (!input$wx_zeros) "non-zero days only" else "all active days"),
           x = x_label,
           y = paste0("Detections per site per day",
                      if (input$wx_yscale=="log") " (log scale)" else "")) +
      theme_minimal(base_size=14) +
      theme(plot.title    = element_text(face="bold", color="#1a3c2e"),
            plot.subtitle = element_text(color="#555555", size=11),
            panel.grid.minor = element_blank(),
            legend.position  = "right")
    
    # Sqrt transform on x-axis for precipitation (many zeros, long right tail)
    if (x_var == "precip_sum_mm") {
      p <- p + scale_x_continuous(
        trans  = "sqrt",
        breaks = c(0, 1, 3, 7, 15, 25, 40),
        labels = scales::comma
      )
    }
    
    p   # explicit return of the ggplot object
  })  # end output$wx_plot renderPlot
  
  output$wx_caption <- renderText({
    df <- wx_data(); if (is.null(df)) return("")
    df_plot <- if (!isTRUE(input$wx_zeros)) df %>% filter(n_detections > 0) else df
    paste0(
      n_distinct(df_plot$Common_Name), " species · ",
      n_distinct(df_plot$site), " sites · ",
      n_distinct(df_plot$date), " days · ",
      nrow(df_plot), " observations",
      if (!isTRUE(input$wx_zeros)) " (zero-detection days hidden)" else " (zeros included)",
      ". Temperature and date are correlated — early June was cooler."
    )
  })
  
  # -------------------------------------------------------------------------
  # TAB 3 — Weather context matrix (site × date)
  # -------------------------------------------------------------------------
  
  output$wx_weather_plot <- renderPlot({
    x_var   <- input$wx_var
    x_label <- if (x_var=="temp_mean_c") "Mean temperature (°C)"
    else "Total precipitation (mm)"
    
    wx <- weather_raw %>%
      mutate(date = as.Date(date)) %>%
      left_join(site_meta %>% select(site, Region, habitat_group), by="site") %>%
      arrange(Region, habitat_group, site) %>%
      mutate(site = factor(site, levels=unique(site)))
    
    fill_scale <- if (x_var == "temp_mean_c")
      scale_fill_gradient2(low="#4575b4", mid="#ffffbf", high="#d73027",
                           midpoint=18, name=x_label, na.value="grey85")
    else
      scale_fill_gradient(low="#f7fbff", high="#08519c",
                          name=x_label, na.value="grey85", trans="sqrt")
    
    ggplot(wx, aes(x=date, y=site, fill=.data[[x_var]])) +
      geom_tile(color="white", linewidth=0.15) +
      facet_grid(Region ~ ., scales="free_y", space="free_y") +
      scale_x_date(date_labels="%b %d", date_breaks="1 week", expand=expansion(0)) +
      scale_y_discrete(expand=expansion(0)) +
      fill_scale +
      labs(title=paste("Site × date weather:", x_label), x=NULL, y=NULL) +
      theme_minimal(base_size=10) +
      theme(plot.title   = element_text(face="bold", color="#1a3c2e", size=13),
            axis.text.y  = element_text(size=7),
            axis.text.x  = element_text(angle=30, hjust=1),
            strip.text.y = element_text(angle=0, face="bold", size=9),
            panel.grid   = element_blank(),
            legend.position = "right")
  })
  
  
  # ---------------------------------------------------------------------------
  # TAB 4 — Species Map
  # ---------------------------------------------------------------------------
  
  all_dates_map <- reactive({ sort(unique(detections$date)) })
  
  output$map_date_label <- renderText({
    dates <- all_dates_map()
    if (!is.null(input$map_date_idx) && input$map_date_idx <= length(dates))
      format(dates[input$map_date_idx], "%B %d, %Y")
    else ""
  })
  
  # Pre-compute fixed color scale per species/threshold —
  # locked to the maximum single-site single-day count so the palette
  # stays constant across all 30 days of animation.
  map_scale_max <- reactive({
    sp <- apply_threshold(detections, input$map_spec) %>%
      filter(Common_Name == input$map_species)
    
    day_max <- sp %>%
      count(site, date, name = "n") %>%
      pull(n) %>% max(1L)
    
    total_max <- sp %>%
      count(site, name = "n") %>%
      pull(n) %>% max(1L)
    
    list(day = day_max, total = total_max)
  })
  
  output$species_map <- renderLeaflet({
    leaflet() %>%
      addProviderTiles(providers$Esri.WorldImagery) %>%
      addProviderTiles(providers$CartoDB.PositronOnlyLabels) %>%
      setView(lng = mean(site_coords$longitude),
              lat = mean(site_coords$latitude), zoom = 12)
  })
  
  observe({
    sp_thresh <- apply_threshold(detections, input$map_spec) %>%
      filter(Common_Name == input$map_species)
    
    scale <- map_scale_max()
    
    if (input$map_mode == "total") {
      counts       <- sp_thresh %>% count(site, name = "n_det")
      period_label <- "June 2025 (all days)"
      scale_max    <- scale$total
    } else {
      dates <- all_dates_map()
      if (is.null(input$map_date_idx) || input$map_date_idx > length(dates)) return()
      sel_date     <- dates[input$map_date_idx]
      counts       <- sp_thresh %>% filter(date == sel_date) %>% count(site, name = "n_det")
      period_label <- format(sel_date, "%B %d, %Y")
      scale_max    <- scale$day   # fixed to species max — constant during animation
    }
    
    map_df <- site_coords %>%
      left_join(site_meta %>% select(site, habitat_group), by = "site") %>%
      left_join(counts, by = "site") %>%
      mutate(n_det = replace_na(n_det, 0L))
    
    # Continuous pale-yellow → deep-red palette on log1p scale (grey = 0)
    det_pal <- colorNumeric(
      palette  = c("#ffffcc","#fecc5c","#fd8d3c","#f03b20","#bd0026"),
      domain   = c(0, log1p(scale_max)),
      na.color = "#cccccc"
    )
    
    # Log-spaced breaks covering the full palette range (pale yellow → deep red)
    # 5 values from near-zero to scale_max, then round to feel clean
    brk_raw <- c(0L, unique(as.integer(round(
      expm1(seq(0, log1p(scale_max), length.out = 7)[-1])
    ))))
    brk_raw <- unique(sort(pmin(as.integer(brk_raw), as.integer(scale_max))))
    
    leg_html <- paste0(
      '<div style="background:rgba(255,255,255,0.9);padding:8px 12px;',
      'border-radius:5px;font-size:12px;line-height:22px;',
      'box-shadow:0 1px 5px rgba(0,0,0,0.3);">',
      '<b>Detections</b><br>',
      paste(mapply(function(v) {
        col <- if (v == 0) "#d0d0d0" else det_pal(log1p(v))
        sprintf(
          '<div style="display:flex;align-items:center;gap:6px;">
           <div style="width:18px;height:12px;background:%s;border-radius:2px;flex-shrink:0;"></div>
           <span>%s</span></div>',
          col, scales::comma(v))
      }, brk_raw), collapse = ""),
      '</div>'
    )
    
    leafletProxy("species_map", data = map_df) %>%
      clearMarkers() %>%
      clearControls() %>%
      addCircleMarkers(
        lng         = ~longitude,
        lat         = ~latitude,
        radius      = 9,
        fillColor   = ~ifelse(n_det == 0, "#cccccc", det_pal(log1p(n_det))),
        fillOpacity = ~ifelse(n_det == 0, 0.25, 0.92),
        stroke      = FALSE,   # no outline
        popup = ~paste0(
          "<b>", site, "</b><br>",
          "<span style='color:#555'>", habitat_group, "</span><br>",
          "<b>", scales::comma(n_det), " detections</b><br>",
          period_label
        )
      ) %>%
      addControl(html = leg_html, position = "bottomleft", layerId = "det_legend")
  })
  
  output$map_caption <- renderText({
    sp_thresh <- apply_threshold(detections, input$map_spec) %>%
      filter(Common_Name == input$map_species)
    if (input$map_mode == "total") {
      total <- nrow(sp_thresh); sites <- n_distinct(sp_thresh$site)
      paste0(input$map_species, " — June 2025: ", scales::comma(total),
             " detections across ", sites, " sites (", input$map_spec, " specificity)")
    } else {
      dates <- all_dates_map()
      if (is.null(input$map_date_idx)) return("")
      sel_date <- dates[min(input$map_date_idx, length(dates))]
      day_det  <- sp_thresh %>% filter(date == sel_date)
      paste0(input$map_species, " on ", format(sel_date, "%B %d, %Y"), " — ",
             scales::comma(nrow(day_det)), " detections at ",
             n_distinct(day_det$site), " sites  ·  color scale fixed to species max (",
             scales::comma(map_scale_max()$day), "/site/day)")
    }
  })
  
  # ---------------------------------------------------------------------------
  # TAB 5 — Community Composition (NMDS)
  # ---------------------------------------------------------------------------
  
  nmds_data <- reactive({
    # Build species × site detection matrix at 85% threshold
    df <- apply_threshold(detections, input$nmds_spec)
    
    # Total detections per species per site
    mat_long <- df %>%
      count(site, Common_Name, name = "n") %>%
      pivot_wider(names_from = Common_Name, values_from = n, values_fill = 0)
    
    sites_in <- mat_long$site
    mat      <- as.matrix(mat_long[, -1])
    rownames(mat) <- sites_in
    
    # Remove sites with 0 total detections
    keep <- rowSums(mat) > 0
    mat  <- mat[keep, , drop = FALSE]
    sites_in <- sites_in[keep]
    
    # Remove species with 0 detections across kept sites
    mat <- mat[, colSums(mat) > 0, drop = FALSE]
    
    list(mat = mat, sites = sites_in)
  })
  
  nmds_result <- reactive({
    nd  <- nmds_data()
    mat <- nd$mat
    if (nrow(mat) < 3) return(NULL)
    
    set.seed(42)
    tryCatch(
      metaMDS(mat, distance = "bray", k = 2, trymax = 20,
              trace = FALSE, autotransform = TRUE),
      error = function(e) NULL
    )
  })
  
  output$nmds_plot <- renderPlot({
    nd    <- nmds_data()
    nmds  <- nmds_result()
    
    if (is.null(nmds)) {
      return(ggplot() +
               annotate("text", x=0.5, y=0.5, label="Not enough sites for NMDS",
                        size=6, color="grey50") + theme_void())
    }
    
    mat      <- nd$mat
    sites_in <- nd$sites
    
    # Site scores
    site_scores <- as.data.frame(scores(nmds, display = "sites")) %>%
      mutate(site = sites_in) %>%
      left_join(site_meta %>% select(site, management, Region, habitat_group),
                by = "site")
    
    color_var <- input$nmds_color
    color_vals <- site_scores[[color_var]]
    
    # Palette
    n_groups <- n_distinct(color_vals, na.rm = TRUE)
    pal <- if (n_groups <= 3)
      c("#2d6a4f","#f0a500","#3a86c8","#e63946","#6a0572")[seq_len(n_groups)]
    else
      scales::hue_pal()(n_groups)
    names(pal) <- unique(na.omit(color_vals))
    
    # PERMANOVA
    group_vec <- site_scores[[color_var]]
    perm_p <- tryCatch({
      pv <- adonis2(mat ~ group_vec, method = "bray", permutations = 999)
      round(pv$`Pr(>F)`[1], 3)
    }, error = function(e) NA)
    
    stress_label <- paste0("Stress = ", round(nmds$stress, 3))
    perm_label   <- if (!is.na(perm_p))
      paste0("  |  PERMANOVA p = ", perm_p) else ""
    
    p <- ggplot(site_scores, aes(x = NMDS1, y = NMDS2,
                                 color = .data[[color_var]],
                                 fill  = .data[[color_var]])) +
      geom_point(size = 3.5, alpha = 0.85) +
      scale_color_manual(values = pal, name = color_var) +
      scale_fill_manual(values  = pal, name = color_var) +
      labs(title    = "Community composition (NMDS, Bray-Curtis)",
           subtitle = paste0(stress_label, perm_label, "  ·  ",
                             input$nmds_spec, " specificity  ·  ",
                             nrow(mat), " sites  ·  ",
                             ncol(mat), " species"),
           x = "NMDS1", y = "NMDS2") +
      theme_minimal(base_size = 14) +
      theme(plot.title    = element_text(face = "bold", color = "#1a3c2e"),
            plot.subtitle = element_text(color = "#555555", size = 11),
            panel.grid.minor = element_blank(),
            legend.position  = "right")
    
    # Ellipses
    if (input$nmds_ellipse && n_groups >= 2) {
      p <- p + stat_ellipse(level = 0.95, geom = "polygon",
                            alpha = 0.08, linewidth = 0.6,
                            show.legend = FALSE)
    }
    
    # Species vectors
    if (input$nmds_vectors) {
      sp_scores <- as.data.frame(scores(nmds, display = "species")) %>%
        mutate(species = rownames(.),
               len     = sqrt(NMDS1^2 + NMDS2^2)) %>%
        slice_max(len, n = 10)   # top 10 most influential
      
      p <- p +
        geom_segment(data = sp_scores,
                     aes(x=0, y=0, xend=NMDS1*0.7, yend=NMDS2*0.7),
                     arrow = arrow(length=unit(0.18,"cm")),
                     color = "#444444", linewidth = 0.5,
                     inherit.aes = FALSE) +
        geom_text(data = sp_scores,
                  aes(x = NMDS1*0.75, y = NMDS2*0.75, label = species),
                  size = 3, color = "#333333", fontface = "italic",
                  inherit.aes = FALSE)
    }
    
    # Continuous habitat vectors (envfit)
    if (input$nmds_habitat) {
      env_vars <- covariates_raw %>%
        filter(site %in% sites_in) %>%
        arrange(match(site, sites_in)) %>%
        select(grass_pasture_pct_100m, forest_pct_100m,
               crop_pct_100m, wet_pct_100m, tot_area_ha) %>%
        mutate(across(everything(), ~replace_na(., median(., na.rm=TRUE))))
      
      ef <- tryCatch(
        envfit(nmds, env_vars, permutations = 999, na.rm = TRUE),
        error = function(e) NULL
      )
      if (!is.null(ef)) {
        env_scores <- as.data.frame(scores(ef, display = "vectors")) %>%
          mutate(var = rownames(.),
                 r2  = ef$vectors$r,
                 p   = ef$vectors$pvals) %>%
          filter(p < 0.1)   # only show significant vectors
        
        if (nrow(env_scores) > 0) {
          p <- p +
            geom_segment(data = env_scores,
                         aes(x=0, y=0, xend=NMDS1*0.6, yend=NMDS2*0.6),
                         arrow = arrow(length=unit(0.18,"cm")),
                         color = "#c0392b", linewidth = 0.7, linetype = "dashed",
                         inherit.aes = FALSE) +
            geom_text(data = env_scores,
                      aes(x=NMDS1*0.65, y=NMDS2*0.65, label=var),
                      size = 3, color = "#c0392b", fontface = "bold",
                      inherit.aes = FALSE)
        }
      }
    }
    
    p
  })
  
  output$nmds_caption <- renderText({
    nd   <- nmds_data()
    nmds <- nmds_result()
    if (is.null(nmds)) return("")
    paste0("Detection matrix: ", nrow(nd$mat), " sites × ", ncol(nd$mat),
           " species. Bray-Curtis dissimilarity, 2D NMDS (stress < 0.2 is good fit). ",
           "Species vectors = top 10 by axis loading. ",
           "Red dashed vectors = significant continuous habitat correlates (p < 0.1).")
  })
  
  
  # ---------------------------------------------------------------------------
  # DOWNLOAD HANDLERS
  # ---------------------------------------------------------------------------
  
  # Helper to get current heatmap/wx/nmds plot objects for saving
  output$dl_diel <- downloadHandler(
    filename = function() paste0("diel_", input$species, "_", Sys.Date(), ".png"),
    content  = function(file) {
      ggsave(file, plot = diel_plot_obj(), width = 10, height = 6, dpi = 150, bg = "white")
    }
  )
  
  output$dl_heatmap <- downloadHandler(
    filename = function() paste0("heatmap_", input$heat_view, "_", Sys.Date(), ".png"),
    content  = function(file) {
      # Re-render the heatmap plot for saving
      agg <- heat_data()
      req(!is.null(agg))
      norm <- input$heat_norm == "norm"
      view <- input$heat_view
      if (view == "diel") {
        hr <- input$heat_hours
        hour_bins <- seq(hr[1]*6L, hr[2]*6L, by=6L)
        x_breaks <- hour_bins; x_labels <- hour_labels(hour_bins%/%6L)
      } else {
        all_x <- sort(unique(agg$x_val))
        x_breaks <- all_x[seq(1,length(all_x),by=7)]
        x_labels <- format(as.Date(x_breaks, origin="1970-01-01"), "%b %d")
      }
      if (norm && "sp_total" %in% names(agg)) {
        agg <- agg %>% mutate(alpha_val = scales::rescale(log1p(replace_na(sp_total, 0)),
                                                          to=c(0.15,1.0),
                                                          from=c(0,log1p(max(sp_total,na.rm=TRUE)))))
      } else {
        agg <- agg %>% mutate(alpha_val = 1.0)
      }
      p <- ggplot(agg, aes(x=x_val, y=Common_Name, fill=n, alpha=alpha_val)) +
        geom_tile(color="white", linewidth=0.25) + guides(alpha="none") +
        scale_x_continuous(breaks=x_breaks, labels=x_labels, expand=expansion(0)) +
        scale_y_discrete(expand=expansion(0)) +
        theme_minimal(base_size=13) +
        theme(axis.text.x=element_text(angle=45,hjust=1), panel.grid=element_blank())
      if (norm) p <- p + scale_fill_gradient(low="#f0f9f0",high="#1b4332",limits=c(0,1))
      else p <- p + scale_fill_gradient(low="#f0f9f0",high="#1b4332",trans="log1p",
                                        breaks=c(0,25,100,500,2000,10000,25000),
                                        labels=scales::comma,limits=c(0,NA))
      ggsave(file, plot=p, width=12, height=8, dpi=150, bg="white")
    }
  )
  
  output$dl_wx <- downloadHandler(
    filename = function() paste0("weather_assoc_", Sys.Date(), ".png"),
    content  = function(file) {
      # Trigger re-render by calling output isolate workaround
      df <- wx_data(); req(!is.null(df))
      if (!input$wx_zeros) df <- df %>% filter(n_detections > 0)
      req(nrow(df) > 0)
      x_var <- input$wx_var
      x_label <- if (x_var=="temp_mean_c") "Daily mean temperature (°C)" else "Daily precipitation (mm)"
      use_color <- input$wx_color != "none"
      p <- ggplot(df, aes(x=.data[[x_var]], y=n_detections)) +
        geom_point(alpha=0.35, size=1.8, color="#2d6a4f") +
        scale_y_continuous(trans=if(input$wx_yscale=="log")"log1p" else "identity",
                           labels=scales::comma, expand=expansion(mult=c(0.02,0.05))) +
        labs(x=x_label, y="Detections per site per day",
             title=paste("Vocal detections vs.", tolower(x_label))) +
        theme_minimal(base_size=14)
      ggsave(file, plot=p, width=10, height=7, dpi=150, bg="white")
    }
  )
  
  output$dl_nmds <- downloadHandler(
    filename = function() paste0("nmds_", input$nmds_color, "_", Sys.Date(), ".png"),
    content  = function(file) {
      p <- last_plot()   # captures the most recently rendered plot
      ggsave(file, plot=p, width=9, height=7, dpi=150, bg="white")
    }
  )
  
  
  # ---------------------------------------------------------------------------
  # TAB 6 — Singing Windows
  # ---------------------------------------------------------------------------
  
  sw_plot_obj <- reactive({
    df <- apply_threshold(detections, input$sw_spec) %>%
      filter(hour >= input$sw_hours[1], hour <= input$sw_hours[2]) %>%
      mutate(dec_hour = true_time_s / 3600)  # decimal hours for precision
    
    stats <- df %>%
      group_by(Common_Name) %>%
      summarise(
        q10    = quantile(dec_hour, 0.10, na.rm=TRUE),
        q50    = quantile(dec_hour, 0.50, na.rm=TRUE),
        q90    = quantile(dec_hour, 0.90, na.rm=TRUE),
        window = q90 - q10,
        n_det  = n(),
        .groups = "drop"
      ) %>%
      filter(n_det >= input$sw_min_n) %>%
      arrange(q10) %>%
      mutate(Common_Name = factor(Common_Name, levels = rev(Common_Name)))
    
    req(nrow(stats) > 0)
    
    color_var <- input$sw_color
    color_lab <- if (color_var == "window") "Window width\n(hours, 10–90th pct)" else "Total detections"
    
    # Hour label helper for x axis
    hour_dec_label <- function(h) {
      hh <- floor(h); mm <- round((h - hh) * 60)
      if (hh == 0) "12 AM"
      else if (hh < 12) paste0(hh, ifelse(mm>0, paste0(":", sprintf("%02d",mm)), ""), " AM")
      else if (hh == 12) "12 PM"
      else paste0(hh-12, ifelse(mm>0, paste0(":", sprintf("%02d",mm)), ""), " PM")
    }
    x_breaks <- seq(input$sw_hours[1], input$sw_hours[2], by=1)
    x_labels <- sapply(x_breaks, hour_dec_label)
    
    ggplot(stats, aes(y = Common_Name)) +
      # Shaded window (10th–90th pct)
      geom_segment(aes(x = q10, xend = q90, yend = Common_Name,
                       color = .data[[color_var]]),
                   linewidth = 5, alpha = 0.75, lineend = "round") +
      # Median dot
      geom_point(aes(x = q50), color = "white", size = 2.2) +
      geom_point(aes(x = q50), color = "#1a1a1a", size = 1.2) +
      scale_color_gradient(low = "#74c476", high = "#00441b", name = color_lab,
                           labels = if (color_var=="window") function(x) paste0(round(x,1),"h")
                           else scales::comma) +
      scale_x_continuous(breaks = x_breaks, labels = x_labels,
                         expand = expansion(mult = 0.02)) +
      labs(title    = "Singing window summary",
           subtitle = paste0(input$sw_spec, " specificity  ·  ",
                             nrow(stats), " species with ≥", input$sw_min_n, " detections  ·  ",
                             "Bar = 10th–90th percentile of detection time  ·  dot = median"),
           x = "Time of day", y = NULL) +
      theme_minimal(base_size = 13) +
      theme(plot.title      = element_text(face="bold", color="#1a3c2e", size=15),
            plot.subtitle   = element_text(color="#555555", size=10),
            axis.text.y     = element_text(size=11),
            axis.text.x     = element_text(angle=45, hjust=1),
            panel.grid.major.y = element_line(color="#eeeeee"),
            panel.grid.major.x = element_blank(),
            panel.grid.minor   = element_blank(),
            legend.position = "right")
  })
  
  output$sw_plot   <- renderPlot({ sw_plot_obj() })
  
  output$sw_caption <- renderText({
    df <- apply_threshold(detections, input$sw_spec) %>%
      filter(hour >= input$sw_hours[1], hour <= input$sw_hours[2])
    n_sp <- n_distinct(df$Common_Name[df$Common_Name %in%
                                        (df %>% count(Common_Name) %>% filter(n >= input$sw_min_n) %>% pull(Common_Name))])
    paste0("Showing ", n_sp, " species. Narrowest bar = most temporally concentrated singer. ",
           "Species sorted by earliest onset (10th percentile). ",
           "White dot = median detection time.")
  })
  
  output$dl_sw <- downloadHandler(
    filename = function() paste0("singing_windows_", Sys.Date(), ".png"),
    content  = function(file) ggsave(file, plot=sw_plot_obj(), width=11, height=8, dpi=150, bg="white")
  )
  
  # ---------------------------------------------------------------------------
  # TAB 7 — Habitat Effects
  # ---------------------------------------------------------------------------
  
  # Pre-compute: total active site-days per site (denominator for detection rate)
  active_site_days_all <- detections %>%
    distinct(site, date) %>%
    left_join(site_meta %>% select(site, management, habitat_group), by="site")
  
  hab_plot_obj <- reactive({
    grp <- input$hab_group
    
    if (input$hab_view == "occ") {
      # ---- Occupancy heatmap ----
      df <- apply_threshold(detections, input$hab_spec)
      
      if (input$hab_metric == "pct_occ") {
        # % of MONITORED sites (sites with recordings) where species detected ≥ once.
        # Critical: use only sites present in detections as denominator —
        # site_meta includes unmonitored sites which would deflate control/reference.
        monitored_sites <- detections %>% distinct(site)
        site_grps <- site_meta %>%
          semi_join(monitored_sites, by="site") %>%   # only monitored sites
          select(site, !!sym(grp)) %>% distinct()
        n_sites_grp <- site_grps %>% count(.data[[grp]], name="n_sites")
        
        detected <- df %>%
          distinct(Common_Name, site) %>%
          left_join(site_grps, by="site") %>%
          filter(!is.na(.data[[grp]])) %>%
          count(Common_Name, .data[[grp]], name="n_det_sites")
        
        occ <- site_grps %>%
          distinct(.data[[grp]]) %>%
          crossing(Common_Name = species_list) %>%
          left_join(detected, by=c("Common_Name", grp)) %>%
          left_join(n_sites_grp, by=grp) %>%
          mutate(
            n_det_sites = replace_na(n_det_sites, 0L),
            value       = n_det_sites / n_sites * 100
          )
        
        fill_lab <- "% monitored\nsites occupied"
        fill_scale <- scale_fill_gradient(low="#f7fcf5", high="#006d2c",
                                          name=fill_lab, limits=c(0,100),
                                          labels=function(x) paste0(x,"%"))
      } else {
        # Mean detections per active site-day
        sp_counts <- df %>%
          count(Common_Name, site, date, name="n_det")
        
        occ <- active_site_days_all %>%
          crossing(Common_Name = species_list) %>%
          left_join(sp_counts, by=c("Common_Name","site","date")) %>%
          mutate(n_det = replace_na(n_det, 0L)) %>%
          group_by(Common_Name, .data[[grp]]) %>%
          summarise(value = mean(n_det), .groups="drop")
        
        fill_lab <- "Mean det.\nper site-day"
        fill_scale <- scale_fill_gradient(low="#f7fcf5", high="#006d2c",
                                          name=fill_lab,
                                          trans="sqrt",
                                          labels=scales::comma)
      }
      
      # Species order
      if (input$hab_order == "occ") {
        sp_order <- occ %>% group_by(Common_Name) %>%
          summarise(tot=sum(value,na.rm=TRUE), .groups="drop") %>%
          arrange(tot) %>% pull(Common_Name)
      } else {
        sp_order <- rev(sort(species_list))
      }
      occ$Common_Name <- factor(occ$Common_Name, levels=sp_order)
      
      ggplot(occ, aes(x=.data[[grp]], y=Common_Name, fill=value)) +
        geom_tile(color="white", linewidth=0.4) +
        geom_text(aes(label=if(input$hab_metric=="pct_occ")
          paste0(round(value), "%\n(n=", n_sites, ")")
          else
            ifelse(value>0, round(value,1), "")),
          size=2.8, lineheight=0.9,
          color=ifelse(occ$value > max(occ$value,na.rm=TRUE)*0.6,
                       "white","#333333")) +
        fill_scale +
        scale_x_discrete(expand=expansion(0)) +
        scale_y_discrete(expand=expansion(0)) +
        labs(title    = if(input$hab_metric=="pct_occ")
          "Species occupancy by habitat"
          else
            "Detection rate by habitat (mean detections / site-day)",
          subtitle = paste0(input$hab_spec, " specificity  ·  ",
                            n_distinct(occ[[grp]]), " ", grp, " groups  ·  ",
                            "n = monitored sites per group  ·  darker = higher occupancy"),
          x=NULL, y=NULL) +
        theme_minimal(base_size=13) +
        theme(plot.title     =element_text(face="bold",color="#1a3c2e",size=14),
              plot.subtitle  =element_text(color="#555555",size=10),
              axis.text.x    =element_text(angle=30,hjust=1,size=11),
              axis.text.y    =element_text(size=11),
              panel.grid     =element_blank(),
              legend.position="right",
              legend.key.height=unit(1.2,"cm"))
      
    } else if (input$hab_view == "rate") {
      # ---- Single species detection rate ----
      sp <- input$hab_species
      df <- apply_threshold(detections, input$hab_spec) %>%
        filter(Common_Name == sp) %>%
        count(site, date, name="n_det")
      
      rate_df <- active_site_days_all %>%
        left_join(df, by=c("site","date")) %>%
        mutate(n_det = replace_na(n_det, 0L))
      
      set.seed(42)
      boot_ci <- rate_df %>%
        group_by(.data[[grp]]) %>%
        summarise(
          mean_rate = mean(n_det),
          n_obs     = n(),
          ci_lo = tryCatch(t.test(n_det)$conf.int[1], error=function(e) mean_rate),
          ci_hi = tryCatch(t.test(n_det)$conf.int[2], error=function(e) mean_rate),
          .groups="drop"
        ) %>%
        arrange(desc(mean_rate))
      
      grp_levels <- boot_ci[[grp]]
      boot_ci[[grp]] <- factor(grp_levels, levels = rev(grp_levels))
      
      ggplot(boot_ci, aes(x=mean_rate, y=.data[[grp]])) +
        geom_col(aes(fill=mean_rate), width=0.65, alpha=0.92) +
        geom_errorbarh(aes(xmin=pmax(ci_lo,0), xmax=ci_hi),
                       height=0.25, linewidth=0.8, color="#333333") +
        geom_text(aes(x=ci_hi + max(ci_hi,na.rm=TRUE)*0.02,
                      label=paste0(round(mean_rate,1), " (n=",n_obs,")")),
                  hjust=0, size=3.5, color="#333333") +
        scale_fill_gradient(low="#74c476", high="#006d2c", guide="none") +
        scale_x_continuous(expand=expansion(mult=c(0,0.25)), labels=scales::comma) +
        labs(title    = paste("Detection rate by habitat:", sp),
             subtitle = paste0(input$hab_spec, " specificity  ·  detections per active site-day  ·  95% CI"),
             x="Mean detections per site-day", y=NULL) +
        theme_minimal(base_size=14) +
        theme(plot.title=element_text(face="bold",color="#1a3c2e",size=14),
              plot.subtitle=element_text(color="#555555",size=11),
              axis.text.y=element_text(size=12),
              panel.grid.major.y=element_blank(), panel.grid.minor=element_blank())
      
    } else {
      # ---- Rank abundance ----
      # Detection rate per species × habitat (detections / active site-days in that group)
      n_site_days_grp <- active_site_days_all %>%
        count(.data[[grp]], name="n_site_days")
      
      rank_df <- apply_threshold(detections, input$hab_spec) %>%
        count(.data[[grp]], Common_Name, name="n_det") %>%
        left_join(n_site_days_grp, by=grp) %>%
        mutate(rate = n_det / n_site_days) %>%
        group_by(.data[[grp]]) %>%
        arrange(desc(rate), .by_group=TRUE) %>%
        mutate(rank = row_number()) %>%
        ungroup()
      
      # Color palette: one color per habitat group
      grp_levels <- sort(unique(rank_df[[grp]]))
      n_grps     <- length(grp_levels)
      grp_pal    <- setNames(
        RColorBrewer::brewer.pal(max(3, n_grps), "Set2")[seq_len(n_grps)],
        grp_levels
      )
      
      if (input$hab_rank_type == "bar") {
        # Faceted lollipop chart — top N per habitat, clean and readable
        top_df <- rank_df %>%
          filter(rank <= input$hab_top_n) %>%
          group_by(.data[[grp]]) %>%
          mutate(Common_Name = factor(Common_Name,
                                      levels=Common_Name[order(rate)])) %>%
          ungroup()
        
        ggplot(top_df, aes(x=rate, y=Common_Name,
                           color=.data[[grp]], fill=.data[[grp]])) +
          geom_segment(aes(x=0, xend=rate, yend=Common_Name),
                       linewidth=1, alpha=0.4) +
          geom_point(size=4, alpha=0.95) +
          geom_text(aes(label=round(rate,1)), hjust=-0.4, size=3, color="#333333") +
          facet_wrap(as.formula(paste("~", grp)), scales="free_y", ncol=2) +
          scale_color_manual(values=grp_pal, guide="none") +
          scale_fill_manual(values=grp_pal, guide="none") +
          scale_x_continuous(expand=expansion(mult=c(0, 0.25)),
                             labels=scales::comma) +
          labs(title    = paste0("Top ", input$hab_top_n,
                                 " species by detection rate — by ", grp),
               subtitle = paste0(input$hab_spec,
                                 " specificity  ·  mean detections per active site-day  ·  ",
                                 "species ranked within each group"),
               x="Mean detections per site-day", y=NULL) +
          theme_minimal(base_size=12) +
          theme(plot.title=element_text(face="bold",color="#1a3c2e",size=14),
                plot.subtitle=element_text(color="#555555",size=10),
                strip.text=element_text(face="bold",size=11,color="#1a3c2e"),
                strip.background=element_rect(fill="#eaf4ef",color=NA),
                axis.text.y=element_text(size=10),
                panel.grid.major.y=element_blank(),
                panel.grid.minor=element_blank())
        
      } else {
        # Rank abundance curves — all species, x=rank, y=log(rate)
        # Reveals community structure: slope = dominance, width = richness
        ggplot(rank_df %>% filter(rate > 0),
               aes(x=rank, y=rate, color=.data[[grp]], group=.data[[grp]])) +
          geom_line(linewidth=1.1, alpha=0.85) +
          geom_point(size=2, alpha=0.7) +
          scale_color_manual(values=grp_pal,
                             name=if(grp=="management") "Management" else grp) +
          scale_y_log10(labels=scales::comma,
                        breaks=c(0.01,0.1,1,10,100,1000)) +
          scale_x_continuous(breaks=seq(1, max(rank_df$rank), by=2)) +
          labs(title    = paste("Rank abundance curves by", grp),
               subtitle = paste0(input$hab_spec,
                                 " specificity  ·  detection rate (det/site-day, log scale)  ·  ",
                                 "steeper slope = more dominant community"),
               x="Species rank (1 = most abundant)", y="Detections per site-day (log scale)") +
          theme_minimal(base_size=13) +
          theme(plot.title=element_text(face="bold",color="#1a3c2e",size=14),
                plot.subtitle=element_text(color="#555555",size=10),
                legend.position="right",
                panel.grid.minor=element_blank())
      }
    }
  })
  
  output$hab_plot   <- renderPlot({ hab_plot_obj() })
  
  output$hab_caption <- renderText({
    grp <- input$hab_group
    if (input$hab_view == "occ") {
      n_grps <- n_distinct(site_meta[[grp]])
      paste0("Each cell = ", if(input$hab_metric=="pct_occ")
        paste0("% of MONITORED ", grp,
               " sites where species detected ≥ once (n in parentheses). ",
               "Denominator = sites with recordings only — unmonitored sites excluded.")
        else
          paste0("mean detections per active site-day (zeros included for undetected days)."))
    } else if (input$hab_view == "rate") {
      paste0(input$hab_species, " — mean detections per active site-day by ", grp,
             ". Error bars = 95% t-interval. n = number of site-day observations per group.")
    } else {
      if (input$hab_rank_type == "bar")
        paste0("Top ", input$hab_top_n, " species by detection rate within each ", grp,
               " group. Each panel ranked independently.")
      else
        paste0("Rank abundance curves by ", grp,
               ". Steeper slope = community dominated by few species. ",
               "Flatter/wider = more even community. Only species with ≥1 detection shown.")
    }
  })
  
  output$dl_hab <- downloadHandler(
    filename = function() paste0("habitat_effects_", Sys.Date(), ".png"),
    content  = function(file) ggsave(file, plot=hab_plot_obj(), width=10, height=7, dpi=150, bg="white")
  )
  
}

# =============================================================================
shinyApp(ui, server)
