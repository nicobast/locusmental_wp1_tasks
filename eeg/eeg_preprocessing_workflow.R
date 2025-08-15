
# EEG Preprocessing Workflow in R

## SETUP ####

require(JADE) #ICA
require(e1071) #kurtosis

# Load required libraries
library(dplyr)
library(tidyr)
library(ggplot2)
library(gridExtra)

library(eegUtils)
require(fastICA)
library(signal)
require(scatterplot3d) #cartesian coordinate plotting
require(geometry)

theme_set(theme_bw())

#cutoffs
flat_channel_variance_cutoff<-1 #1 microvolt
noisy_channel_cutoff<-100 #100 microvolt

#EEG characteristics - derived from manual BrainProducts RNP-LA-32.pdf
file_path<-"C:/Users/nico/PowerFolders/project_locusmental_wp1/data/testdata_battery_eeg_Leni13082025/eeg/eeg_with_triggers.csv"
eeg_channel_range<-2:33
sampling_rate <- 1000
channel_labels<-c(
  'FP1',  'Fz',  'F3',  'F7',  'F9',  'FC5',  'FC1',
  'C3',  'T7',  'CP5',  'CP1',  'Pz',  'P3',  'P7',
  'P9',  'O1',  'Oz',  'O2',  'P10',  'P8',  'P4',
  'CP2',  'CP6',  'T8',  'C4',  'Cz',  'FC2',  'FC6',
  'F10',  'F8',  'F4',  'FP2')

#EEG electrode positions - derived from manual BrainProducts RNP-LA-32.pdf

#arc from ear to ear - origin is Cz with 90 degrees to left and 90 degrees to right
theta <- c(-90, 45, -60, -90, -113, -69, -31, -45, -90, -69, -31, 45, -60, -90, -113, -90, 90, 90, 113, 90, 60, 31, 69, 90, 45, 0, 31, 69, 113, 90, 60, 90)
#arc from nose to neck - origin is Cz with 90 degrees to nose and 90 degrees to neck
phi <- c(-72, 90, -51, -36, -36, -21, -46, 0, 0, 21, 46, -90, 51, 36, 36, 72, -90, -72, -36, -36, -51, -46, -21, 0, 0, 0, 46, 21, 36, 36, 51, 72)
#-->reflects the 32 electrode montage position of the RNP-LA-32 (R-Net caps)


spherical_to_cartesian <- function(theta_deg, phi_deg) {
  # Convert degrees to radians
  theta_rad <- theta_deg * pi / 180
  phi_rad <- phi_deg * pi / 180
  
  # Convert spherical to Cartesian coordinates
  x <- sin(theta_rad) * cos(phi_rad)
  y <- sin(theta_rad) * sin(phi_rad)
  z <- cos(theta_rad)
  
  return(cbind(x, y, z))
}

cart_coordinates<-data.frame(spherical_to_cartesian(theta,phi))
row.names(cart_coordinates)<-channel_labels

#plot in 3D space
s3d<-scatterplot3d(cart_coordinates[,1], 
              cart_coordinates[,2], 
              cart_coordinates[,3], pch = 16, color = "blue", main = "3D Cartesian Coordinates")
s3d_coords <- s3d$xyz.convert(cart_coordinates[,1], cart_coordinates[,2], cart_coordinates[,3])
text(s3d_coords$x, s3d_coords$y, row.names(cart_coordinates), pos = 4)

#plot in 2D space
ggplot(cart_coordinates,aes(x=x,y=y))+geom_point()+geom_label(label=row.names(cart_coordinates))+labs(title='top-down view')
ggplot(cart_coordinates,aes(x=x,y=z))+geom_point()+geom_label(label=row.names(cart_coordinates))+labs(title='back view')

#add column for electrode label
cart_coordinates<-data.frame(electrode=channel_labels,cart_coordinates)


## LOAD FUNCTIONS ####

# Function to load EEG data from CSV
load_eeg_data <- function(file_path) {
  data <- read.csv(file_path,header=T,sep=',')
  return(data)
}

#inspect channels
inspect_channels<-function(data){

  mean<-apply(data,2,mean)
  median<-apply(data,2,median)
  sd<-apply(data,2,sd)
  plot_summary<-data.frame(mean,median,sd)
  
  ggplot(plot_summary,aes(x=colnames(data),y=median))+
    geom_boxplot(aes(
      lower = median - sd, 
      upper = median + sd, 
      middle = median, 
      ymin = median - 3*sd, 
      ymax = median + 3*sd),
      stat = "identity")+
    labs(y='median voltage')

}


