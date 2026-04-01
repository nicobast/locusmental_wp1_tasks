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
          "data.table",
          "readxl",
          "psych"
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

# PATHS (adjust to your project)

home_path <- "//192.168.88.212/daten/KJP_Studien"
data_path <- "/LOCUS_MENTAL/6_Versuchsdaten/visual_search_task/"

# Load processed files
df_et <- readRDS(paste0(home_path, data_path, "eyetracking_processed.rds"))
df_trial <- readRDS(paste0(home_path, data_path, "trialdata_processed.rds"))

df_trial_hits_only <- readRDS(paste0(home_path, data_path, "eyetracking_trial_hits_only.rds"))
df_trial_hits <- readRDS(paste0(home_path, data_path, "eyetracking_trial_hits.rds"))


# 1) Trial-Level Metrics ----
## Trial Duration, Stimulus Duration and ISI Duration

# Remove rows where baseline_fixation_start_timestamps has missing values
df_trial <- df_trial[is.na(df_trial$baseline_fixation_start_timestamp), ]
# Create trial_type based on auditory_cue
df_trial$trial_type <- ifelse(df_trial$auditory_cue == TRUE, "cued", "standard")

# Expected durations
expected_trial_duration <- 3.5 
expected_stimulus_duration <- 1.5
expected_ISI_duration <- 1.5
expected_beep_phase_duration <- 0.4
expected_beep_duration <- 0.2

# Plot 1: Trial Duration
p1 <- ggplot(df_trial, aes(x = trial_duration)) +
  geom_histogram(bins = 50, fill = "steelblue", color = "white") +
  facet_wrap(~trial_type)+
  xlim(c(0,10))+
  geom_vline(xintercept = expected_trial_duration, linetype = "dashed", color = "red", linewidth = 1) +
  annotate("text", x = expected_trial_duration, y = 0, label = "Expected Max Duration",
           color = "red", angle = 0, vjust = -0.7, size = 3) +
  labs(title = "Distribution of Trial Duration", x = "Trial Duration (s)", y = "Count") +
  theme_minimal()
print(p1)

# Plot 2: Stimulus Duration
p2 <- ggplot(df_trial, aes(x = actual_visual_search_duration)) +
  geom_histogram(bins = 30, fill = "steelblue", color = "white") +
  facet_wrap(~trial_type)+
  geom_vline(xintercept = expected_stimulus_duration, linetype = "dashed", color = "red", size = 1) +
  annotate("text", x = expected_stimulus_duration, y = 0, label = "Expected Duration",
           color = "red", angle = 0, vjust = -0.7, size = 3) +
  labs(title = "Distribution of Stimulus Duration", x = "Stimulus Duration (s)", y = "Count") +
  theme_minimal()
print(p2)

# Plot 3: ISI Duration
p3 <- ggplot(df_trial, aes(x = ISI_actual_duration)) +
  geom_histogram(bins = 30, fill = "steelblue", color = "white") +
  facet_wrap(~trial_type)+
  xlim(c(0,10))+
  geom_vline(xintercept = expected_ISI_duration, linetype = "dashed", color = "red", size = 1) +
  annotate("text", x = expected_ISI_duration, y = 0, label = "Expected Max Duration",
           color = "red",angle = 0, vjust = -0.7, size = 3) +
  labs(title = "Distribution of ISI Duration", x = "ISI Duration (s)", y = "Count") +
  theme_minimal()
print(p3)

# Plot 4: Beep Phase
p4 <- ggplot(df_trial, aes(x = actual_beep_phase_duration)) +
  geom_histogram(bins = 30, fill = "steelblue", color = "white") +
  facet_wrap(~trial_type)+
  #xlim(c(0,10))+
  geom_vline(xintercept = expected_beep_phase_duration, linetype = "dashed", color = "red", size = 1) +
  annotate("text", x = expected_beep_phase_duration, y = 0, label = "Expected Max Duration",
           color = "red",angle = 0, vjust = -0.7, size = 3) +
  labs(title = "Distribution of beep Phase Duration", x = "ISI Duration (s)", y = "Count") +
  theme_minimal()
