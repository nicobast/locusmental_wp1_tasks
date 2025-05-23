################################################################################
# 
# Auditory Oddball Preprocessing
# Author: Iskra Todorova
# Last Update: 08.05.2025
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

home_path <- "C:/Users/iskra_todorova"
project_path <- "PowerFolders/R-Project-Locus-Mental/LOCUS-MENTAL"
data_path <- "/PowerFolders/R-Project-Locus-Mental/LOCUS-MENTAL/data/auditory_oddball/"
data_path_et <- "/PowerFolders/R-Project-Locus-Mental/LOCUS-MENTAL/data/auditory_oddball/eyetracking"
data_path_trial <- "/PowerFolders/R-Project-Locus-Mental/LOCUS-MENTAL/data/auditory_oddball/trialdata"
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
  #print(paste0("completed reading: ", data_files_et[i]))
 }
h5closeAll()

# List names for each subject are unique including date and time of recording.
# Extract IDs from file names
id_names <- sub("auditory-oddball_(\\d+)_Test_.+\\.hdf5", "\\1", basename(data_files_et))

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
  "phase",
  "stimulus_duration",
  "baseline_trial_counter",
  "trial",
  "timestamp_exp",
  "oddball_trial_counter",
  "ISI_duration",
  "gaze_offset_duration",
  "trial_nodata_duration",
  "oddball_frequency",
  "standard_frequency"
  )

for (i in 1:length(data_files_trial)) {
  list_trial_data[[i]] <- fread(data_files_trial[i], select = trial_variables)
  print(paste0("read TRIAL data file: ", i))
  }
list_trial_data <- lapply(list_trial_data, data.frame)

# Extract IDs from file names
id_names <- sub("auditory-oddball_(\\d+)_Test_.+\\.csv", "\\1", basename(data_files_trial))

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

