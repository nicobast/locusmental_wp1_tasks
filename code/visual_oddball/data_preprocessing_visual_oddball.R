################################################################################
# 
# Visual Oddball Preprocessing
# Author: Iskra Todorova
# Last Update: 26.05.2025
# R Version: 4.4.2
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
#   2.2) Blink function
#   2.3) Pupil Dilation Preprocessing Function
# 3) Data Reshaping
#   3.1) Trial data and eye tracking data reshaping
#   3.2) Calculate Baseline Means
# 4)Pupil Response Preprocessing
#   4.1) Trial filtering and setup
#   4.2) Pupil response metrics and data merging
# 5) Saving Data
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
          "DescTools")

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
data_path <- "/LOCUS_MENTAL/6_Versuchsdaten/visual_oddball/"
data_path_et <- "/LOCUS_MENTAL/6_Versuchsdaten/visual_oddball//eyetracking"
data_path_trial <- "/LOCUS_MENTAL/6_Versuchsdaten/visual_oddball//trialdata"
datapath <- paste0(home_path, data_path) # .csv + .hdf5 input files
datapath_et <- paste0(home_path, data_path_et)
datapath_trial <- paste0(home_path, data_path_trial)
# List all .hdf and .csv files
data_files_et <- list.files(path = datapath_et, full.names = TRUE)
data_files_trial <- list.files(path = datapath_trial, full.names = TRUE)

# 1) Loading Data----
#   1.1) Load Eye Tracking Data ----

# Get eye tracking data and store in a list of df (one per subject)
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
id_names <- sub("visual-oddball_([A-Za-z]+_\\d+)_Pilot_.+\\.hdf5", "\\1", basename(data_files_et))

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

#   1.2) Load Trial Data ----

# Get trial data and store them in a list of df (one per subject)
data_files_trial <- data_files_trial[grepl(".csv", data_files_trial)]
list_trial_data <- list(0)

trial_variables <- c(
  "condition",
  "trial_number",
  "expected_baseline_fixation_duration",
  "baseline_fixation_actual_duration",
  "baseline_fixation_gaze_offset_duration",
  "baseline_fixation_nodata_duration",
  "timestamp_exp",
  "stimulus_start_timestamp",
  "stimulus_end_timestamp",
  "stimulus_duration",
  "ISI_start_timestamp",
  "ISI_end_timestamp",
  "nodata_stimulus",
  "gaze_offset_isi_duration",
  "nodata_isi_duration",
  "trial_duration",
  "actual_isi_duration",
  "expected_isi_duration",
  "ISI_duration_timestamp",
  "pause_isi_duration"
)

for (i in 1:length(data_files_trial)) {
  list_trial_data[[i]] <- fread(data_files_trial[i], select = trial_variables)
  print(paste0("read TRIAL data file: ", i))
}

list_trial_data <- lapply(list_trial_data, data.frame)

# Extract IDs from filenames
id_names <- sub("visual-oddball_([A-Za-z]+_\\d+)_Pilot_.+\\.csv", "\\1", basename(data_files_trial))

# Assign IDs to the list names
names(list_trial_data) <- id_names

# Add id to each data frame in list_trial_data
list_trial_data <- Map(function(df, id) {
  df$id <- id  # Add the id column
  return(df)
}, list_trial_data, id_names)

#   1.3) File Matching Check ----

# Check for .csv- + .hdf5- file matching (path-independent):
unmatched_et <- tools::file_path_sans_ext(basename(data_files_et))[
  !(tools::file_path_sans_ext(basename(data_files_et)) %in% tools::file_path_sans_ext(basename(data_files_trial)))]
unmatched_task <- tools::file_path_sans_ext(basename(data_files_trial))[
  !(tools::file_path_sans_ext(basename(data_files_trial)) %in% tools::file_path_sans_ext(basename(data_files_et)))]

# print unmatching files in console
cat(unmatched_task, "do not have a matching et file", sep = "\n") 
cat(unmatched_et, "do not have a matching trial file", sep = "\n")

