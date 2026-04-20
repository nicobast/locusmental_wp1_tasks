################################################################################
#
# Rapid Sound Sequences Data Quallity
# Author: Iskra Todorova
# Last Update: 10.02.2026
# R Version: 4.5.1
#
################################################################################
#
# Before you begin
# - Loading/installing packages
# - Setting working directory
#
################################################################################
#
# In this script
# - Loading/reading the raw eye tracking data and excel trial data
# - calculating pd 
# - some reshaping
# - save eye tracking data and trial data as rds
#
################################################################################
## SETUP ####

sessionInfo()

# REQUIRED PACKAGES

pkgs <- c("tidyverse",
          "ggplot2", # creating graphs
          "dplyr",
          "patchwork",
          "knitr",
          "viridis",
          "DT",
          "kableExtra",
          "lme4", 
          "emmeans",
          "lmerTest",
          "ggdist",
          "tidyquant"
)

# check if required packages are installed
installed_packages = pkgs %in% rownames(installed.packages())

# install packages if not installed
if (any(installed_packages == FALSE)) {
  install.packages(pkgs[!installed_packages])
}

lapply(pkgs, function(pkg) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    message(paste("Package", pkg, "not found."))
  }
})

# Define paths (adjust to your project)
home_path <- "S:/KJP_Studien"
#home_path <- "C:/Users/nico/Nextcloud/project_locusmental_wp1"
#data_path <- "/data/rapid_sound_sequences/preprocessed/"
data_path <- "/LOCUS_MENTAL/6_Versuchsdaten/rapid_sound_sequences/"

# Load processed files
df_et <- readRDS(paste0(home_path, data_path, "eyetracking_rss.rds"))
df_trial <- readRDS(paste0(home_path, data_path, "trialdata_rss.rds"))


###############################################################################


# 1. Missing PD Data ----

#  Simple count and percentage
total_summary <- df_et %>%
  summarise(
    Total_Samples = n(),
    Missing_Samples = sum(is.na(pd)),
    Valid_Samples = sum(!is.na(pd)),
    Percent_Missing = (Missing_Samples / Total_Samples) * 100
  )

print("--- Total Overview ---")
print(total_summary)

 exclusion_report <- df_et %>%
 summarise(
     # 1. Total rows recorded by eyetracker
     total_rows = n(),
     
     # 2. Rows removed because they weren't in a labeled phase (ISI, Sequence, etc.)
     # These are the ones your function labeled as NA
     rows_with_no_phase = sum(is.na(trial_phase)),
     
     # 3. Rows that ARE in a phase but have NO pupil data (The ones you want to exclude for stats)
     # This is your true "Data Loss" due to quality/gaze-contingency
    missing_pd_in_valid_phases = sum(!is.na(trial_phase) & is.na(pd)),
     
     # 4. Total valid data points available for your LMM
     valid_data_points = sum(!is.na(trial_phase) & !is.na(pd))
   ) %>%
   mutate(
   percent_quality_loss = (missing_pd_in_valid_phases / (total_rows - rows_with_no_phase)) * 100
   )

print(exclusion_report)
 
# Exclude pd NAs
 df_et_clean_na <- df_et %>%
   # Remove rows where pupil is NA 
  filter(!is.na(pd))

# 2. Trials Check per participant ----

# --- 1. SETTINGS & THRESHOLDS ---
expected_samples <- 360 # 6s @ 60Hz
min_tracking_ratio <- 0.50 # 50% of 360 = 180 samples

# Participant-level thresholds (High vs Low)
thresh_high <- tibble(
  Condition = c("REG10", "RAND20", "REG10-RAND20", "RAND20-REG10", "RAND20-REG1"),
  min_req = c(4, 4, 6, 6, 6) 
)
thresh_low <- tibble(
  Condition = c("REG10", "RAND20", "REG10-RAND20", "RAND20-REG10", "RAND20-REG1"),
  min_req = c(2, 2, 2, 2, 2)
)

# --- 2. GAZE & TRIAL LEVEL PROCESSING ---
df_trial_pool <- df_et_clean_na %>%
  mutate(
    gaze_x_px = (left_gaze_x + right_gaze_x) / 2,
    gaze_y_px = (left_gaze_y + right_gaze_y) / 2,
    gaze_dist = sqrt(gaze_x_px^2 + gaze_y_px^2)
  ) %>%
  # Filter for on-screen samples
  filter(!is.na(gaze_dist), abs(gaze_x_px) <= 1280, abs(gaze_y_px) <= 720) %>%
  group_by(id, Trial.Number, Condition) %>%
  summarise(
    actual_n = n(),
    tracking_ok = actual_n >= (expected_samples * min_tracking_ratio),
    prop_135 = sum(gaze_dist <= 135) / actual_n,
    prop_200 = sum(gaze_dist <= 200) / actual_n,
    .groups = "drop"
  ) %>%
  filter(tracking_ok == TRUE) # Drop trials with < 50% data recording

