################################################################################
# 
# Cued  Visual Search Preprocessing
# Author: Iskra Todorova
# Last Update: 02.10.2025
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
# Outline:
# 1) Loading Data
#   1.1) Load Eye Tracking Data
#   1.2) Load Trial Data
#   1.3) File Matching Check
# 2) Functions
#   2.1) Merge eye tracking and trial ids, aligning with trial events
# 3) Data Reshaping
#   3.1) Trial data and eye tracking data reshaping
#   3.2) Calculate Baseline Means
# 4)Pupil Response Preprocessing
#   4.1) Trial filtering and setup
#   4.2) Summary and analysis
# 5) Target/Hit
#   5.1) Preprocessing
#   5.2) Analysis
# 6) Saving Data
#
################################################################################

## SETUP ####

sessionInfo()

# REQUIRED PACKAGES

pkgs <- c("rhdf5",
          "data.table", # efficient due to parallelization
          "zoo", # used for na.approx
          "pbapply", # progress bar for apply functions
          "ggplot2", # creating graphs
          "dplyr",# for %>% operator
          "DescTools",
          "PupilPreprocess",
          "lme4",
          "emmeans",
          "lmerTest")

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


# PATHS

home_path <- "S:/KJP_Studien"
project_path <- "LOCUS_MENTAL/6_Versuchsdaten"
data_path <- "/LOCUS_MENTAL/6_Versuchsdaten/visual_search_task/"
data_path_et <- "/LOCUS_MENTAL/6_Versuchsdaten/visual_search_task/eyetracking"
data_path_trial <- "/LOCUS_MENTAL/6_Versuchsdaten/visual_search_task/trialdata"
datapath <- paste0(home_path, data_path) # .csv + .hdf5 input files
datapath_et <- paste0(home_path, data_path_et)
datapath_trial <- paste0(home_path, data_path_trial)
# List all .hdf and .csv files
data_files_et <- list.files(path = datapath_et, full.names = TRUE)
data_files_trial <- list.files(path = datapath_trial, full.names = TRUE)

# 1) Loading Data----

#   1.1) Load Eye Tracking Data----
data_files_et <- data_files_et[grepl(".hdf5", data_files_et)]

list_et_data <- list(0)
for (i in 1:length(data_files_et)) {
  print(paste0("now reading: ", data_files_et[i]))
  list_et_data[[i]] <- h5read(
    file = data_files_et[i],
    name = "data_collection/events/eyetracker/BinocularEyeSampleEvent")
}
h5closeAll()

# List names for each subject are unique including date and time of recording.

# Extract IDs from file names
id_names <- sub("cued-visual-search_([A-Za-z]+_\\d+)_Pilot_.+\\.hdf5", "\\1", basename(data_files_et))

# Assign IDs to the list names
names(list_et_data) <- id_names

# These eye tracker variables are being dropped, keeping variables
# left_pupil_measure1, right_pupil_measure1, logged_time,
# left_gaze_x and left_gaze_y.
constant_variables <- c(
  "experiment_id",
  "status",
  "session_id",
  "device_id",
  "type",
  "device_time",
  "time",
  "delay",
  "confidence_interval",
  "filter_id",
  "left_gaze_z", "right_gaze_z",
  "left_angle_x", "right_angle_x",
  "left_angle_y", "right_angle_y",
  "left_raw_x", "right_raw_x",
  "left_raw_y", "right_raw_y",
  "left_pupil_measure1_type", "right_pupil_measure1_type",
  "left_pupil_measure2_type", "right_pupil_measure2_type",
  "left_ppd_x", "right_ppd_x",
  "left_ppd_y", "right_ppd_y",
  "left_velocity_x", "right_velocity_x",
  "left_velocity_y", "right_velocity_y",
  "left_velocity_xy", "right_velocity_xy",
  "left_pupil_measure2", "right_pupil_measure2",
  "left_eye_cam_x", "right_eye_cam_x",
  "left_eye_cam_y", "right_eye_cam_y",
  "left_eye_cam_z", "right_eye_cam_z"
)

list_et_data <- lapply(
  list_et_data, function(x) {
    x[!(names(x) %in% constant_variables)]})