# Function to apply bandpass filter, 1-40Hz, 1000Hz sampling rate
bandpass_filter <- function(data, low_freq = 1, high_freq = 40, srate = sampling_rate) {
  nyquist <- srate / 2
  bf <- butter(4, c(low_freq / nyquist, high_freq / nyquist), type = "pass")
  filtered_data <- as.data.frame(lapply(data, function(channel) {
    filtfilt(bf, channel)
  }))
  return(filtered_data)
}

# identify noisy and flat channels
identify_flat_channels<-function(data,flat_cutoff){
channel_labels[apply(data, 2, sd) < flat_cutoff]
}

identify_noisy_channels<-function(data,noisy_cutoff){
channel_labels[apply(data, 2, sd) > noisy_cutoff]
}

#channel correlation
channel_correlation<-function(data){
  
  #identify channels with low absolute intercorrelations
  #correlation ordered by first principal component (clustered correlation patterns)
  cor_table<-corrplot::corrplot(cor(data),order='FPC')[[1]]
  cor_table<-abs(cor_table)
  diag(cor_table)<-NA
  mean_intercorrelations<-apply(cor_table,2,mean,na.rm=T)
  names(mean_intercorrelations)<-colnames(cor_table)
  plot(mean_intercorrelations)
  text(mean_intercorrelations,names(mean_intercorrelations),pos=3,col='red')
  low_intercorrelations<-names(mean_intercorrelations)[mean_intercorrelations<0.4]
  return(low_intercorrelations)
  
}


#spatial interpolation - with inverse distance weighting
  spatial_interpolate <- function(eeg_data, bad_channels, coords) {
    
    good_channels <- setdiff(colnames(eeg_data), bad_channels)
    
    # Extract coordinates
    good_coords <- coords %>% eegUtils::filter(electrode %in% good_channels) %>% select(x, y, z)
    bad_coords <- coords %>% eegUtils::filter(electrode %in% bad_channels) %>% select(x, y, z)
    
    # Compute distance matrix between bad and good channels
    dist_matrix <- as.matrix(dist(rbind(bad_coords, good_coords)))
    dist_matrix <- dist_matrix[1:nrow(bad_coords), (nrow(bad_coords)+1):nrow(dist_matrix)]
    
    # Compute weights (inverse distance)
    weights <- 1 / (dist_matrix + 1e-6)
    weights <- weights / rowSums(weights)
    
    # Extract EEG values for good channels
    eeg_good <- as.matrix(eeg_data[, good_channels])
    
    # Interpolate: matrix multiplication of weights and good channel values
    eeg_interp <- weights %*% t(eeg_good)  # result: bad_channels × time
    
    # Transpose and assign interpolated values to bad channels
    eeg_data[, bad_channels] <- t(eeg_interp)
    
    return(eeg_data)
  }
  
  
# Function to apply Common Average Reference
apply_car <- function(eeg_data) {
  # Compute the average across all channels for each time point
  car_vector <- rowMeans(eeg_data, na.rm = TRUE)
  
  # Subtract the average from each channel
  eeg_car <- sweep(eeg_data, 1, car_vector)
  
  return(eeg_car)
}


# Function to perform ICA for artifact removal - based on eegUtils package
perform_ica <- function(data) {
  
  #testing
  eeg_data<-filtered_data
  #centering
  eeg_centered_data <- scale(as.matrix(eeg_data), center = TRUE, scale = FALSE)
  #dimensionality reduction with PCA
  pca_result <- prcomp(eeg_centered_data, center = TRUE, scale. = FALSE)
  summary(pca_result)
  # Keep only components with non-zero variance
  nonzero_var <- apply(pca_result$x, 2, sd) > 1e-6
  pca_scores <- pca_result$x[, nonzero_var]
  #Apply JADE ICA
  ica_result<-JADE(pca_scores)
  #extract components
  components <- ica_result$S
  mixing_matrix <- ica_result$A
  
  return(list(components,mixing_matrix,pca_result,nonzero_var,eeg_centered_data))
 
} 

# Function to select specific channels
select_channels <- function(data, channels) {
  selected_data <- data[, channels]
  return(selected_data)
}