print(p4)

# Plot 4: Beep Duration
p5 <- ggplot(df_trial, aes(x = actual_beep_duration)) +
  geom_histogram(bins = 30, fill = "steelblue", color = "white") +
  facet_wrap(~trial_type)+
  #xlim(c(0,10))+
  geom_vline(xintercept = expected_beep_duration, linetype = "dashed", color = "red", size = 1) +
  annotate("text", x = expected_beep_duration, y = 0, label = "Expected Max Duration",
           color = "red",angle = 0, vjust = -0.7, size = 3) +
  labs(title = "Distribution of beep duration", x = "ISI Duration (s)", y = "Count") +
  theme_minimal()
print(p5)

# Filter trials longer than 2.5 seconds
long_trials <- df_trial %>%
  filter(trial_duration > 4.5)
long_ISI <- df_trial %>% 
  filter(ISI_actual_duration > 2.5)
long_search_phase <- df_trial %>% 
  filter(actual_visual_search_duration > 2)

# 2) Pupil Dilation (PD) Data ----

## Misisng PD data

na_threshold <- 0.5 

# Summarize NA proportion per trial
trial_na_summary <- df_et %>%
  group_by(id, trial_number) %>%
  summarise(
    total_samples = n(),
    na_count = sum(is.na(pd)),
    na_prop = mean(is.na(pd)),
    .groups = "drop"
  )

# Inspect high-NA trials
high_na_trials <- trial_na_summary %>%
  filter(na_prop > na_threshold)

print(high_na_trials)

# Exclude trials with high NAs
df<- df_et %>%
  anti_join(high_na_trials, by = c("id", "trial_number"))

# Total trials before exclusion
total_trials <- nrow(trial_na_summary)

# Trials excluded for too many NAs
excluded_trials <- nrow(high_na_trials)

# Trials remaining after exclusion
remaining_trials <- total_trials - excluded_trials

percent_excluded <- (excluded_trials / total_trials) * 100
percent_remaining <- (remaining_trials / total_trials) * 100

cat(
  "NA filtering summary:\n",
  sprintf("Total trials: %d\n", total_trials),
  sprintf("Excluded trials (NA > %.2f): %d (%.2f%%)\n", na_threshold, excluded_trials, percent_excluded),
  sprintf("Remaining trials: %d (%.2f%%)\n\n", remaining_trials, percent_remaining)
)

# Mean proportion of NAs in excluded vs included trials
mean_na_excluded <- mean(high_na_trials$na_prop)
mean_na_included <- mean(trial_na_summary$na_prop[!(trial_na_summary$trial_number %in% high_na_trials$trial_number &
                                                      trial_na_summary$id %in% high_na_trials$id)])

cat(
  sprintf("Mean NA proportion in excluded trials: %.3f\n", mean_na_excluded),
  sprintf("Mean NA proportion in included trials: %.3f\n", mean_na_included)
)

# 3) Gaze positions ----
# Check if gaze columns exist
gaze_cols <- c("left_gaze_x", "right_gaze_x", "left_gaze_y", "right_gaze_y")
missing_gaze_cols <- setdiff(gaze_cols, names(df))

if(length(missing_gaze_cols) > 0) {
  cat("Warning: Missing gaze columns:", paste(missing_gaze_cols, collapse = ", "), "\n")
  cat("Available columns:", paste(names(df), collapse = ", "), "\n")
} else {
  # Calculate average gaze positions
  df$gaze_x_px <- (df$left_gaze_x + df$right_gaze_x) / 2
  df$gaze_y_px <- (df$left_gaze_y + df$right_gaze_y) / 2
  
  # Screen parameters
  monitor_width <- 2560
  monitor_height <- 1440
  half_width <- monitor_width / 2
  half_height <- monitor_height / 2
  
  cat("Gaze position summaries:\n")
  cat("X position: ")
  print(summary(df$gaze_x_px))
  cat("Y position: ")
  print(summary(df$gaze_y_px))
}