#   1.2) Load Trial Data----
data_files_trial <- data_files_trial[grepl(".csv", data_files_trial)]
list_trial_data <- list(0)

trial_variables <- c(
  "trial_number",
  "base_color",
  "target_color",
  "target_position",
  "target_position_index",
  "baseline_fixation_start_timestamp",
  "baseline_fixation_end_timestamp",
  "baseline_fixation_duration",
  "baseline_fixation_actual_isi_duration",
  "baseline_fixation_gaze_offset_duration",
  "baseline_fixation_nodata_duration",
  "baseline_fixation_pause_duration",
  "timestamp_exp",
  "trial_start_timestamp",
  "trial_end_timestamp",
  "trial_duration",
  "ISI_start_timestamp",
  "ISI_end_timestamp",
  "ISI_Gaze_Offset_Duration",
  "ISI_nodata_Duration",
  "ISI_Pause_Duration",
  "ISI_expected",
  "ISI_duration_timestamp",
  "ISI_actual_duration",
  "auditory_cue",
  "beep_phase_start_timestamp",
  "beep_phase_end_timestamp",
  "beep_start_timestamp",
  "beep_end_timestamp",
  "actual_beep_duration",
  "expected_beep_duration",
  "nodata_beep_interval",
  "actual_beep_phase_duration",
  "delay_beep_phase",
  "actual_visual_search_duration",
  "nodata_visual_search"
)

for (i in 1:length(data_files_trial)) {
  list_trial_data[[i]] <- fread(data_files_trial[i], select = trial_variables)
  print(paste0("read TRIAL data file: ", i))
}

list_trial_data <- lapply(list_trial_data, data.frame)

# Extract IDs from filenames
id_names <- sub("cued-visual-search_([A-Za-z]+_\\d+)_Pilot_.+\\.csv", "\\1", basename(data_files_trial))

# Assign IDs to the list names
names(list_trial_data) <- id_names

# Add id to each data frame in list_trial_data
list_trial_data <- Map(function(df, id) {
  df$id <- id  # Add the id column
  return(df)
}, list_trial_data, id_names)


#   1.3) File Matching Check----
# Check for .csv- + .hdf5- file matching (path-independent):
unmatched_et <- tools::file_path_sans_ext(basename(data_files_et))[
  !(tools::file_path_sans_ext(basename(data_files_et)) %in% tools::file_path_sans_ext(basename(data_files_trial)))]
unmatched_task <- tools::file_path_sans_ext(basename(data_files_trial))[
  !(tools::file_path_sans_ext(basename(data_files_trial)) %in% tools::file_path_sans_ext(basename(data_files_et)))]

# print unmatching files in console
cat(unmatched_task, "do not have a matching et file", sep = "\n") 
cat(unmatched_et, "do not have a matching trial file", sep = "\n")

#reduce data files for participant with ET and task data
list_et_data<-list_et_data[!(names(list_et_data) %in% paste0(unmatched_et,'.hdf5'))]
list_trial_data<-list_trial_data[!(names(list_trial_data) %in% paste0(unmatched_task,'.csv'))]

# 2) Functions ----
 
#   2.1) Merge eye tracking and trial ids, aligning with trial events ----

fun_merge_all_ids <- function(et_data, trial_data) {
  # Time variables: eye tracking (logged_time) + trial data (timestamp_exp)
  start_ts <- trial_data$timestamp_exp # trial start
  end_ts <- c(trial_data$timestamp_exp[-1], max(et_data$logged_time, na.rm = TRUE)) # trial end, replaced NA with max (et_data$logged_time, na.rm = TRUE)
  et_ts <- et_data$logged_time  # Define et_ts here
  split_trial_data <- split(trial_data, seq(nrow(trial_data)))
  
  # Pass et_ts as an argument to fun_merge_data
  fun_merge_data <- function(ts_1, ts_2, trial_data_splitted, et_ts) { # added et_ts to make it accessible inside the nested function fun_merge_data
    matched_time <- which(et_ts >= ts_1 & et_ts <= ts_2)  # added equal sign et_ts <= ts_2 for the last trial to be included
    
    # Skip if no matching eye-tracking data is found
    if (length(matched_time) == 0) {
      return(NULL)
    }
    
    # For all other trials (rapid sound sequence)
    selected_et_data <- et_data[matched_time, ] # et data for trial duration
    # trial data: 1 row == 1 trial -> is repeated for each eye tracking event
    repeated_trial_data <- data.frame(
      sapply(trial_data_splitted, function(x) {
        rep(x, length(matched_time))}, simplify = FALSE))
    # Add ts_1 and ts_2 to the merged data
    merged_data <- data.frame(repeated_trial_data, selected_et_data, ts_1 = ts_1, ts_2 = ts_2)
  }
  
  print(paste0("merge: ", unique(trial_data$id))) #debugging print
  
  # Pass et_ts to mapply
  df_one_id <- mapply(
    fun_merge_data,
    ts_1 = start_ts,
    ts_2 = end_ts,
    trial_data_splitted = split_trial_data,
    MoreArgs = list(et_ts = et_ts),  # Pass et_ts here
    SIMPLIFY = FALSE)
  
  df_one_id <- dplyr::bind_rows(df_one_id) # faster than rbind.fill
}