# --- 3. HELPER FUNCTION FOR PARTICIPANT FILTERING ---
# This function applies your 'Group A' and 'Group B' completion logic
filter_completed_ids <- function(trial_data, aoi_col, count_rules) {
  
  # Step A: Filter trials by AOI threshold (50% in AOI)
  valid_trials <- trial_data %>% filter(!!sym(aoi_col) >= 0.50)
  
  # Step B: Count valid trials per ID/Condition
  counts <- valid_trials %>%
    group_by(id, Condition) %>%
    summarise(n = n(), .groups = "drop") %>%
    left_join(count_rules, by = "Condition") %>%
    mutate(meets = n >= min_req)
  
  # Step C: Completion Logic
  ids_passing <- counts %>%
    group_by(id) %>%
    summarise(
      # Group A: RAND20 + (RAND20-REG10 or RAND20-REG1)
      has_rand_group = any(Condition == "RAND20" & meets) & 
        (any(Condition == "RAND20-REG10" & meets) | any(Condition == "RAND20-REG1" & meets)),
      # Group B: REG10 + REG10-RAND20
      has_reg_group = any(Condition == "REG10" & meets) & 
        any(Condition == "REG10-RAND20" & meets),
      keep = has_rand_group | has_reg_group
    ) %>%
    filter(keep == TRUE) %>%
    pull(id)
  
  # Return final DF with only valid IDs and valid trials
  return(valid_trials %>% filter(id %in% ids_passing))
}

# --- 4. CREATE THE 4 FINAL DATAFRAMES ---

# 1. Strict AOI (135) + High Trial Requirements
df_strict_high <- filter_completed_ids(df_trial_pool, "prop_135", thresh_high)

# 2. Strict AOI (135) + Low Trial Requirements
df_strict_low  <- filter_completed_ids(df_trial_pool, "prop_135", thresh_low)

# 3. Loose AOI (200) + High Trial Requirements
df_loose_high  <- filter_completed_ids(df_trial_pool, "prop_200", thresh_high)

# 4. Loose AOI (200) + Low Trial Requirements
df_loose_low   <- filter_completed_ids(df_trial_pool, "prop_200", thresh_low)

# --- 5. REPORTING & VISUALIZATION ---

report <- data.frame(
  Dataset = c("Strict_High", "Strict_Low", "Loose_High", "Loose_Low"),
  N_Trials = c(nrow(df_strict_high), nrow(df_strict_low), nrow(df_loose_high), nrow(df_loose_low)),
  N_Participants = c(n_distinct(df_strict_high$id), n_distinct(df_strict_low$id), 
                     n_distinct(df_loose_high$id), n_distinct(df_loose_low$id))
)

cat("\n--- FINAL EXCLUSION SUMMARY ---\n")
print(report)

# Visualization of Data Loss (using Strict_High as example)
ggplot(df_trial_pool, aes(x = actual_n)) +
  geom_histogram(fill = "grey80", color = "white", bins = 30) +
  geom_vline(xintercept = 180, color = "red", linetype = "dashed") +
  labs(title = "Trial Quality (Samples per Trial)",
       subtitle = "Trials below red line (180 samples) were excluded immediately",
       x = "Sample Count", y = "Frequency") +
  theme_minimal()

# Result Visualization: Comparing Strict vs Loose (High Threshold Only)
df_comp <- bind_rows(
  df_strict_high %>% mutate(Type = "Strict (135px)"),
  df_loose_high %>% mutate(Type = "Loose (200px)")
)

ggplot(df_comp, aes(x = Condition, y = if_else(Type == "Strict (135px)", prop_135, prop_200), fill = Type)) +
  geom_boxplot(alpha = 0.7) +
  theme_minimal() +
  coord_flip() +
  labs(title = "AOI Proportion: Strict vs Loose Comparison",
       subtitle = "Using High Trial-Count Threshold",
       y = "Gaze Proportion in AOI")


saveRDS(df_strict_high,file = paste0(home_path,data_path ,"df_strict_high.rds"))
saveRDS(df_strict_low,file = paste0(home_path,data_path,  "df_strict_low.rds"))
saveRDS(df_loose_high, file = paste0(home_path,data_path ,"df_loose_high.rds"))
saveRDS(df_loose_low,file = paste0(home_path,data_path, "df_loose_low.rds"))


