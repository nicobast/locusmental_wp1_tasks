require(data.table)

#timestamp have high fractional values that can be displayed with this option in R
options(digits = 12)

files<-list.files('C:/Users/nico/PowerFolders/project_locusmental_wp1/data/testdata_battery_eeg_Leni13082025/eeg',full.names=T)

files

#paths to files
path_to_EEG_csv<-files[2]
path_to_trigger_csv<-files[3]

df_eeg<-fread(path_to_EEG_csv, header=T, sep=',')
# 36 variables: 1 timestamp, 32 EEG channels, 3 movement channels
df_trigger<-fread(path_to_trigger_csv)
# 2 variables: 1 timestamp, 1 trigger name

# Sort both by timestamp
setorder(df_eeg, Timestamp)
setorder(df_trigger, Timestamp)

# Add end time for each trigger (next trigger's timestamp)
df_trigger[, End := shift(Timestamp, type = "lead", fill = Inf)]
df_trigger<-df_trigger[!is.infinite(df_trigger$End),]

# Find interval indices for each EEG timestamp
interval_indices <- findInterval(df_eeg$Timestamp, df_trigger$Timestamp)
# Replace 0s with NA to avoid invalid indexing
interval_indices[interval_indices == 0] <- NA

# Assign trigger names using the interval indices
df_eeg[, trigger_trial := df_trigger$`1`[interval_indices]]
df_eeg[, trigger_trialcounter := df_trigger$`0`[interval_indices]]
df_eeg[, trigger_timestamp := df_trigger$`2`[interval_indices]]

# Save the merged data
output_path <- 'C:/Users/nico/PowerFolders/project_locusmental_wp1/eeg/data/eeg_with_triggers.csv'
fwrite(df_eeg, output_path)
cat("Merged EEG data with triggers saved to:\n", output_path)

#data checking
names(df_eeg)
table(df_eeg$trigger_trial)
table(df_eeg$trigger_trialcounter)

#remove task unrelated data
df_eeg<-df_eeg[!is.na(df_eeg$trigger_trial),]
df_eeg$ts_trial<-unlist(lapply(table(df_eeg$trigger_trialcounter),seq_len))

hist(df_eeg$ts_trial)

hist(unlist(df_eeg[,36]))