# 3) Data Reshaping ----

#   3.1) Trial data and eye tracking data reshaping ----

# Combine trial data
# Merge all trial-level data (from list of dataframes) into one dataframe
# Input:  list_trial_data (list of trial metadata per participant)
# Output: df_trial (single combined dataframe)
df_trial <- plyr::rbind.fill(list_trial_data)

# For each participant, merge raw eye-tracking samples with their corresponding trial events
# Uses fun_merge_all_ids() to handle time-window matching
# Input:  list_et_data (raw eye tracking) + list_trial_data (trial timestamps)
# Output: df_list (list of merged dataframes, one per participant)
df_list <- pbmapply(
  fun_merge_all_ids,
  et_data = list_et_data,
  trial_data = list_trial_data, SIMPLIFY = FALSE)

# Cleanup: Remove empty list elements (participants with no matched data)
df_list<-df_list[sapply(df_list,function(x){length(x)!=0})]

# Bind trials together to a df
df <- dplyr::bind_rows(df_list)

df_list<- lapply(df_list, function(trial) {
  trial$trial_type <- ifelse(trial$auditory_cue, "cued", "standard")
  return(trial)
})
#  Assign trial_number = 999 for baseline trials in df_list
df_list <- lapply(df_list, function(x) {
  x$trial_number <- ifelse(x$trial_type == "baseline", 999, x$trial_number)
  return(x)
})

# Convert from participant-level to trial-level lists
# Input:  df_list (participant-level data)
# Output: list_split_trial (list where each element = one trial's data)
list_split_trial <- pblapply(df_list, function(x) {
  split(x, x$trial_number)})
list_split_trial <- unlist(list_split_trial, recursive = FALSE)

# New variable ts_trial: elapsed time from the beginnig of trial(timnestamp_exp) to specific event (logged_time)
# ts_trial is an interval in seconds
list_split_trial <- pblapply(list_split_trial, function(x) {
  x$ts_trial <- x$logged_time - x$beep_phase_start_timestamp
  x$ts_search <- x$logged_time - x$beep_phase_end_timestamp
  return(x)
})


# ts_search time from the start of the search phase
#list_split_trial <- pblapply(list_split_trial, function(x) {
#  x$ts_search <- x$logged_time - x$beep_phase_end_timestamp
#  return(x)
#})

#apply preprocessing for pd based on Pupil_Preprocess package
list_split_trial <- pblapply(
  list_split_trial, pupil_preprocessing, 
  sampling_rate=60, provide_variable_names = T,
  left_diameter_name = 'left_pupil_measure1',
  right_diameter_name = 'right_pupil_measure1',
  timestamp_name = 'ts_trial')

# Create a trial type varible
list_trial_data <- lapply(list_trial_data, function(trial) {
  trial$trial_type <- ifelse(trial$auditory_cue, "cued", "standard")
  return(trial)
})

# Assign trial_type based on baselinefixation_start_timestamp
list_trial_data <- lapply(list_trial_data, function(trial) {
  trial$trial_type <- ifelse(!is.na(trial$baseline_fixation_start_timestamp),
                             "baseline",                       # if baseline timestamp exists
                             ifelse(trial$auditory_cue, "cued", "standard"))  # otherwise cued/standard
  return(trial)
})

