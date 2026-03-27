## SETUP ####

sessionInfo()

# REQUIRED PACKAGES

pkgs <- c("tidyverse",
          # "ggplot2", # creating graphs
          # "dplyr",
          # "patchwork",
          # "knitr",
          # "viridis",
          # "DT",
          # "kableExtra",
          # "lme4", 
          # "emmeans",
          # "lmerTest",
          # "ggdist",
          # "tidyquant",
          "data.table"
)

# check if required packages are installed
installed_packages = pkgs %in% rownames(installed.packages())

# install packages if not installed
if (any(installed_packages == FALSE)) {
  install.packages(pkgs[!installed_packages])
}

#loads required packages and gives error if not found
lapply(pkgs, function(pkg) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    message(paste("Package", pkg, "not found."))
  }
})

# =============================================================================
# Auditory Oddball – Data Quality Script
# Steps:
#   1. PD NA check & summary
#   2. Exclude trials with > 50 % PD NAs
#   3. Gaze offset check & exclusion (AOI threshold = 200 px from center)
# =============================================================================

# -----------------------------------------------------------------------------
# Paths – adjust to your project
# -----------------------------------------------------------------------------
home_path <- "//192.168.88.212/daten/KJP_Studien"
data_path <- "/LOCUS_MENTAL/6_Versuchsdaten/auditory_oddball/"

df_et <- readRDS(paste0(home_path, data_path, "eyetracking_ao.rds"))

# =============================================================================
# 1. PD NA CHECK & SUMMARY
# =============================================================================
cat("==========================================================\n")
cat("STEP 1 – PD Missing Data Summary\n")
cat("==========================================================\n\n")

# Per-trial NA summary
trial_na_summary <- df_et %>%
  group_by(id, trial_number) %>%
  summarise(
    total_samples = n(),
    na_count      = sum(is.na(pd)),
    na_prop       = mean(is.na(pd)),
    .groups = "drop"
  )

cat("Overall PD NA summary across all trials:\n")
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

cat("\nPer-participant PD missing data proportion:\n")
print(participant_na_summary)
sort(round(participant_na_summary$na_prop,2))

### MArch 2026:
#--> of n=91 datasets, n=84 have less than 10% missing data

# =============================================================================
# 2. EXCLUDE TRIALS WITH > 50 % PD NAs
# =============================================================================
cat("\n==========================================================\n")
cat("STEP 2 – Exclude Trials with > 50 % PD NAs\n")
cat("==========================================================\n\n")

na_threshold <- 0.50

high_na_trials <- trial_na_summary %>%
  filter(na_prop > na_threshold)

cat("Trials flagged as high-NA (na_prop > 50 %):\n")
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

# Mean NA proportion in excluded vs. included trials
included_na_summary <- trial_na_summary %>%
  anti_join(high_na_trials, by = c("id", "trial_number"))

cat(sprintf(
  "  Mean NA prop in excluded trials : %.3f
  Mean NA prop in included trials  : %.3f\n\n",
  mean(high_na_trials$na_prop),
  mean(included_na_summary$na_prop)
))


# =============================================================================
# 3. GAZE OFFSET CHECK & EXCLUSION (AOI = 200 px from center)
# =============================================================================
cat("==========================================================\n")
cat("STEP 3 – Gaze Offset Check & Exclusion (AOI ±200 px)\n")
cat("==========================================================\n\n")

# --- 3a. Verify required gaze columns ----------------------------------------
gaze_cols         <- c("left_gaze_x", "right_gaze_x", "left_gaze_y", "right_gaze_y")
missing_gaze_cols <- setdiff(gaze_cols, names(df))

if (length(missing_gaze_cols) > 0) {
  stop("Missing gaze columns: ", paste(missing_gaze_cols, collapse = ", "))
}

# --- 3b. Average left/right gaze to get a single x/y per sample --------------
df <- df %>%
  mutate(
    gaze_x_px = (left_gaze_x + right_gaze_x) / 2,
    gaze_y_px = (left_gaze_y + right_gaze_y) / 2
  )

cat("Gaze position summaries (averaged eye):\n")
cat("  X position:\n"); print(summary(df$gaze_x_px))
cat("  Y position:\n"); print(summary(df$gaze_y_px))

# --- 3c. AOI classification --------------------------------------------------
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
cat("\nGaze classification (box criterion ±200 px):\n")
print(aoi_counts)
cat("\nProportion (%):\n")
print(round(prop.table(aoi_counts) * 100, 2))

prop_deviated <- mean(df$gaze_deviated, na.rm = TRUE) * 100
cat(sprintf(
  "\nProportion of samples outside circular AOI boundary (r > %d px): %.2f%%\n",
  aoi_threshold, prop_deviated
))

# --- 3d. Keep only AOI samples -----------------------------------------------
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

# --- 3e. Per-trial offset summary (informational) ----------------------------
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


output_file <- paste0(home_path, data_path, "eyetracking_ao_clean.rds")
saveRDS(df_aoi, file = output_file)
cat(sprintf("\nCleaned dataset saved to:\n  %s\n", output_file))
