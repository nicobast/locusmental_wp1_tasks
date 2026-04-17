################################################################################
#
# Visual Oddball Preprocessing
# Author: Iskra Todorova & Nico Bast
# Last Update: 17.04.2026
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

# install pupil preprocessing package from github
#remotes::install_github("nicobast/PupilPreprocess")
require(PupilPreprocess)
#detach("package:PupilPreprocess", unload=T)

#instal rhdf5 from Bioconductor repository as not available for R4.5 form CRAN
if (!requireNamespace("BiocManager", quietly = TRUE))
  install.packages("BiocManager")
BiocManager::install("rhdf5")
require(rhdf5)

# PATHS

#home_path <- "S:/KJP_Studien"
home_path <- "//192.168.88.212/daten/KJP_Studien"
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
  "trial_type",
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
  if (nrow(df) == 0) return(df) # ignore empty file
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
list_et_data<-list_et_data[(names(list_et_data) %in% names(list_trial_data))]
list_trial_data<-list_trial_data[(names(list_trial_data) %in% names(list_et_data))]

# 2) Functions ----
# Merge eye tracking and trial ids, aligning with trial events ----

#  2.1) Function only for the trials
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
    return(merged_data)
  }

  print(paste0("merge: ", unique(trial_data$id[1]))) #debugging print

  # Pass et_ts to mapply
  df_one_id <- mapply(
    fun_merge_data,
    ts_1 = start_ts,
    ts_2 = end_ts,
    trial_data_splitted = split_trial_data,
    MoreArgs = list(et_ts = et_ts),  # Pass et_ts here
    SIMPLIFY = FALSE)

  df_one_id <- dplyr::bind_rows(df_one_id) # faster than rbind.fill
  return(df_one_id)
}

# 2.2.) Function for the baseline fixation and final baseline fixation
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

# 3) Data reshaping ----

#   3.1) Trial data and eye tracking data reshaping----

# Assign Baseline Trial Numbers for the start and end baseline fixations
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
# stimulus_start_timestamp represents the timestamp at the beginning of the start of the stimulus
list_split_trial <- pblapply(list_split_trial, function(x) {
  x$ts_trial <- x$logged_time - x$stimulus_start_timestamp
  return(x)
})

#apply preprocessing for pd based on Pupil_Preprocess package
list_split_trial <- pblapply(
  list_split_trial, pupil_preprocessing,
  sampling_rate=60, provide_variable_names = T,
  left_diameter_name = 'left_pupil_measure1',
  right_diameter_name = 'right_pupil_measure1',
  timestamp_name = 'ts_trial')

# Combine all data first (more efficient than processing trial by trial)
df_all <- rbindlist(list_split_trial, fill = TRUE)

# Convert to data.table for efficient processing
setDT(df_all)

# Rearrange variables
setcolorder(df_all, c("id", "trial_number", "condition", "ts_trial", "pd"))

# df back up
df_backup <- df_all

# Repair missing condition
# For 2 Participants 027 and 078 we have backup files the condition variable is not filled with trial type values,
# they have all empty values but we have a variable trial_type that stores the values
# Transfer trial_type values into the condition variable
df_empty_condition <- df_all[condition == ""]
df_empty_condition[, .(n_unique_trials = uniqueN(trial_number)), by = id]
df_all[condition == "" & !is.na(trial_type),
       condition := trial_type]

# check if it worked
df_all[condition == "" | is.na(condition),
       .N,
       by = id]
df_all[is.na(condition) | condition == "", .N]
df_all[, .N, by = condition][order(-N)]

#   3.2) Calculate trial baseline using the first 250ms of the trial----

# Set baseline window parameters
baseline_duration <- 0.250  # 250ms in seconds

# Calculate trial-wise baseline correction
trial_baseline_pds <- df_all[
  ts_trial >= 0 &
    ts_trial < baseline_duration,
  .(baseline_pd = mean(pd, na.rm = TRUE)),
  by = .(id, trial_number)
]

trial_baseline_pds <- trial_baseline_pds[!is.na(baseline_pd)]

# diagnostic check: sample counts per trial; should be around 15 samples
df_all[
  ts_trial >= 0 &
    ts_trial < baseline_duration,
  .(n_samples = .N),
  by = .(id, trial_number)
]

#check plausibility of baseline values
ggplot(trial_baseline_pds,aes(x=trial_number,y=baseline_pd))+geom_smooth()
ggplot(trial_baseline_pds,aes(x=trial_number,y=baseline_pd,group=id,color=id))+geom_smooth()+xlim(c(0,10))

#  Merge baseline with df_all
df_all <- merge(
  df_all,
  trial_baseline_pds,
  by = c("id", "trial_number"),
  all.x = TRUE
)

ggplot(df_all,aes(x=ts_trial,y=pd,group=condition,color=condition))+geom_smooth()#+xlim(c(0,2))
# there are trials that last very long, over 80 s. So take a look at those and exclude everything that is over 2 seconds in the next steps

# merge with trial data
df_trial <- merge(
  df_trial,
  trial_baseline_pds,
  by = c("id", "trial_number"),
  all.x = TRUE
)