#  Assign trial_number = 999 for baseline trials in list_trial_data
list_trial_data<- lapply(list_trial_data, function(x) {
  x$trial_number <- ifelse(x$trial_type == "baseline", 999, x$trial_number)
  return(x)
})

#  Assign trial_number = 999 for baseline trials in list_trial_data
list_trial_data<- lapply(list_trial_data, function(x) {
  x$trial_number <- ifelse(x$trial_type == "baseline", 999, x$trial_number)
  return(x)
})


# Bind trials together to a df
df <- dplyr::bind_rows(list_split_trial)

#   3.2) Calculate Values for PD Correction ----

# Convert df to data.table 
setDT(df)

summary(df$logged_time)
summary(df$ISI_start_timestamp)
summary(df$ISI_end_timestamp)

# Filter for only ISI interval and create ts_trial_ISI
df_ISI <- df[
  logged_time >= ISI_start_timestamp & logged_time <= ISI_end_timestamp
]

setDT(df_ISI)

# Relative time from ISI start
df_ISI[, ts_trial_ISI := logged_time - ISI_start_timestamp]

# Add ts_trial_ISI to the entire df dataset
df[, ts_trial_ISI := logged_time - ISI_start_timestamp]

ggplot(df_ISI, aes(x = ts_trial_ISI, y = pd, group = trial_type, color = trial_type)) +
  geom_smooth() +
  #xlim(c(0,5))+
  labs(
    x = "Time in Trial (s)",
    y = "Pupil Diameter",
    color = "Trial Type",
    title = "Pupil Diameter Across Trials"
  ) +
  theme_minimal()

hist(df_ISI$ISI_duration_timestamp)

# BASELINE CORRECTION (ISI-based)
# Trial-wise baseline correction. Define baseline time window for each trial, last 250 ms from the ISI of the previous trial

# Set baseline window length
baseline_duration <- 0.250

# Get trial-level ISI end times and calculate baseline windows
trial_baselines <- df_ISI[
  , .(ISI_end = unique(ISI_end_timestamp)[1]), 
  by = .(id, trial_number)
][
  , `:=`(
    baseline_start = ISI_end - baseline_duration,
    baseline_end = ISI_end
  )
]

# Join baseline windows to full data
df_with_baseline <- merge(df, trial_baselines,
                          by = c("id", "trial_number"),
                          all.x = TRUE)

# Calculate baseline PD for each trial (from ISI period)
baseline_pds <- df_with_baseline[
  logged_time >= baseline_start & logged_time <= baseline_end,
  .(mean_baseline_pd = mean(pd, na.rm = TRUE)),
  by = .(id, trial_number)
]

#check plausibility of baseline values
ggplot(baseline_pds,aes(x=trial_number,y=mean_baseline_pd))+geom_smooth()
ggplot(baseline_pds,aes(x=trial_number,y=mean_baseline_pd,group=id,color=id))+geom_smooth()

# Merge baseline values back to main data
df <- merge(df, baseline_pds, by = c("id", "trial_number"), all.x = TRUE)

# 4) Pupil Response ------
#   4.1) Corrected PDs ----

# baseline corrected PD
df[, pd_corr := pd - mean_baseline_pd]

ggplot(df,aes(x=ts_trial,y=pd_corr, group = trial_type, color = trial_type))+geom_smooth()+xlim(c(0,2))

# Cued evoked pupil response and SEPR
df[, CEPR := ifelse(ts_trial>= 0.4 & ts_trial <= 0.6, pd_corr, NA_real_)]
df[, SEPR := ifelse(ts_trial>= 1.125 & ts_trial <= 1.8, pd_corr, NA_real_)]


#   4.2) Summary and analysis ----

# CREATE TRIAL-LEVEL SUMMARY
# Calculate trial-level averages
trial_level <- df[
  , .(
    mean_baseline_pd = mean(mean_baseline_pd, na.rm = TRUE),
    mean_CEPR = mean(CEPR, na.rm = TRUE),
    mean_SEPR = mean(SEPR, na.rm = TRUE)
    # RPD_short = mean(RPD_short, na.rm = TRUE)
  ), 
  by = .(id, trial_number, trial_type)  
]

