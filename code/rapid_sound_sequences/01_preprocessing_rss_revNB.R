################################################################################
#
# Rapid Sound Sequences Preprocessing
# Author: Iskra Todorova & Nico Bast
# Last Update: 26.03.2026
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

pkgs <- c("rhdf5",
          "data.table", # efficient due to parallelization
          "zoo", # used for na.approx
          "pbapply", # progress bar for apply functions
          "ggplot2", # creating graphs
          "dplyr",
          "tidyr") # for %>% operator

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


# install pupil preprocessing package from github
remotes::install_github("nicobast/PupilPreprocess")
require(PupilPreprocess)
#detach("package:PupilPreprocess", unload=T)


# PATHS

home_path <- "//192.168.88.212/daten/KJP_Studien"
project_path <- "/LOCUS_MENTAL/6_Versuchsdaten"
data_path <- "/LOCUS_MENTAL/6_Versuchsdaten/rapid_sound_sequences/"
data_path_et <- "/LOCUS_MENTAL/6_Versuchsdaten/rapid_sound_sequences/eyetracking"
data_path_trial <- "/LOCUS_MENTAL/6_Versuchsdaten/rapid_sound_sequences/trialdata"
datapath <- paste0(home_path, data_path) # .csv + .hdf5 input files
datapath_et <- paste0(home_path, data_path_et)
datapath_trial <- paste0(home_path, data_path_trial)
# List all .hdf and .csv files
data_files_et <- list.files(path = datapath_et, full.names = TRUE)
data_files_trial <- list.files(path = datapath_trial, full.names = TRUE)

# 1) Loading Data ----

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
id_names <- sub("rapid-sound-sequences_([A-Za-z]+_\\d+)_Pilot_.+\\.hdf5", "\\1", basename(data_files_et))

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
  "trial_start_time",
  "trial_end_time",
  "start_timestamp_0",
  "transition_timestamp_1",
  "end_timestamp_2",
  "timestamp_exp",
  "expected_stimulus_duration",
  "Stimulus_Duration",
  "nodata_stimulus",
  "gaze_offset_stimuli",
  "pause_stimulus",
  "Gaze_Offset_Cartoon_Duration",
  "nodata_cartoon_Duration",
  "Pause_cartoon_Duration",
  "Trial_Duration",
  "cartoon_start",
  "cartoon_actual_duration",
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
id_names <- sub("rapid-sound-sequences_([A-Za-z]+_\\d+)_Pilot_.+\\.csv", "\\1", basename(data_files_trial))

# Assign IDs to the list names
names(list_trial_data) <- id_names

# Add id to each data frame in list_trial_data
list_trial_data <- Map(function(df, id) {
  if (nrow(df) == 0) return(df)  # ignore empty trial files
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

unmatched_task
unmatched_et

names(list_trial_data)
names(list_et_data)

#reduce data files for participant with ET and task data
  # list_et_data<-list_et_data[!(names(list_et_data) %in% paste0(unmatched_et,'.hdf5'))]
  # list_trial_data<-list_trial_data[!(names(list_trial_data) %in% paste0(unmatched_task,'.csv'))]
list_et_data<-list_et_data[(names(list_et_data) %in% names(list_trial_data))]
list_trial_data<-list_trial_data[(names(list_trial_data) %in% names(list_et_data))]

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


#   2.4) Function for Labeling Trial Phases ----

label_phases_list <- function(df_list) {
  df_list <- lapply(df_list, function(df) {
    df <- df %>%
      mutate(
        # Convert to numeric to ensure comparisons work
        logged_time = as.numeric(logged_time), 
        start0 = as.numeric(start_timestamp_0),
        trans1 = as.numeric(transition_timestamp_1),
        end2   = as.numeric(end_timestamp_2),
        cart_s = as.numeric(cartoon_start)
      ) %>%
      mutate(
        trial_phase = case_when(
          # 1. Cartoon/ISI Phase
          logged_time >= cart_s & logged_time < start0 ~ "Cartoon_ISI",
          
          # 2. Control Conditions (Full 6s Sequence)
          Condition %in% c("REG10", "RAND20") & 
            logged_time >= start0 & logged_time <= end2 ~ "Sequence",
          
          # 3. Transition Conditions: Part 1
          Condition %in% c("RAND20-REG1", "RAND20-REG10", "REG10-RAND20") &
            logged_time >= start0 & logged_time < trans1 ~ "Sequence_Part1",
          
          # 4. Transition Conditions: Part 2
          Condition %in% c("RAND20-REG1", "RAND20-REG10", "REG10-RAND20") &
            logged_time >= trans1 & logged_time <= end2 ~ "Sequence_Part2",
          
          # Everything else
          TRUE ~ NA_character_
        )
      )
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
  x$ts_trial <- x$logged_time - x$timestamp_exp # time from trial start after ISI
  x$ts_sequence <- x$logged_time-x$start_timestamp_0 # time from sequence start till end of sequence, ISi excluded
  return(x)
})

#apply preprocessing for pd based on Pupil_Preprocess package
list_split_trial <- pblapply(
  list_split_trial, pupil_preprocessing,
  sampling_rate=60, provide_variable_names = T,
  left_diameter_name = 'left_pupil_measure1',
  right_diameter_name = 'right_pupil_measure1',
  timestamp_name = 'ts_sequence')


# Merge all trial-level data into one dataframe
df <- dplyr::bind_rows(list_split_trial)

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


# 4) Save Data ----

# ggplot(df, aes(x = ts_sequence, y = pd)) +
#   geom_smooth() +
#   theme_minimal() +
#   xlim(0,6)
 
# Save as RDS (preserves R attributes)
saveRDS(
  df_trial,
  file = paste0(datapath_trial,  "_rss_revNB.rds")
)
saveRDS(
  df,
  file = paste0(datapath_et,  "_rss_revNB.rds")
)