# Function to visualize EEG signals
plot_preprocessed_segments<-function(eeg_data){
  
  number_of_samples <- 10
  segment_length <- 10000
  
  # Random electrodes
  sample_electrodes <- sample(names(eeg_data), number_of_samples)
  
  # Random start indices, adjusted for segment length
  start_segments <- sample(1:nrow(eeg_data), number_of_samples)
  start_segments <- ifelse(start_segments > (nrow(eeg_data) - segment_length),
                           start_segments - segment_length, start_segments)
  end_segments <- start_segments + segment_length
  
  # Create a list of ggplots
  plot_list <- mapply(function(electrode, start_idx, end_idx) {
    seg_data <- eeg_data[start_idx:end_idx, electrode, drop = FALSE]
    df <- data.frame(Time = start_idx:end_idx, Amplitude = seg_data[[1]])
    
    ggplot(df, aes(x = Time, y = Amplitude)) +
      geom_line() +
      labs(title = electrode) +
      theme_minimal()
  },
  electrode = sample_electrodes,
  start_idx = start_segments,
  end_idx = end_segments,
  SIMPLIFY = FALSE)
  
  # Arrange them in a grid
  do.call(grid.arrange, plot_list)
  
}

#epoch function
epoch_eeg <- function(eeg_data, data_with_trigger_info,
                      srate, tmin, tmax) {
  # eeg_data: data.frame (time × channels)
  # triggers: vector of event onset samples (integer indices)
  # trial_labels: optional vector of event labels (same length as triggers)
  # srate: sampling rate in Hz
  # tmin, tmax: epoch window in seconds (relative to trigger)
  trigger_info<-data_with_trigger_info
  triggers<-as.numeric(with(trigger_info,
                             by(1:nrow(trigger_info),
                                droplevels(interaction(trigger_trial,trigger_trialcounter)),min)))
  trial_labels<-names(with(trigger_info,
                            by(1:nrow(trigger_info),
                               droplevels(interaction(trigger_trial,trigger_trialcounter)),min)))
  
  # Convert times to samples
  pre_samp <- round(tmin * srate)
  post_samp <- round(tmax * srate)
  epoch_len <- post_samp - pre_samp + 1
  
  # Filter out triggers that would go out of bounds
  valid_idx <- which(triggers + pre_samp > 0 &
                       triggers + post_samp <= nrow(eeg_data))
  triggers <- triggers[valid_idx]
  
  if (!is.null(trial_labels)) {
    trial_labels <- trial_labels[valid_idx]
  }
  
  # Create matrix of start indices for all trials
  start_idx <- triggers + pre_samp
  
  # Preallocate 3D array: time × channels × trials
  n_trials <- length(start_idx)
  n_ch <- ncol(eeg_data)
  epochs <- array(NA_real_, dim = c(epoch_len, n_ch, n_trials),
                  dimnames = list(NULL, colnames(eeg_data), NULL))
  
  # Fill array (vectorized over channels, loop only over trials)
  for (i in seq_along(start_idx)) {
    idx_range <- start_idx[i]:(start_idx[i] + epoch_len - 1)
    epochs[, , i] <- as.matrix(eeg_data[idx_range, ])
  }
  
  # Return as list with metadata
  out <- list(
    data = epochs,
    srate = srate,
    time = seq(tmin, tmax, by = 1/srate),
    trials = n_trials,
    labels = trial_labels
  )
  class(out) <- "eeg_epochs"
  return(out)
}

#baseline correction
baseline_correct <- function(epoch_obj, baseline = c(-0.2, 0)) {
  # epoch_obj: output from epoch_eeg()
  # baseline: time window in seconds (start, end)
  
  data <- epoch_obj$data
  time <- epoch_obj$time
  
  # Find indices corresponding to baseline window
  baseline_idx <- which(time >= baseline[1] & time <= baseline[2])
  
  # Compute baseline mean for each channel & trial
  # Result: 1 × channels × trials
  base_mean <- apply(data[baseline_idx, , , drop = FALSE], c(2, 3), mean)
  
  # Subtract baseline mean from each time point
  # Broadcasting via sweep
  data_bc <- sweep(data, c(2, 3), base_mean, "-")
  
  # Return same structure with corrected data
  epoch_obj$data <- data_bc
  return(epoch_obj)
}



## APPLY TO DATA ####

#load data
raw_data <- load_eeg_data(file_path) #load data
names(raw_data)[eeg_channel_range]<-channel_labels #apply channel labels

#identify correct task to preprocess
start_task<-min((1:nrow(raw_data))[raw_data$trigger_trial=='baseline'])
end_task<-max((1:nrow(raw_data))[raw_data$trigger_trial=='auditory oddball'])
raw_data<-raw_data[start_task:end_task,]