library(lmerTest)
library(emmeans)
# Cue-Evoked Pupil Response
m1 <- lmer(mean_CEPR ~ trial_type + (1|id), data = trial_level)
anova(m1)
# SEPR
m2 <- lmer(mean_SEPR ~ trial_type + (1|id), data = trial_level)
anova(m2)
emm <- emmeans(m2, pairwise ~ trial_type, adjust = "tukey")
print(emm)


# 5) Target/Hit  -----
#   5.1) Preprocessing ----

# Circle positions relative to screen center
circle_positions <- data.frame(
  position_index = 0:3,
  position_name = c("top", "right", "bottom", "left"),
  center_x = c(0, 400, 0, -400),    
  center_y = c(400, 0, -400, 0)     
)

circle_radius <- 100  # Adjust if needed, adding a tolerance of 20 px?

# Function to get target center coordinates
get_target_center <- function(position_index) {
  pos <- circle_positions[circle_positions$position_index == position_index, ]
  return(list(
    center_x = pos$center_x,
    center_y = pos$center_y
  ))
}

trial_id <- unique(df$trial_number)[1]
trial_data <- df[trial_number == trial_id]

target_center <- get_target_center(trial_data$target_position_index[1])

ggplot(trial_data, aes(x = left_gaze_x, y = left_gaze_y)) +
  geom_point(color = "blue", alpha = 0.5) +
  geom_point(aes(x = target_center$center_x, y = target_center$center_y),
             color = "red", size = 5) +
  annotate("path",
           x = target_center$center_x + circle_radius * cos(seq(0, 2*pi, length.out=100)),
           y = target_center$center_y + circle_radius * sin(seq(0, 2*pi, length.out=100)),
           color = "red") +
  coord_fixed()

# Check if gaze is inside target (left eye)
df[, left_gaze_inside_target := {
  target_center <- get_target_center(target_position_index)
  distance_squared <- (left_gaze_x - target_center$center_x)^2 + 
    (left_gaze_y - target_center$center_y)^2
  distance_squared <= circle_radius^2 & 
    !is.na(left_gaze_x) & !is.na(left_gaze_y)
}, by = .(target_position_index)]


# Check if gaze is inside target (right eye)
df[, right_gaze_inside_target := {
  target_center <- get_target_center(target_position_index)
  distance_squared <- (right_gaze_x - target_center$center_x)^2 + 
    (right_gaze_y - target_center$center_y)^2
  distance_squared <= circle_radius^2 & 
    !is.na(right_gaze_x) & !is.na(right_gaze_y)
}, by = .(target_position_index)]

# Combined gaze (either eye inside target)
df[, any_gaze_inside_target := left_gaze_inside_target | right_gaze_inside_target]

# Detect hits in a trial - ONLY for search phase samples
detect_hit <- function(trial_data, consecutive = 8) {
  # FILTER: Only use samples during search phase
  search_samples <- trial_data$ts_search >= 0 & 
    trial_data$ts_search <= trial_data$search_duration[1]
  
  # If no valid search samples, return no hit
  if (sum(search_samples, na.rm = TRUE) < consecutive) {
    return(list(hit = FALSE, hit_time = NA_real_))
  }
  
  # Filter to search phase only
  inside <- trial_data$any_gaze_inside_target[search_samples]
  times <- trial_data$ts_search[search_samples]  # Already relative to search start
  
  n <- length(inside)
  
  for (i in seq_len(n - consecutive + 1)) {
    if (isTRUE(inside[i]) && all(inside[i:(i + consecutive - 1)])) {
      # times is already ts_search (relative to search start)
      hit_time <- times[i]
      return(list(hit = TRUE, hit_time = hit_time))
    }
  }
  
  return(list(hit = FALSE, hit_time = NA_real_))
}


# Calculate search duration before applying detect_hit
df[, search_duration := trial_end_timestamp - beep_phase_end_timestamp]

# Apply per subject & trial
trial_hits <- df[, {
  res <- detect_hit(.SD, consecutive = 8)
  .(hit = res$hit, 
    hit_time = res$hit_time,
    search_duration = unique(search_duration))
}, by = .(id, trial_number, trial_type, target_position)]

# Verify results
summary(trial_hits$hit_time)
summary(trial_hits$search_duration)

