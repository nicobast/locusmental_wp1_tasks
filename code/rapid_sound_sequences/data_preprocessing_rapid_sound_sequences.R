################################################################################
# 
# Rapid Sound Sequences Preprocessing
# Author: Iskra Todorova
# Last Update: 16.05.2025
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
# 1) Loadind Data
#   1.1) Load Eye Tracking Data
#   1.2) Load Trial Data
#   1.3) File Matching Check
# 2) Functions
#   2.1) Merge eye tracking and trial ids, aligning with trial events
#   2.2) Blink function
#   2.3) Pupil Dilation Preprocessing Function
#   2.4) Function for Labeling Trial Phases
# 3) Data Reshaping
#   3.1) Trial data and eye tracking data reshaping
#   3.2) Calculate Baseline Means
# 4)Pupil Response Preprocessing
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
          "dplyr") # for %>% operator

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

home_path <- "C:/Users/iskra_todorova"
project_path <- "PowerFolders/R-Project-Locus-Mental/LOCUS-MENTAL"
data_path <- "/PowerFolders/R-Project-Locus-Mental/LOCUS-MENTAL/data/rapid_sound_sequences/"
data_path_et <- "/PowerFolders/R-Project-Locus-Mental/LOCUS-MENTAL/data/rapid_sound_sequences/eyetracking"
data_path_trial <- "/PowerFolders/R-Project-Locus-Mental/LOCUS-MENTAL/data/rapid_sound_sequences/trialdata"
datapath <- paste0(home_path, data_path) # .csv + .hdf5 input files
datapath_et <- paste0(home_path, data_path_et)
datapath_trial <- paste0(home_path, data_path_trial)
# List all .hdf and .csv files
data_files_et <- list.files(path = datapath_et, full.names = TRUE)
data_files_trial <- list.files(path = datapath_trial, full.names = TRUE)

# 1) Preparing Data ----

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
id_names <- sub("rapid-sound-sequences_(\\d+)_Test_.+\\.hdf5", "\\1", basename(data_files_et))

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

# Get trial data and store in a list of df (one per subject)
data_files_trial <- data_files_trial[grepl(".csv", data_files_trial)]

list_trial_data <- list(0)

trial_variables <- c(
  "Condition",
  "Trial Number",
  "baseline_fixation_start_timestamp",
  "baseline_fixation_end_timestamp",
  "baseline_fixation_duration",
  "baseline_fixation_gaze_offset_duration",
  "baseline_fixation_nodata_duration",
  "start_timestamp_0",
  "transition_timestamp_1",
  "end_timestamp_2",
  "timestamp_exp",
  "Stimulus_Duration",
  "nodata_stimulus",
  "gaze_offset_stimuli",
  "ISI_Gaze_Offset_Duration",
  "ISI_nodata_Duration",
  "Trial_Duration",
  "ISI_actual_duration",
  "num_repetitions",
  "rep_1",
  "rep_2",
  "rep_3",
  "rep_4",
  "rep_5",
  "rep_6",
  "rep_7",
  "rep_8",
  "rep_9",
  "rep_10",
  "rep_11",
  "rep_12",
  "REG1 Frequency"
)

for (i in 1:length(data_files_trial)) {
  list_trial_data[[i]] <- fread(data_files_trial[i], select = trial_variables)
  print(paste0("read TRIAL data file: ", i))
}

list_trial_data <- lapply(list_trial_data, data.frame)

# Extract IDs from filenames
id_names <- sub("rapid-sound-sequences_(\\d+)_Test_.+\\.csv", "\\1", basename(data_files_trial))

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
list_et_data<-list_et_data[!(names(list_et_data) %in% paste0(unmatched_et,'.hdf5'))]
list_trial_data<-list_trial_data[!(names(list_trial_data) %in% paste0(unmatched_task,'.csv'))]

# 2) Functions -----

#   2.1) Merge eye tracking and trial ids, aligning with trial events ----

# This function merges only the eye-tracking data during the stimulus sequences,
# based on explicitly defined start and end timestamps for each stimulus segment