# Eye tracking data (logged_time) are assigned to trials (timestamp_exp).
# Before it needs to be checked that trial data matches to ET data
fun_merge_all_ids <- function(et_data, trial_data) {
  # Time variables: eye tracking (logged_time) + trial data (timestamp_exp)
  start_ts <- trial_data$timestamp_exp # trial start
  end_ts <- dplyr::lead(start_ts)  # c(trial_data$timestamp_exp[-1], NA) # trial end, chanded with lead function
  et_ts <- et_data$logged_time
  
  # split trial data into list(one row = one trial)
  split_trial_data <- split(trial_data, seq(nrow(trial_data)))
  
  # Define merging logic for a single trial
  fun_merge_data <- function(ts_1, ts_2, trial_data_splitted) {
    matched_time <- which(et_ts >= ts_1 & et_ts < ts_2)
    if (trial_data_splitted$baseline_trial_counter == "1" & !is.na(trial_data_splitted$baseline_trial_counter)) {
      matched_time <- which(et_ts >= ts_1)# no upper bound for baseline
    } 
    selected_et_data <- et_data[matched_time, ] # et data for trial duration
    # trial data: 1 row == 1 trial -> is repeated for each eye tracking event
    repeated_trial_data <- data.frame(
      sapply(trial_data_splitted, function(x) {
        rep(x, length(matched_time))}, simplify = FALSE)
      )
        merged_data <- data.frame(repeated_trial_data, selected_et_data)
  }
  
  print(paste0("merge: ", unique(trial_data$id))) #debugging print
  
  df_one_id <- mapply(
    fun_merge_data,
    ts_1 = start_ts,
    ts_2 = end_ts,
    trial_data_splitted = split_trial_data,
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



# 3) Data reshaping ----

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

# Standardize Column Names

# Rename 'oddball_trial_counter' to 'trial_number' for consistency
df_list <- lapply(df_list, function(x) {
  names(x)[names(x) == "oddball_trial_counter"] <- "trial_number"
  return(x)
})

# Assign trial_number = 999 to baseline trials (NA by default)
df_list <- lapply(df_list, function(x) {
  # Add a trial_number for baseline trials
  x$trial_number <- ifelse(is.na(x$trial_number) & x$trial == "baseline", 999, x$trial_number)
  return(x)
})

# Convert from participant-level to trial-level lists
# Input:  df_list (participant-level data)
# Output: list_split_trial (list where each element = one trial's data)
list_split_trial <- pblapply(df_list, function(x) {
  split(x, x$trial_number)})
list_split_trial <- unlist(list_split_trial, recursive = FALSE)  # Flatten nested list

# Create ts_trial: Timestamps relative to trial onset (timestamp_exp)
list_split_trial <- pblapply(list_split_trial, function(x) {
  x$ts_trial <- x$logged_time - x$timestamp_exp
  return(x)
})

# Apply custom preprocessing for pd
list_split_trial <- pblapply(
  list_split_trial, func_pd_preprocess)

# Binary flag for baseline trials (1 = baseline, 0 = oddball)
list_split_trial <- pblapply(list_split_trial, function(x) {
  if (any(x$trial_number == 999)) {
    # Handle baseline trial data here
    x$baseline_trial_counter <- ifelse(x$trial == "baseline", 1, 0)
  }
  return(x)
})

# Merge all trial-level data into one dataframe
df <- dplyr::bind_rows(list_split_trial)

# rearrange variables
df <- df %>%
  relocate(
    id, # no repetitions
    trial_number,
    trial,
    ts_trial,
    pd,
    .before = 1 # Move these columns to the start
  )

# df back up
df_backup <- df

#   3.2) Calculate Baseline Means ----

# Calculate baseline means 
baseline_means<- df %>%
  filter(trial == "baseline", baseline_trial_counter == 1) %>%
  group_by(id) %>%
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

# 4) Pupil Response Preprocessing----

#   4.1) Trial filtering and setup----

# Remove baseline trials from eye tracking df
df <- subset(df, phase != "baseline")

# Convert ID to character for consistent merging
df$id <- as.character(df$id)

# Create backup trial df
df_trial_backup <- df_trial

# Trial filtering
# Identify and exclude the last trial
last_trial_num <- max(df_trial$oddball_trial_counter, na.rm = TRUE)
print(paste("Last trial number is:", last_trial_num))

# Filter out baseline trial and the last trial
df_trial<- df_trial %>%
  filter(
    trial != "baseline",
    oddball_trial_counter != last_trial_num
  ) %>%
  rename(trial_number = oddball_trial_counter)

#   4.2) Pupil response metrics and data merging ----

# Calculate trial-level pupil metrics:
# - rpd_auc: Area Under Curve (0-1.5s)
# - rpd_high: Mean PD in late window (500-1500ms)
# - rpd_low: Mean PD in baseline window (0-250ms)

df_et_trial <- lapply(list_split_trial, function(x) {
  # Skip baseline trials entirely
  if (unique(x$phase) == "baseline") return(NULL)  # Exclude baseline trials
  
  data.frame(
    id = unique(x$id),
    trial_number = unique(x$trial_number),
    rpd_auc = min(AUC(x$ts_trial, x$pd, na.rm = TRUE), 15),  # Cap AUC at 15
    rpd_high = mean(x$pd[x$ts_trial > 0.500 & x$ts_trial < 1.5], na.rm = TRUE),
    rpd_low = mean(x$pd[x$ts_trial < 0.250], na.rm = TRUE)
  )
}) %>% 
  bind_rows()  # Combine all trials

# Merge trial metrics with metadata
df_trial <- df_trial %>%
  left_join(df_et_trial, by = c("id", "trial_number")) 

df_trial <- df_trial%>%
  left_join(
    baseline_means, 
    by = "id"
  )

df_trial<- df_trial %>% 
  mutate(
    # pupil response
    rpd = rpd_high - rpd_low
  )

# Trial classification
# Classify trial types and frequencies
df_trial <- df_trial %>%
  mutate(
    pitch = case_when(
      trial == "oddball" ~ oddball_frequency,
      trial == "standard" ~ standard_frequency,
      TRUE ~ NA_real_
    ),
    trial = as.factor(ifelse(grepl("oddball", trial), "oddball", "standard"))
  )

# PD data corrections

# Add baseline-corrected PD to raw data
df <- df %>%
  left_join(
    select(df_trial, 
           id, 
           trial_number,
           rpd_low,       # Baseline PD (0-250ms)
           rpd_high,      # Late-window PD (500-1500ms)
           rpd,           # Corrected response (high - low)
           baseline_mean), # Global baseline,
    by = c("id", "trial_number")
  )

df <- df %>%
  mutate(trial_corr_rpd = pd - rpd_low) # for every sample

# Calculate trial-level mean corrected RPD
trial_corr_rpd <- df %>%
  group_by(id, trial_number) %>%
  summarize(
    trial_corr_rpd = mean(pd - rpd_low, na.rm = TRUE)  # Mean corrected PD per trial
  ) %>%
  ungroup()

# Add to trial data
df_trial <- df_trial %>%
  left_join(trial_corr_rpd, by = c("id", "trial_number"))

# 5) Data Saving

# Optional: Save as RDS (preserves R attributes)
saveRDS(
  df_trial,
  file = paste0(datapath_trial,  "_ao.rds")
)
saveRDS(
  df,
  file = paste0(datapath_et,  "_ao.rds")
)