df_off_monitor <- df %>%
  filter(
    !is.na(gaze_x_px) & !is.na(gaze_y_px) &
      (abs(gaze_x_px) > half_width | abs(gaze_y_px) > half_height)
  )
df <- anti_join(df, df_off_monitor)
# Number of rows before exclusion
total_rows <- nrow(df) + nrow(df_off_monitor)  # because df already excludes df_off_monitor

# Number of rows excluded (off-monitor gaze)
excluded_rows <- nrow(df_off_monitor)

# Number of rows remaining after exclusion
remaining_rows <- nrow(df)

percent_excluded <- (excluded_rows / total_rows) * 100
percent_remaining <- (remaining_rows / total_rows) * 100

cat(
  "Off-monitor gaze exclusions (summary):\n",
  sprintf("Total samples: %d\n", total_rows),
  sprintf("Excluded samples (off-monitor): %d (%.2f%%)\n", excluded_rows, percent_excluded),
  sprintf("Remaining samples: %d (%.2f%%)\n", remaining_rows, percent_remaining)
)

ggplot(df, aes(x = pd)) +
  geom_histogram(
    bins = 30,                    # Number of bins
    fill = "steelblue",           # Fill color
    color = "black",              # Border color
    alpha = 0.7                   # Transparency
  ) +
  labs(
    title = "Distribution of Pupil Dilation",
    x = "Pupil Dilation in mm",
    y = "Frequency"
  ) +
  theme_minimal()


# 4) Area of Interest (AOI) ----

#Area of interest is defined as 500 px distance from the center, enclosing all four target positions

if(length(missing_gaze_cols) == 0) {
  # Filter valid gaze points within screen bounds
  df_valid <- df %>%
    filter(
      !is.na(gaze_x_px) & !is.na(gaze_y_px) &
        abs(gaze_x_px) <= (monitor_width / 2) &
        abs(gaze_y_px) <= (monitor_height / 2)
    )
  
  # AOI threshold (half-width/height of AOI box)
  aoi_threshold <- 500
  
  # Label AOI vs Offset
  df_valid <- df_valid %>%
    mutate(
      aoi_label = ifelse(
        abs(gaze_x_px) <= aoi_threshold & abs(gaze_y_px) <= aoi_threshold,
        "AOI", "Offset"
      ),
      gaze_distance = sqrt(gaze_x_px^2 + gaze_y_px^2),
      gaze_deviated = gaze_distance > aoi_threshold
    )
  
  # Summary counts and proportions
  aoi_table <- table(df_valid$aoi_label)
  cat("AOI Analysis Results:\n")
  print(aoi_table)
  cat("\nProportion in AOI vs Offset:\n")
  print(round(prop.table(aoi_table) * 100, 2))
  
  # Gaze distance descriptive stats
  cat("\nGaze distance summary:\n")
  print(summary(df_valid$gaze_distance))
  
  # Optional: proportion of gaze deviated
  prop_deviated <- mean(df_valid$gaze_deviated) * 100
  cat(sprintf("\nProportion of gaze points deviated from AOI in a circle boundary : %.2f%%\n", prop_deviated))
  
  total_samples <- nrow(df)
  valid_samples <- nrow(df_valid)
  excluded_samples <- total_samples - valid_samples
  percent_valid <- (valid_samples / total_samples) * 100
  percent_excluded <- 100 - percent_valid
  
  cat(
    "Exclusion of gaze data outside the center area (summary):\n",
    sprintf("Total samples: %d\n", total_samples),
    sprintf("Valid samples (within center screen area): %d (%.2f%%)\n", valid_samples, percent_valid),
    sprintf("Excluded samples (outside center screen area or NA): %d (%.2f%%)", excluded_samples, percent_excluded)
  )
}

df_aoi <- df_valid %>%
  filter(aoi_label == "AOI")