fun_merge_all_ids_stimulus <- function(et_data, trial_data) {
  # Time variables: eye tracking (logged_time) + trial data (timestamp_exp)
  start_ts <- trial_data$start_timestamp_0 # trial start timestamp
  end_ts <- trial_data$end_timestamp_2 # trial end timestamp
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

# This function uses experiment timestamps to merge all available eye-tracking data across the full trial duration,
# including baseline, ISI, and stimulus periods.
# If you are planning to use the global baselines ans ISI for calculations apply this one
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

#   2.3) Pupil Dilation Preprocessing Function ----

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

#   2.4) Function for Labeling Trial Phases ----

label_phases_list <- function(df_list) {
  # Apply the labeling function to each data frame in the list
  df_list <- lapply(df_list, function(df) {
    df <- df %>%
      group_by(id, Condition, Trial.Number) %>%
      mutate(
        
        trial_phase = case_when(
          logged_time < start_timestamp_0 ~ "ISI",
          Condition %in% c("RAND20-REG1", "RAND20-REG10", "REG10-RAND20") &
            !is.na(transition_timestamp_1) &
            logged_time >= start_timestamp_0 & logged_time < transition_timestamp_1 ~ "Sequence Part 1",
          Condition %in% c("RAND20-REG1", "RAND20-REG10", "REG10-RAND20") &
            !is.na(transition_timestamp_1) &
            logged_time >= transition_timestamp_1 & logged_time < end_timestamp_2 ~ "Sequence Part 2",
          Condition %in% c("REG10", "RAND20") &
            logged_time >= start_timestamp_0 & logged_time < end_timestamp_2 ~ "Sequence",
          # Labeling phases based on timestamps
          Condition == "BASELINE"~ NA_character_,
          TRUE ~ NA_character_
        )
      ) %>%
      # Explicitly filter out NAs for calculations of min/max
      mutate(
        # Start and End of "Sequence"
        trial_phase = ifelse(
          logged_time == min(logged_time[!is.na(logged_time) & trial_phase == "Sequence"], na.rm = TRUE), 
          "Start of Sequence", trial_phase),
        trial_phase = ifelse(
          logged_time == max(logged_time[!is.na(logged_time) & trial_phase == "Sequence"], na.rm = TRUE), 
          "End of Sequence", trial_phase),
        
        # Start and End of "Sequence Part 1"
        trial_phase = ifelse(
          logged_time == min(logged_time[!is.na(logged_time) & trial_phase == "Sequence Part 1"], na.rm = TRUE), 
          "Start of Sequence Part 1", trial_phase),
        trial_phase = ifelse(
          logged_time == max(logged_time[!is.na(logged_time) & trial_phase == "Sequence Part 1"], na.rm = TRUE), 
          "End of Sequence Part 1", trial_phase),
        
        # Start and End of "Sequence Part 2"
        trial_phase = ifelse(
          logged_time == min(logged_time[!is.na(logged_time) & trial_phase == "Sequence Part 2"], na.rm = TRUE), 
          "Start of Sequence Part 2", trial_phase),
        trial_phase = ifelse(
          logged_time == max(logged_time[!is.na(logged_time) & trial_phase == "Sequence Part 2"], na.rm = TRUE), 
          "End of Sequence Part 2", trial_phase),
        
        # Insert "Transition" between last Sequence Part 1 and first Sequence Part 2
        trial_phase = ifelse(
          logged_time == max(logged_time[!is.na(logged_time) & trial_phase == "Sequence Part 1"], na.rm = TRUE) |
            logged_time == min(logged_time[!is.na(logged_time) & trial_phase == "Sequence Part 2"], na.rm = TRUE), 
          "Transition", trial_phase)
      ) %>%
      ungroup()
    
    return(df)
  })
  
  return(df_list)
}

# 3) Data reshaping ----

#   3.1) Trial data and eye tracking data reshaping ----

# Assigning BASELINE to condition and its Trail Number Value 999
list_trial_data <- lapply(list_trial_data, function(df_trial) {
  # Add "BASELINE" to Condition if baseline_fixation_start_timestamp is not NA
  df_trial$Condition <- ifelse(!is.na(df_trial$baseline_fixation_start_timestamp), "BASELINE", df_trial$Condition)
  
  # Assign 999 to Trial.Number for BASELINE
  df_trial$Trial.Number <- ifelse(!is.na(df_trial$baseline_fixation_start_timestamp), 999, df_trial$Trial.Number)
  
  # Return the modified data frame
  return(df_trial)
})

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
  fun_merge_all_ids_stimulus, # for global baseline or ISI calculations use the fun_merge_all_ids
  et_data = list_et_data,
  trial_data = list_trial_data, SIMPLIFY = FALSE)

# Cleanup: Remove empty list elements (participants with no matched data)
df_list<-df_list[sapply(df_list,function(x){length(x)!=0})]

# Add phase variable
df_list <- label_phases_list(df_list)

# Convert from participant-level to trial-level lists
# Input:  df_list (participant-level data)
# Output: list_split_trial (list where each element = one trial's data)
list_split_trial <- pblapply(df_list, function(x) {
  split(x, x$Trial.Number)})
list_split_trial <- unlist(list_split_trial, recursive = FALSE)

# New variable ts_trial: elapsed time from the beginnig of trial(timnestamp_exp) to specific event (logged_time)
# ts_trial is an interval in seconds
list_split_trial <- pblapply(list_split_trial, function(x) {
  x$ts_trial <- x$logged_time - x$timestamp_exp
  return(x)
})

# Apply custom preprocessing for pd
list_split_trial <- pblapply(
  list_split_trial, func_pd_preprocess)

# Merge all trial-level data into one dataframe
df <- dplyr::bind_rows(list_split_trial)