# Check for any invalid hit times (should be none)
invalid <- trial_hits[hit == TRUE & (hit_time < 0 | hit_time > search_duration)]
if(nrow(invalid) > 0) {
  print("WARNING: Invalid hit times found:")
  print(invalid)
} else {
  print("All hit times are valid!")
}


#   5.2) Analysis ---- 

# First, filter to only include trials with hits
trial_hits_only <- trial_hits[hit == TRUE]

# Check  data
summary(trial_hits_only$hit_time)
table(trial_hits_only$trial_type)

# Summary by condition
desc_stats <- trial_hits_only[, .(
  n_trials = .N,
  mean_hit_time = mean(hit_time, na.rm = TRUE),
  sd_hit_time = sd(hit_time, na.rm = TRUE),
  median_hit_time = median(hit_time, na.rm = TRUE)
), by = trial_type]

print(desc_stats)

# By participant and condition
desc_by_id <- trial_hits_only[, .(
  n_trials = .N,
  mean_hit_time = mean(hit_time, na.rm = TRUE),
  sd_hit_time = sd(hit_time, na.rm = TRUE)
), by = .(id, trial_type)]

print(desc_by_id)

# Individual participant lines
ggplot(desc_by_id, aes(x = trial_type, y = mean_hit_time, group = id, color = id)) +
  geom_line() +
  geom_point() +
  labs(
    x = "Trial Type",
    y = "Mean Hit Time (seconds)",
    title = "Individual Participant Performance"
  ) +
  theme_minimal()

# Basic model: hit_time predicted by trial_type with random intercept for participant, absolute hit values
m_hit <- lmer(scale(hit_time) ~ trial_type + (1|id), data = trial_hits_only)
anova(m_hit)
emm_hit <- emmeans(m_hit, pairwise ~ trial_type, adjust = "tukey")
print(emm_hit)
# currently not signifikant 

# Check assumptions
plot(m_hit)  # residuals vs fitted
qqnorm(resid(m_hit))  # normality of residuals
qqline(resid(m_hit))

# add target positions to basic model
m_hit_position <- lmer(scale(hit_time) ~ trial_type + target_position +  (1|id), 
                       data = trial_hits_only)
anova(m_hit_position)

emm_hit_position <- emmeans(m_hit_position, ~ target_position)
print(emm_hit_position)
pairs(emm_hit_position)
# signifikant, top position faster response
# check colors as well ?

# Hit Rate pro Participant und Trial Type
hit_rate_summary <- trial_hits[, .(
  n_trials = .N,
  n_hits = sum(hit),
  hit_rate = mean(hit),
  se = sd(hit)/sqrt(.N)
), by = .(id, trial_type)]

print(hit_rate_summary)

# Generalized Linear Mixed Model (binomial family)
# probability of a Hit
m_hit_rate <- glmer(hit ~ trial_type + (1|id), 
                    data = trial_hits, 
                    family = binomial(link = "logit"))

summary(m_hit_rate)

emm_hit_rate <- emmeans(m_hit_rate, pairwise ~ trial_type, type = "response")
print(emm_hit_rate)
# nothing interesting

# Add target position
m_hit_rate_pos <- glmer(hit ~ trial_type + target_position + (1|id), 
                        data = trial_hits, 
                        family = binomial(link = "logit"))

summary(m_hit_rate_pos)
anova(m_hit_rate_pos)

# Compare models
anova(m_hit_rate, m_hit_rate_pos)

# Visualization
ggplot(hit_rate_summary, aes(x = trial_type, y = hit_rate, fill = trial_type)) +
  geom_boxplot() +
  geom_jitter(width = 0.2, alpha = 0.5) +
  labs(
    x = "Trial Type",
    y = "Hit Rate (Proportion)",
    title = "Hit Rate by Trial Type"
  ) +
  theme_minimal()
# 6) Save Data ------

# Save all datasets
saveRDS(df_trial, file = paste0(datapath_trial, "_processed.rds"))
saveRDS(df, file = paste0(datapath_et, "_processed.rds"))
saveRDS(trial_hits, file = paste0(datapath_et, "_trial_hits.rds"))
saveRDS(trial_hits_only, file = paste0(datapath_et, "_trial_hits_only.rds"))

#---