# Points outside the AOI circle
outside_circle <- df_aoi %>%
  filter(gaze_distance > aoi_threshold)

# Summary counts
total_aoi_points <- nrow(df_aoi)
outside_points <- nrow(outside_circle)
inside_points <- total_aoi_points - outside_points

percent_outside <- (outside_points / total_aoi_points) * 100
percent_inside <- 100 - percent_outside

cat(
  "AOI Circle Distance Summary (no exclusions here):\n",
  sprintf("Total AOI points: %d\n", total_aoi_points),
  sprintf("Inside circle (<= %.0f px): %d (%.2f%%)\n", aoi_threshold, inside_points, percent_inside),
  sprintf("Outside circle (> %.0f px): %d (%.2f%%)\n", aoi_threshold, outside_points, percent_outside)
)

# 5) Baseline PDs ----

# Summary statistics of the baseline means by trial and participant 

summary_stats <- df_aoi %>%
  group_by(id,trial_type) %>%
  summarise(
    mean = mean(mean_baseline_pd, na.rm = TRUE),
    median = median(mean_baseline_pd, na.rm = TRUE),
    sd = sd(mean_baseline_pd, na.rm = TRUE),
    min = min(mean_baseline_pd, na.rm = TRUE),
    max = max(mean_baseline_pd, na.rm = TRUE),
    n = sum(!is.na(mean_baseline_pd))
  )
# Print a nice formatted table
summary_stats %>%
  kable("html", caption = "Summary Statistics of Mean Baseline PD by Participant and Trial") %>%
  kable_styling(full_width = FALSE, bootstrap_options = c("striped", "hover", "condensed")) %>%
  column_spec(1:2, bold = TRUE)

ggplot(df_aoi, aes(x = factor(id), y = mean_baseline_pd)) +
  geom_boxplot(outlier.color = "red", fill = "skyblue", alpha = 0.7) +
  facet_wrap(~trial_type, scales = "free_x", ncol = 3) +  # Adjust columns for better layout
  labs(
    title = "Baseline Pupil Diameter by Trial",
    subtitle = "Boxplot of mean baseline pupil diameter across participants",
    x = "Participant ID",
    y = "Mean Baseline Pupil Diameter"
  ) +
  theme_minimal(base_size = 14) +  # Larger base font size for readability
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, color = "black", size = 10, face = "bold"),
    axis.title = element_text(face = "bold"),
    plot.title = element_text(face = "bold", size = 18, hjust = 0.5),
    plot.subtitle = element_text(size = 12, hjust = 0.5, margin = margin(b = 10)),
    strip.text = element_text(face = "bold", size = 12, color = "darkred"),
    panel.grid.major = element_line(color = "gray80"),
    panel.grid.minor = element_blank()
  )

# 6) Hits ----

# Get unique ID/Trial pairs from the cleaned data
valid_pairs <- df_aoi %>% 
  select(id, trial_number) %>% 
  distinct()

# Keep only rows that exist in the valid_pairs
df_trial_hits <- df_trial_hits %>% 
  semi_join(valid_pairs, by = c("id", "trial_number"))

df_trial_hits_only <- df_trial_hits_only %>% 
  semi_join(valid_pairs, by = c("id", "trial_number"))

# Overall hit rate
overall_hit_rate <- df_trial_hits[, .(
  total_trials = .N,
  total_hits = sum(hit),
  hit_rate = mean(hit)
), by = trial_type]

print(overall_hit_rate)

##  Hits (Absolute Hits / Hit Rate)

# Compute per-participant hit rates
hit_summary <- df_trial_hits %>%
  group_by(id, trial_type) %>%
  summarise(
    hits = sum(hit, na.rm = TRUE),
    total_trials = n(),
    hit_rate = hits / total_trials
  )

# Overall
total_hits <- sum(hit_summary$hits)
total_trials <- sum(hit_summary$total_trials)
overall_hit_rate <- total_hits / total_trials