# create time interval variable counting from the begin of the sequence, current ts_trial counts fromn the trial start(e.g. ISI)
df <-df %>% 
  mutate(ts_sequence=logged_time- as.numeric(start_timestamp_0))

# create variable condition type for visualizations
df <- df %>%
  mutate(
    condition_type = case_when(
      Condition == "RAND20" ~ "control",
      Condition == "REG10" ~ "control",
      Condition != "NA" ~ "transition",  # Assign "control" to other cases (excluding NA)
      TRUE ~ NA_character_  # Keep NA as is if it's already NA
    )
  )

# create variable initial_sequence type for visualizations
df <- df %>%
  mutate(
    initial_sequence = case_when(
      Condition == "RAND20-REG1" ~ "RAND",
      Condition == "RAND20-REG10" ~ "RAND",
      Condition == "RAND20" ~ "RAND",
      Condition == "REG10-RAND20" ~ "REG",
      Condition == "REG10" ~ "REG",
      Condition != "NA" ~ "transition",  # Assign "control" to other cases (excluding NA)
      TRUE ~ NA_character_  # Keep NA as is if it's already NA
    )
  )

# convert transition timestamp to numeric for further calculations
df$transition_timestamp_1 <- as.numeric(df$transition_timestamp_1)

# create transition timepoint varible based on transitoin timestamp, for control trials a pseudo transition set at the 3rd second of the trial
df <- df %>%
  mutate(
    transition_time_trial = case_when(
      !is.na(transition_timestamp_1) & is.finite(transition_timestamp_1) ~ as.numeric(transition_timestamp_1) - as.numeric(start_timestamp_0),  # Valid transition
      Condition %in% c("REG10", "RAND20") ~ 3,  # Simulate transition at 5s for these conditions
      TRUE ~ NA_real_  # For other cases, return NA
    )
  )

# create logical variables to use for calculating the change in corrected pd After vs. Before transition
df <- df %>%
  mutate(
    before_window = ts_sequence >= (transition_time_trial - 3) & ts_sequence < transition_time_trial,
    after_window = ts_sequence >= transition_time_trial & ts_sequence <= (transition_time_trial + 3)
  )
# delete baseline columns
df <- df %>% select(-starts_with("baseline"))

#   3.2) Calculate Baseline Means ----

# Baseline Calculations based on the first second from Stimulus onset

stimulus_baseline <- df %>%
  group_by(id, Condition, Trial.Number) %>% 
  filter(logged_time >= start_timestamp_0 & logged_time < (start_timestamp_0 + 1))%>% 
  ungroup()

# Calculate baseline means (only once)
baseline_means<- stimulus_baseline %>%
  group_by(id, Condition, Trial.Number) %>%
  summarize(baseline_mean = mean(pd, na.rm = TRUE)) %>%
  ungroup()

# Visualization of baseline means distribution
ggplot(baseline_means, aes(x = "", y = baseline_mean)) +
  geom_boxplot(width = 0.3, fill = "lightgray") +
  geom_jitter(aes(color = id), width = 0.1, size = 3) +
  labs(title = "Distribution of Baseline PD Means",
       x = NULL,
       y = "Mean PD (mm)") +
  theme_minimal()

# Add baseline to df and pd_corrected
df <- df %>%
  left_join(baseline_means, by = c("id", "Condition", "Trial.Number")) %>%
  mutate(pd_corrected = pd - baseline_mean)

# remove Condition BASELINE from df_trial
df_trial <- df_trial %>% 
  filter(Condition != "BASELINE")

# Add baseline to df_trial and pd_corrected
df_trial <- df_trial %>%
  left_join(baseline_means, by = c("id", "Condition", "Trial.Number")) 


# 4) Pupil Data preprocessing -----

# Calculate 2 s before and After transition pdr (with correction)
pd_change <- df %>%
  group_by(id, Condition, Trial.Number) %>%
  summarise(
    pd_before = mean(pd_corrected[before_window], na.rm = TRUE),
    pd_after = mean(pd_corrected[after_window], na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(pd_change = pd_after - pd_before)  # Compute the change

#Plot
ggplot(pd_change, aes(x = Condition, y = pd_change, fill = Condition)) +
  geom_boxplot() +
  theme_minimal() +
  ggtitle("Change in Corrected Pupil Dilation Before vs. After Transition") +
  ylab("Pupil Dilation Change (After - Before)") +
  xlab("Condition")

# merge to df
df <- df %>%
  left_join(pd_change, by = c("id", "Condition", "Trial.Number"))

df_trial <- df_trial %>%
  left_join(pd_change, by = c("id", "Condition", "Trial.Number"))


# 5) Data Saving -----

# Optional: Save as RDS (preserves R attributes)
saveRDS(
  df_trial,
  file = paste0(datapath_trial,  "_rss.rds")
)
saveRDS(
  df,
  file = paste0(datapath_et,  "_rss.rds")
)

