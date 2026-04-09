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
          "tidyquant",
          "data.table"
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

# =============================================================================
# Visual Oddball – Data Quality Script
# Steps:
#   1. PD NA check & summary
#   2. Exclude trials with > 50 % PD NAs
#   3. Gaze offset check & exclusion (AOI threshold = 200 px from center)
# =============================================================================

# -----------------------------------------------------------------------------
# Paths – adjust to your project
# -----------------------------------------------------------------------------

home_path <- "S:/KJP_Studien"
data_path <- "/LOCUS_MENTAL/6_Versuchsdaten/visual_oddball/"

# Load processed files
df_et <- readRDS(paste0(home_path, data_path, "eyetracking_processed.rds"))

# =============================================================================
# 1. PD NA CHECK & SUMMARY
# =============================================================================

# Per-trial NA summary
trial_na_summary <- df_et %>%
  group_by(id, trial_number) %>%
  summarise(
    total_samples = n(),
    na_count      = sum(is.na(pd)),
    na_prop       = mean(is.na(pd)),
    .groups = "drop"
  )

print(summary(trial_na_summary$na_prop))

# Per-participant NA summary
participant_na_summary <- df_et %>%
  group_by(id) %>%
  summarise(
    total_samples = n(),
    na_count      = sum(is.na(pd)),
    na_prop       = mean(is.na(pd)),
    .groups = "drop"
  ) %>%
  arrange(desc(na_prop))

print(participant_na_summary)


# =============================================================================
# 2. EXCLUDE TRIALS WITH > 50 % PD NAs
# =============================================================================

na_threshold <- 0.50

high_na_trials <- trial_na_summary %>%
  filter(na_prop > na_threshold)

print(high_na_trials)

# Exclude flagged trials from the eye-tracking data
df <- df_et %>%
  anti_join(high_na_trials, by = c("id", "trial_number"))

# Exclusion summary
total_trials     <- nrow(trial_na_summary)
excluded_trials  <- nrow(high_na_trials)
remaining_trials <- total_trials - excluded_trials

cat(sprintf(
  "\nNA filtering summary:
  Total trials         : %d
  Excluded (NA > %.0f%%): %d  (%.2f%%)
  Remaining            : %d  (%.2f%%)\n",
  total_trials,
  na_threshold * 100,
  excluded_trials,  (excluded_trials  / total_trials) * 100,
  remaining_trials, (remaining_trials / total_trials) * 100
))

# =============================================================================
# 3. GAZE OFFSET CHECK & EXCLUSION (AOI = 200 px from center)
# =============================================================================
#  Verify required gaze columns 
gaze_cols         <- c("left_gaze_x", "right_gaze_x", "left_gaze_y", "right_gaze_y")
missing_gaze_cols <- setdiff(gaze_cols, names(df))

if (length(missing_gaze_cols) > 0) {
  stop("Missing gaze columns: ", paste(missing_gaze_cols, collapse = ", "))
}

# Average left/right gaze to get a single x/y per sample
df <- df %>%
  mutate(
    gaze_x_px = (left_gaze_x + right_gaze_x) / 2,
    gaze_y_px = (left_gaze_y + right_gaze_y) / 2
  )

cat("Gaze position summaries (averaged eye):\n")
cat("  X position:\n"); print(summary(df$gaze_x_px))
cat("  Y position:\n"); print(summary(df$gaze_y_px))

# AOI classification
# Screen centre is (0, 0) in gaze-coordinate space; AOI = ±200 px square
aoi_threshold <- 200

df <- df %>%
  mutate(
    aoi_label      = ifelse(
      abs(gaze_x_px) <= aoi_threshold & abs(gaze_y_px) <= aoi_threshold,
      "AOI", "Offset"
    ),
    gaze_distance  = sqrt(gaze_x_px^2 + gaze_y_px^2),   # Euclidean distance from centre
    gaze_deviated  = gaze_distance > aoi_threshold        # circular boundary flag
  )

aoi_counts <- table(df$aoi_label)
print(aoi_counts)
print(round(prop.table(aoi_counts) * 100, 2))

prop_deviated <- mean(df$gaze_deviated, na.rm = TRUE) * 100
cat(sprintf(
  "\nProportion of samples outside circular AOI boundary (r > %d px): %.2f%%\n",
  aoi_threshold, prop_deviated
))

# Keep only AOI samples 
total_samples_before <- nrow(df)
df_aoi               <- df %>% filter(aoi_label == "AOI")
excluded_samples     <- total_samples_before - nrow(df_aoi)

cat(sprintf(
  "\nGaze offset exclusion summary:
  Total samples         : %d
  Excluded (Offset)     : %d  (%.2f%%)
  Remaining (AOI only)  : %d  (%.2f%%)\n\n",
  total_samples_before,
  excluded_samples,      (excluded_samples      / total_samples_before) * 100,
  nrow(df_aoi),          (nrow(df_aoi)           / total_samples_before) * 100
))

# Per-trial offset summary (informational)
trial_offset_summary <- df %>%
  group_by(id, trial_number) %>%
  summarise(
    total_samples   = n(),
    offset_samples  = sum(aoi_label == "Offset", na.rm = TRUE),
    offset_prop     = mean(aoi_label == "Offset", na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(offset_prop))

cat("Trials with the highest gaze-offset proportion (top 20):\n")
print(head(trial_offset_summary, 20))

# =============================================================================
# OUTPUT
# =============================================================================
# df_aoi  – clean eye-tracking data: trials with <= 50 % PD NAs AND gaze in AOI
# trial_na_summary    – per-trial NA proportions (all trials)
# trial_offset_summary – per-trial gaze-offset proportions (after NA exclusion)

cat("\n==========================================================\n")
cat("Quality checks complete.\n")
cat("  Clean dataset : 'df_aoi'\n")
cat(sprintf("  Rows          : %d\n", nrow(df_aoi)))
cat(sprintf("  Participants  : %d\n", length(unique(df_aoi$id))))
cat("==========================================================\n")


output_file <- paste0(home_path, data_path, "eyetracking_vo_clean.rds")
saveRDS(df_aoi, file = output_file)
cat(sprintf("\nCleaned dataset saved to:\n  %s\n", output_file))