#   3.3) Long trials ----

CUTOFF <- 2  # seconds

df_trial <- df_trial %>%
  mutate(
    #repair missing condition
    condition = ifelse(condition == "" & !is.na(trial_type), trial_type, condition),
    is_baseline = condition %in% c("baseline_fixation", "final_baseline_fixation"),
    is_long_trial = !is_baseline & trial_duration > CUTOFF
  )

# Keep only clean trials
df_trial_clean <- df_trial %>% filter(!is_long_trial)
df_all_clean <- df_all %>%
  semi_join(df_trial_clean, by = c("id", "trial_number"))

# Overview
df_trial %>%
  count(condition, is_long_trial) %>%
  group_by(condition) %>%
  mutate(pct = round(100 * n / sum(n), 1)) %>%
  print()
# => 25% of each condition has a trial longer than 2s

# Quick check
cat("Rows in df_all before:", nrow(df_all), "\n")
cat("Rows in df_all after: ", nrow(df_all_clean), "\n")

ggplot(df_all_clean[df_all_clean$ts_trial<1.5,],aes(x=ts_trial,y=pd,group=condition,color=condition))+geom_smooth() #+xlim(c(0,2))

#   3.4) Calculate stimulus-evoked pupil responses (SEPR/RPD) ----

setDT(df_all_clean)
# Calculate pd corrected for each sample
df_all_clean[, pd_corr := pd - baseline_pd]

# HIGH period: 1 to 2 s from trial start
sepr <- df_all_clean[ts_trial >= 1 & ts_trial <= 2,
                  .(rpd = mean(pd_corr, na.rm = TRUE)),
                  by = .(id, trial_number)]

# Merge to main data
df_all_clean <- merge(df_all_clean, sepr, by = c("id", "trial_number"), all.x = TRUE)
df_trial_all <- merge(df_trial, sepr, by = c("id", "trial_number"), all.x = TRUE)

#   3.4) Global Baseline ----

# Create df of global baseline fixation at start and end separately
# Merge global baseline
global_baseline_list <- pbmapply(fun_merge_baseline,
                             et_data = list_et_data,
                             trial_data = list_trial_data,
                             SIMPLIFY = FALSE)

# Drop empty elements
global_baseline_list <- global_baseline_list[sapply(global_baseline_list, function(x) !is.null(x))]

# Add ts_trial and pd
global_baseline_list <- pblapply(global_baseline_list, function(df) {

  # Skip empty elements
  if (is.null(df) || nrow(df) == 0) {
    return(NULL)
  }

  # Create trial-relative timestamp
  df$ts_trial <- df$logged_time - df$timestamp_exp

  # Apply pupil preprocessing
  df_processed <- pupil_preprocessing(
    df,
    sampling_rate = 60,
    provide_variable_names = TRUE,
    left_diameter_name  = "left_pupil_measure1",
    right_diameter_name = "right_pupil_measure1",
    timestamp_name      = "ts_trial"
  )

  return(df_processed)

})

global_baselines <- bind_rows(global_baseline_list)
setDT(global_baselines)

# Compute global baseline means per participant
baseline_means <- global_baselines[
  condition == "baseline_fixation",
  .(start_baseline_mean = mean(pd, na.rm = TRUE)),
  by = id
]

# Compute final baseline per participant
final_baseline_means <- global_baselines[
  condition == "final_baseline_fixation",
  .(final_baseline_mean = mean(pd, na.rm = TRUE)),
  by = id
]

#   3.7) Clean up and prepare final datasets ----

setDT(df_trial_all)
# Remove baseline trials
df_trial_all <- df_trial_all[!condition %in% c("baseline_fixation", "final_baseline_fixation")]
# Remove unnecessary variables
vars_to_remove <- c("baseline_fixation_actual_duration", "baseline_fixation_gaze_offset_duration",
                    "expected_baseline_fixation_duration", "baseline_fixation_nodata_duration",
                    "baseline_start", "baseline_end", "ts_from_stimulus")

# Remove columns if they exist
vars_to_remove <- vars_to_remove[vars_to_remove %in% names(df_all_clean)]
if(length(vars_to_remove) > 0) {
  df_all_clean[, (vars_to_remove) := NULL]
}
# Remove columns if they exist
setDT(df_trial_clean)
vars_to_remove <- vars_to_remove[vars_to_remove %in% names(df_trial_clean)]
if(length(vars_to_remove) > 0) {
  df_trial_clean[, (vars_to_remove) := NULL]
}
# Create final clean datasets
df_all <- df_all_clean[order(id, trial_number, logged_time)]
df_trial_all <- df_trial_clean[order(id, trial_number)]


# 4) Save processed data ----

# Save all datasets

saveRDS(df_trial_all, file = paste0(datapath_trial, "_processed.rds"))
saveRDS(df_all, file = paste0(datapath_et, "_processed.rds"))
saveRDS(global_baselines, file = paste0(datapath_et, "_baseline.rds"))
saveRDS(baseline_means, file = paste0(datapath_et, "_global_baseline_means.rds"))
saveRDS(final_baseline_means, file = paste0(datapath_et, "_final_baseline_means.rds"))