cat("Total hits:", total_hits, "\n")
cat("Total trials:", total_trials, "\n")
cat("Overall hit rate:", round(overall_hit_rate * 100, 2), "%\n")

# Plot: Boxplot of hit rate by trial type
ggplot(hit_summary, aes(x = trial_type, y = hit_rate, fill = trial_type)) +
  geom_violin(alpha = 0.6) +
  geom_jitter(width = 0.2, alpha = 0.3) +
  labs(x = "Trial Type", y = "Hit Rate", title = "Hit Rate by Trial Type") +
  theme_minimal()

hit_rate_per_participant <- df_trial_hits %>%
  group_by(id) %>%
  summarise(
    total_trials = n(),
    hits = sum(hit, na.rm = TRUE),
    hit_rate = hits / total_trials
  )

# Summary statistics per trial type
hit_time_summary_stats <- df_trial_hits_only[, .(
  n = .N,
  mean = mean(hit_time),
  sd = sd(hit_time),
  median = median(hit_time),
  min = min(hit_time),
  max = max(hit_time),
  q25 = quantile(hit_time, 0.25),
  q75 = quantile(hit_time, 0.75)
), by = trial_type]

print(hit_time_summary_stats)

# Comprehensive summary (Participant-level view)
comprehensive_summary <- df_trial_hits[, .(
  n_participants = uniqueN(id),
  total_trials = .N,
  hit_rate = mean(hit),
  mean_hit_time = mean(hit_time[hit == 1], na.rm = TRUE),
  sd_hit_time = sd(hit_time[hit == 1], na.rm = TRUE),
  median_hit_time = median(hit_time[hit == 1], na.rm = TRUE)
), by = trial_type]

print(comprehensive_summary)


# Trial-level hit time distribution (Boxplot + Jitter)
p2 <- ggplot(df_trial_hits_only, aes(x = trial_type, y = hit_time, fill = trial_type)) +
  geom_boxplot(alpha = 0.7) +
  geom_jitter(alpha = 0.3, width = 0.2, size = 1) +
  labs(
    title = "Trial-Level Distribution of Hit Times",
    subtitle = "Each point = one trial | Shows within-condition variability across all participants",
    x = "Trial Type", 
    y = "Hit Time (seconds)"
  ) +
  theme_minimal() +
  theme(legend.position = "none")
print(p2)

# Re-calculating mean per participant for the plot
hit_time_participant_summary <- df_trial_hits_only %>%
  filter(hit == TRUE) %>%
  group_by(id, trial_type) %>%
  summarise(mean_hit_time = mean(hit_time, na.rm = TRUE), .groups = 'drop')

p3 <- ggplot(hit_time_participant_summary, aes(x = trial_type, y = mean_hit_time, fill = trial_type)) +
  geom_boxplot(alpha = 0.6) +
  geom_jitter(alpha = 0.4, width = 0.15, size = 2) +
  labs(
    x = "Trial Type", 
    y = "Mean Hit Time (s)", 
    title = "Participant-Level Mean Hit Times", 
    subtitle = "Each point = one participant’s mean hit time per condition"
  ) +
  theme_minimal()
print(p3)

# Check for implausibly fast (<200ms) or slow (>1.5s) responses
implausible_fast <- df_trial_hits_only[hit_time < 0.2]
implausible_slow <- df_trial_hits_only[hit_time > 1.5]

cat("\n--- Data Quality Check ---\n")
cat("Implausibly fast responses (<200ms):", nrow(implausible_fast), "\n")
cat("Implausibly slow responses (>1.5s):", nrow(implausible_slow), "\n")

# --- 3. Save as RDS (Recommended for R) ---
saveRDS(df_aoi,             file = paste0(home_path, data_path, "df_aoi_cleaned.rds"))
saveRDS(df_trial_hits,      file = paste0(home_path, data_path, "trial_hits_cleaned.rds"))
saveRDS(df_trial_hits_only, file = paste0(home_path, data_path, "trial_hits_only_cleaned.rds"))