eeg_data<-raw_data[,eeg_channel_range] #extract channels
ggplot(raw_data,aes(x=1:nrow(eeg_data),fill=trigger_trial))+geom_histogram(bins=100) #show trigger distribution

#band-pass filtering - important for other steps to work efficiently
filtered_data <- bandpass_filter(eeg_data)

#visual inspection of channels
inspect_channels(filtered_data)
corrplot::corrplot(cor(filtered_data),type='upper',order='FPC') #correlation ordered by first principal component (clustered correlation patterns)

#bad channel identification by algorithm
lowcor_channels<-channel_correlation(filtered_data)
flat_channels<-identify_flat_channels(filtered_data,flat_channel_variance_cutoff)
noisy_channels<-identify_noisy_channels(filtered_data,noisy_channel_cutoff)
bad_channels<-unique(c(lowcor_channels,flat_channels,noisy_channels))
bad_channels

#spatial interpolation of bad channels - with inverse distance weighting, requires electrode coordinates
filtered_data<-spatial_interpolate(filtered_data,bad_channels,cart_coordinates)
corrplot::corrplot(cor(filtered_data),type='upper',order='FPC') #check effect of spatial interpolation

#referencing - with common average referencing per timepoint
apply(filtered_data,2,median) #mean amplitude BEFORE rereferenceing
filtered_data<-apply_car(filtered_data)
apply(filtered_data,2,median) #mean amplitude AFTER rereferenceing

#Artifact-Removal - ICA --> TAKES SOME TIME
## 0. perform ICA
ica_result <- perform_ica(filtered_data)
components<-ica_result[[1]]
mixing_matrix<-ica_result[[2]]
pca_result<-ica_result[[3]]
nonzero_var<-ica_result[[4]]
eeg_centered_data<-ica_result[[5]]
##1. visual inspection of components
number_of_components<-5
for (i in 1:number_of_components){
  plot(components[, i], type = "l", main = paste("Component",i))
}
##2. automated inspection of components by  kurtosis
IC_kurtosis<-round(apply(components, 2, function(x){kurtosis(x)}),2)
high_kurtosis<-IC_kurtosis>100
##3. remove components (automatically based on kurtosis or visual inspection)
components_clean <- components
exclude_components<-3
components_clean[, c(1, exclude_components)] <- 0  # Replace with components you want to remove - automate by replacing with "high_kurtosis"
##4.reconstruct cleaned EEG
eeg_pca_clean <- components_clean %*% t(mixing_matrix) #Back to PCA space
eeg_clean <- eeg_pca_clean %*% t(pca_result$rotation[, nonzero_var]) # Back to original channel space
eeg_clean <- sweep(eeg_clean, 2, attr(eeg_centered_data, "scaled:center"), "+") #uncenter
eeg_clean<-data.frame(eeg_clean)

#inspect preprocessed data
corrplot::corrplot(cor(eeg_clean),type='upper',order='FPC') #correlation ordered by first principal component (clustered correlation patterns)
inspect_channels(eeg_clean)
plot_preprocessed_segments(eeg_clean)

#epoch data
eeg_epochs<-epoch_eeg(eeg_clean, 
                      data_with_trigger_info=raw_data[,-eeg_channel_range],
                      sampling_rate,
                      tmin=-0.2,tmax=1.8)

#baseline correction
eeg_epochs<-baseline_correct(eeg_epochs)

#inspect data
#extract 
desired_electrode<-'Fz'
desired_electrode_position<-which(dimnames(eeg_epochs$data)[[2]]==desired_electrode)
df_electrode<-eeg_epochs$data[,desired_electrode_position,]
colnames(df_electrode)<-eeg_epochs$labels
row.names(df_electrode)<-eeg_epochs$time
df_electrode<-data.frame(df_electrode)

df_electrode<-reshape2::melt(df_electrode)
epoch_time<-rep(eeg_epochs$time,length(unique(df_electrode$variable)))
split_vec <- strsplit(as.character(df_electrode$variable), "\\.")
condition <- sapply(split_vec, `[`, 1)
trial_number <- sapply(split_vec, `[`, 2)

df_electrode<-data.frame(epoch_time,condition,trial_number,df_electrode)
ggplot(df_electrode[df_electrode$epoch_time<0.5,],
       aes(x=epoch_time,y=value,group=condition,color=condition))+geom_smooth()+
  labs(title=desired_electrode,x='epoch time (s)',y='amplitude (uV)')



#TODO: covary for movement vectors X32,33,34 - can these be used to filter out movement artifacts?