#reduce data files for participant with ET and task data
#list_et_data<-list_et_data[!(names(list_et_data) %in% paste0(unmatched_et,'.hdf5'))]
#list_trial_data<-list_trial_data[!(names(list_trial_data) %in% paste0(unmatched_task,'.csv'))]

# 2) Functions ----
#   2.1) Merge eye tracking and trial ids, aligning with trial events ----

# Function only for the trials
fun_merge_all_ids <- function(et_data, trial_data) {
  # Time variables: eye tracking (logged_time) + trial data (timestamp_exp)
  start_ts <- trial_data$stimulus_start_timestamp # trial start
  end_ts <- trial_data$ISI_end_timestamp # trial end, replaced NA with max (et_data$logged_time, na.rm = TRUE)
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

# Function for the baseline fixation and final baseline fixation
fun_merge_baseline <- function(et_data, trial_data) {
  # Filter only baseline trials (999 and 666)
  trial_data_baseline <- trial_data %>% 
    dplyr::filter(trial_number %in% c(999, 666))
  
  if (nrow(trial_data_baseline) == 0) {
    return(NULL)
  }
  
  # Calculate start and end timestamps
  trial_data_baseline <- trial_data_baseline %>%
    dplyr::mutate(
      ts_1 = timestamp_exp,
      ts_2 = timestamp_exp + baseline_fixation_actual_duration
    )
  
  et_ts <- et_data$logged_time
  split_trial_data <- split(trial_data_baseline, seq(nrow(trial_data_baseline)))
  
  # Merge function using new time window
  fun_merge_data <- function(ts_1, ts_2, trial_data_splitted, et_ts) {
    matched_time <- which(et_ts >= ts_1 & et_ts <= ts_2)
    
    if (length(matched_time) == 0) {
      return(NULL)
    }
    
    selected_et_data <- et_data[matched_time, ]
    repeated_trial_data <- data.frame(
      sapply(trial_data_splitted, function(x) {
        rep(x, length(matched_time))
      }, simplify = FALSE))
    
    merged_data <- data.frame(repeated_trial_data, selected_et_data)
    return(merged_data)
  }
  
  df_baseline <- mapply(
    fun_merge_data,
    ts_1 = trial_data_baseline$ts_1,
    ts_2 = trial_data_baseline$ts_2,
    trial_data_splitted = split_trial_data,
    MoreArgs = list(et_ts = et_ts),
    SIMPLIFY = FALSE
  )
  
  df_baseline <- dplyr::bind_rows(df_baseline)
  return(df_baseline)
}

#   2.2) Blink function ----

# Blinks are defined as consecutive missing et data for 75–250 ms
# Need adjustments for Tobii Spark, sampling rate 60
# Sampling Interval = 1000/60 = 16.67
# lower threshold = 75/16.67 ~ 4.5 samples
# Upper threshold = 250 / 16.67 ~ 15 samples
# 8 samples * 16.67 ms per sample ≈ 133 ms

fun_blink_cor <- function(
    signal, lower_threshold = 5, upper_threshold = 15,
    samples_before = 8, samples_after = 8 ) { # should be changes as well?
  # Replace Na with 999
  findna <- ifelse(is.na(signal), 999, signal)
  repets <- rle(findna) # gives number of repetitions
  # Repeat number of repetition as often the value is
  repets <- rep(repets[["lengths"]], times = repets[["lengths"]])
  # 75 ms / 3,33 sampling interval = 23 samples (rows of et data)
  # 250 ms / 3,33 ms sampling interval = 75 samples (rows of eye tracking data)
  # If value is consecutively repeted >= 23 and <= 75, coding is "1", else "0"
  repets <- ifelse(repets >= lower_threshold & repets <= upper_threshold, 1, 0)
  # Repeated values other than Na are set to "0"
  repets[findna != 999 & repets == 1] <- 0
  # Differences between consecutive values indicate blink artefact bounderies
  changes <- c(diff(repets), 0)
  change_start <- which(changes == 1)
  # Blink sequence includes 8 samples before after blink, repectively.
  start_seq <- unlist(lapply(change_start, function(x) {
    seq(max(x - (samples_before - 1), 1), x)
  }
  ))
  repets[start_seq] <- 1
  changes_end <- which(changes == -1) + 1
  end_seq <- unlist(lapply(changes_end, function(x) {
    seq(x, min(x + (samples_before - 1), length(repets)))
  }
  ))
  repets[end_seq] <- 1
  # Data in blink interval is replaced with Na.
  signal[repets == 1] <- NA
  return(signal)
}

#   2.3) Pupil Dilation Preprocessing Function -----

func_pd_preprocess <- function(x) {
  left_diameter <- x$left_pupil_measure1
  right_diameter <- x$right_pupil_measure1
  remote_time <- x$ts_trial * 1000 # *1000 to convert s -> ms format
  # Pupil diameter outliers (< 2 mm or > 8 mm) are replaced with Na.
  pl <- ifelse((left_diameter < 2 | left_diameter > 8), NA, left_diameter)
  pr <- ifelse((right_diameter < 2 | right_diameter > 8), NA, right_diameter)
  # Dilation speed outliers: > constant * median change values are excluded
  constant <- 3
  # speed defined as movement / time
  # Dilatation speed for left eye
  pl_speed1 <- diff(pl) / diff(remote_time) # compared to previous et event
  pl_speed2 <- diff(rev(pl)) / diff(rev(remote_time)) # compared to next event
  pl_speed1 <- c(NA, pl_speed1)
  pl_speed2 <- c(rev(pl_speed2), NA)
  pl_speed <- pmax(pl_speed1, pl_speed2, na.rm = TRUE)
  rm(pl_speed1, pl_speed2)
  # Dilatation speed for right eye
  pr_speed1 <- diff(pr) / diff(remote_time) # compared to previous et event
  pr_speed2 <- diff(rev(pr)) / diff(rev(remote_time)) # compared to next event
  pr_speed1 <- c(NA, pr_speed1)
  pr_speed2 <- c(rev(pr_speed2), NA)
  pr_speed <- pmax(pr_speed1, pr_speed2, na.rm = TRUE)
  rm(pr_speed1, pr_speed2)
  # Threshold (in mm/ms): dilation speed median + 3 * median absolute deviation
  # Left eye
  pl_speed_med <- median(pl_speed, na.rm = TRUE)
  pl_mad <- median(abs(pl_speed - pl_speed_med), na.rm = TRUE)
  pl_treshold_speed <- pl_speed_med + constant * pl_mad
  # Right eye
  pr_speed_med <- median(pr_speed, na.rm = TRUE)
  pr_mad <- median(abs(pr_speed - pr_speed_med), na.rm = TRUE)
  pr_treshold_speed <- pr_speed_med + constant * pr_mad
  # Replace pupil data higher than threshold with Na
  pl <- ifelse(abs(pl_speed) > pl_treshold_speed, NA, pl)
  pr <- ifelse(abs(pr_speed) > pr_treshold_speed, NA, pr)
  # Calling function for blink correction
  pl <- fun_blink_cor(pl)
  pr <- fun_blink_cor(pr)
  # Two pass approach. 1st pass: Exclude deviation from trend
  # line derived from all samples. 2nd pass: Exclude deviation from trend
  # line derived from samples passing. Reintroduction of sample that might
  # have been falsely excluded due to outliers estimate smooth size based
  # on sampling rate
  smooth_length <- 150 # in ms
  # take sampling rate into account (300 vs. 120):
  smooth_size <- round(
    smooth_length / median(diff(remote_time), # remote_time is ts_trial in ms
                           na.rm = TRUE))
  is_even <- function(x) {
    x %% 2 == 0
  }
  smooth_size <- ifelse(
    is_even(smooth_size) == TRUE,
    smooth_size + 1, smooth_size) # odd values for runmed()-function
  # for left and right eye:
  # giving the smooth function Na would raise an error
  pl_smooth <- na.approx(pl, na.rm = FALSE, rule = 2)
  # Robust Scatter Plot Smoothing
  if (sum(!is.na(pl_smooth)) != 0) {
    pl_smooth <- runmed(pl_smooth, k = smooth_size)
  }
  pl_mad <- median(abs(pl - pl_smooth), na.rm = TRUE)
  # Giving the smooth function Na would raise an error
  pr_smooth <- na.approx(pr, na.rm = FALSE, rule = 2)
  # Robust Scatter Plot Smoothing
  if (sum(!is.na(pr_smooth)) != 0) {
    pr_smooth <- runmed(pr_smooth, k = smooth_size)
  }
  pr_mad <- median(abs(pr - pr_smooth), na.rm = TRUE)
  # correct pupil dilation for size outliers - 1st pass
  pl_pass1 <- ifelse(
    (pl > pl_smooth + constant * pl_mad) | (pl < pl_smooth - constant * pl_mad),
    NA, pl)
  pr_pass1 <- ifelse(
    (pr > pr_smooth + constant * pr_mad) | (pr < pr_smooth - constant * pr_mad),
    NA, pr)
  # for left and right eye:
  # giving the smooth function Na would raise an error
  pl_smooth <- na.approx(pl_pass1, na.rm = FALSE, rule = 2)
  # Robust Scatter Plot Smoothing
  if (sum(!is.na(pl_smooth)) != 0) {
    pl_smooth <- runmed(pl_smooth, k = smooth_size)
  }
  pl_mad <- median(abs(pl - pl_smooth), na.rm = TRUE)
  # Giving the smooth function Na would raise an error
  pr_smooth <- na.approx(pr_pass1, na.rm = FALSE, rule = 2)
  # Robust Scatter Plot Smoothing
  if (sum(!is.na(pr_smooth)) != 0) {
    pr_smooth <- runmed(pr_smooth, k = smooth_size)
  }
  pr_mad <- median(abs(pr - pr_smooth), na.rm = TRUE)
  # correct pupil dilation for size outliers - 2nd pass
  pl_pass2 <- ifelse(
    (pl > pl_smooth + constant * pl_mad) | (pl < pl_smooth - constant * pl_mad),
    NA, pl)
  pr_pass2 <- ifelse(
    (pr > pr_smooth + constant * pr_mad) | (pr < pr_smooth - constant * pr_mad),
    NA, pr)
  pl <- pl_pass2
  pr <- pr_pass2
  # Fill Na with offset value
  pd_offset <- pl - pr
  pd_offset <- na.approx(pd_offset, rule = 2)
  pl <- ifelse(is.na(pl) == FALSE, pl, pr + pd_offset)
  pr <- ifelse(is.na(pr) == FALSE, pr, pl - pd_offset)
  # Interpolation of missing values < 300 ms
  pl <- na.approx(pl, na.rm = FALSE, maxgap = 90, rule = 2)
  pr <- na.approx(pr, na.rm = FALSE, maxgap = 90, rule = 2)
  # mean pupil dilation across both eyes
  pd <- (pl + pr) / 2
  x[, "pd"] <- pd
  return(x)
}

# 3) Data reshaping ----

#   3.1) Trial data and eye tracking data reshaping----

# Assign Baseline Trial Numbers
list_trial_data <- lapply(list_trial_data, function(df_trial) {
  df_trial$trial_number <- ifelse(df_trial$condition =="baseline_fixation", 999, df_trial$trial_number)
  df_trial$trial_number <- ifelse(df_trial$condition =="final_baseline_fixation", 666, df_trial$trial_number)
  return(df_trial)
})

# Combine all trial data
df_trial <- plyr::rbind.fill(list_trial_data)

# Merge Eye-Tracking and Trial Data

# Merge each participant’s trial and ET data
df_list <- pbmapply(
  fun_merge_all_ids,
  et_data = list_et_data,
  trial_data = list_trial_data, SIMPLIFY = FALSE)

# Remove empty/mismatched entries
df_list<-df_list[sapply(df_list,function(x){length(x)!=0})]

# Convert from participant-level to trial-level lists
list_split_trial <- unlist(
  pblapply(df_list, function(x) split(x, x$trial_number)),
  recursive = FALSE
)

# Add ts_trial and preprocess pd
# New variable ts_trial: elapsed time from the beginnig of trial(timnestamp_exp) to specific event (logged_time)
# ts_trial is an interval in seconds
# timestamp_exp represents the timestamp at the beginning of each trial/the start of the stimulus
list_split_trial <- pblapply(list_split_trial, function(x) {
  x$ts_trial <- x$logged_time - x$timestamp_exp
  x <- func_pd_preprocess(x)
  return(x)
})

# Combine all data first (more efficient than processing trial by trial)
df_all <- rbindlist(list_split_trial, fill = TRUE)

# Convert to data.table for efficient processing
setDT(df_all)

# Rearrange variables
setcolorder(df_all, c("id", "trial_number", "condition", "ts_trial", "pd"))

# df back up
df_backup <- df_all

#   3.2) Baseline correction using last 250ms of ISI ----

# Set baseline window parameters
baseline_duration <- 0.250  # 250ms in seconds

# Calculate trial-wise baseline correction
# Step 1: Get ISI end timestamps for each trial
trial_info <- df_all[, .(
  ISI_end = unique(ISI_end_timestamp)[1],
  stimulus_start = unique(stimulus_start_timestamp)[1]
), by = .(id, trial_number)]

# Step 2: Define baseline window (last 250ms of ISI)
trial_info[, `:=`(
  baseline_start = ISI_end - baseline_duration,
  baseline_end = ISI_end
)]

# Step 3: Merge baseline info back to main data
df_all <- merge(df_all, trial_info, by = c("id", "trial_number"), all.x = TRUE)

# Step 4: Calculate baseline PD for each trial (using last 250ms of ISI)
baseline_pds <- df_all[
  logged_time >= baseline_start & logged_time <= baseline_end,
  .(baseline_pd = mean(pd, na.rm = TRUE)),
  by = .(id, trial_number)
]

# Step 5: Shift baseline to next trial (baseline for trial N is calculated from trial N-1)
baseline_pds[, trial_number := trial_number + 1]

# Step 6: Merge baseline PD back to main data
df_all <- merge(df_all, baseline_pds, by = c("id", "trial_number"), all.x = TRUE)

# Step 7: Remove first trial for each participant (no baseline available)
df_all <- df_all[trial_number != 1]

#   3.3) Calculate stimulus-evoked pupil responses (SEPR) ----

# CALCULATE RAW PERIOD AVERAGES

# LOW period: 0–250 ms from trial start
pd_low <- df_all[ts_trial >= 0 & ts_trial <= 0.25,
                 .(pd_low = mean(pd, na.rm = TRUE)),
                 by = .(id, trial_number)]

# HIGH period: 500–1400 ms from trial start  
pd_high <- df_all[ts_trial >= 1 & ts_trial <= 1.6,
                  .(pd_high = mean(pd, na.rm = TRUE)),
                  by = .(id, trial_number)]

# Merge period averages to main data
df_all <- merge(df_all, pd_low, by = c("id", "trial_number"), all.x = TRUE)
df_all <- merge(df_all, pd_high, by = c("id", "trial_number"), all.x = TRUE)

# BASELINE CORRECTION

# Correct LOW and HIGH periods for baseline
df_all[, corr_pd_low := pd_low - baseline_pd]
df_all[, corr_pd_high := pd_high - baseline_pd]

# Apply baseline correction to all timepoints
df_all[, baseline_corr_pd := pd - baseline_pd]

# CALCULATE RELATIVE PUPIL DILATION (RPD)

# RPD = corrected HIGH - corrected LOW
df_all[, RPD := corr_pd_high - corr_pd_low]

# Calculate trial-level averages
trial_level <- df_all[
  , .(
    mean_baseline_pd = unique(baseline_pd),
    pd_low = unique(pd_low),
    pd_high = unique(pd_high),
    corr_pd_low = unique(corr_pd_low),
    corr_pd_high = unique(corr_pd_high),
    RPD = unique(RPD)
  ), 
  by = .(id, trial_number, condition)  
]

df_trial_all <- merge(df_trial, trial_level, by = c("id", "trial_number", "condition"), all.x = TRUE)
df_trial_all <- as.data.table(df_trial_all)

vars_to_remove <- c("final_baseline_fixation", "baseline_fixation")
df_trial_all <- df_trial_all[trial_number != 1]
df_trial_all[, (vars_to_remove) := NULL]

#   3.4) Calculate Global Baseline Fixation Means----

# Create df of global baseline fixation at start and end separately
# Merge global baseline 
df_baseline_list <- pbmapply(fun_merge_baseline,
                             et_data = list_et_data,
                             trial_data = list_trial_data,
                             SIMPLIFY = FALSE)

# Drop empty elements
df_baseline_list <- df_baseline_list[sapply(df_baseline_list, function(x) !is.null(x))]

# Add ts_trial and pd
df_baseline_list <- lapply(df_baseline_list, function(df) {
  df$ts_trial <- df$logged_time - df$timestamp_exp
  func_pd_preprocess(df)
})
df_baselines <- bind_rows(df_baseline_list)
setDT(df_baselines)

# Compute global baseline means per participant
baseline_means <- df_baselines[
  condition == "baseline_fixation",
  .(baseline_mean = mean(pd, na.rm = TRUE)),
  by = id
]

# Compute final baseline per participant 
final_baseline_means <- df_baselines[
  condition == "final_baseline_fixation",
  .(final_baseline_mean = mean(pd, na.rm = TRUE)),
  by = id
]

#   3.7) Clean up and prepare final datasets ----

# Remove unnecessary variables
vars_to_remove <- c("baseline_fixation_actual_duration", "baseline_fixation_gaze_offset_duration",
                    "expected_baseline_fixation_duration", "baseline_fixation_nodata_duration",
                    "baseline_start", "baseline_end", "ts_from_stimulus")

# Remove columns if they exist
vars_to_remove <- vars_to_remove[vars_to_remove %in% names(df_all)]
if(length(vars_to_remove) > 0) {
  df_all[, (vars_to_remove) := NULL]
}
# Remove columns if they exist
vars_to_remove <- vars_to_remove[vars_to_remove %in% names(df_trial_all)]
if(length(vars_to_remove) > 0) {
  df_trial_all[, (vars_to_remove) := NULL]
}
# Create final clean datasets
df_all <- df_all[order(id, trial_number, logged_time)]
df_trial_all <- df_trial_all[order(id, trial_number)]

# 4) Save processed data ----

# Save all datasets
saveRDS(df_trial_all, file = paste0(datapath_trial, "_processed.rds"))
saveRDS(df_all, file = paste0(datapath_et, "_processed.rds"))
saveRDS(df_baselines, file = paste0(datapath_et, "_baseline.rds"))
saveRDS(baseline_means, file = paste0(datapath_et, "_global_baseline_means.rds"))



# VISUALIZATION
# Plot baseline-corrected time series
p1 <- ggplot(df_all, aes(x = ts_trial, y = baseline_corr_pd , color = condition)) +
  geom_smooth() +
  xlim(c(0,2))+
  labs(title = "Baseline-Corrected Pupil Dilation Over Time",
       x = "Time from Trial Start (s)",
       y = "Baseline-Corrected PD") +
  theme_minimal()

print(p1)

# STATISTICAL ANALYSIS
# Ensure trial is properly factored with reference level
df_trial_all[, trial := relevel(as.factor(condition), ref = "oddball")]

# Fit mixed-effects model
model <- lmer(corr_pd_high ~ condition + (1 | id), data = df_trial_all)
anova(model)

# Model diagnostics
plot(model)
qqnorm(resid(model)); qqline(resid(model))
