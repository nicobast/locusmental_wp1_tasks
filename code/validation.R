################################################################################
# 
# LOCUS-MENTAL Eye Tracking Battery Validation
# Author: Iskra Todorova & Nico Bast
# Last Update: 2026-04-13
# R Version: 4.5.1
#
################################################################################
# 
# Before you begin
# - Loading/installing packages 
# - Setting working directory
#
################################################################################
## SETUP ####

sessionInfo()

# REQUIRED PACKAGES

# pkgs <- c("tidyverse", "ggplot2", "dplyr", "patchwork",
#           "knitr", "viridis", "DT", "kableExtra",
#           "lme4", "emmeans", "lmerTest", "performance", "GGally")

pkgs <- c("tidyverse", "GGally")

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

# Setup paths

home_path <- "S:/KJP_Studien"
data_path_vo <- "/LOCUS_MENTAL/6_Versuchsdaten/visual_oddball/"
data_path_ao <- "/LOCUS_MENTAL/6_Versuchsdaten/auditory_oddball/"
data_path_rss <- "/LOCUS_MENTAL/6_Versuchsdaten/rapid_sound_sequences/"
data_path_cvs <- "/LOCUS_MENTAL/6_Versuchsdaten/visual_search_task/"

# Load data

df_ao <- readRDS(paste0(home_path, data_path_ao, "df_sepr_aggregated_AO.rds"))
df_vo <- readRDS(paste0(home_path, data_path_vo, "sepr_condition.rds"))
df_rss <- readRDS(paste0(home_path, data_path_rss, "df_sepr_aggregated_RSS.rds"))
df_cvs <- readRDS(paste0(home_path, data_path_cvs, "df_cued_agg.rds"))

### Data reshaping ----

# 1. Prepare df_ao (Already wide)
# Keeping only the primary columns of interest
data_ao <- df_ao %>%
  select(id, SEPR_AO_m_oddball, SEPR_AO_m_standard) %>% 
  # scale SEPR
  mutate(
    SEPR_AO_standard_z = as.numeric(scale(SEPR_AO_m_standard)),
    SEPR_AO_oddball_z    = as.numeric(scale(SEPR_AO_m_oddball))
  )

# 2. Prepare df_rss (Already wide)
# Keeping only the primary columns of interest
data_rss <- df_rss %>%
  select(id, SEPR_RSS_SEPR_early_mean_control, SEPR_RSS_SEPR_early_mean_transition)%>%
  # Scale SEPR
  mutate(
    RSS_transition_z = as.numeric(scale(SEPR_RSS_SEPR_early_mean_transition)),
    RSS_control_z    = as.numeric(scale(SEPR_RSS_SEPR_early_mean_control))
  )

# 3. Prepare df_vo (NEEDS CONVERTING)
# We pivot it from long to wide so conditions become columns
data_vo <- df_vo %>%
  mutate(sepr_scaled = as.numeric(scale(sepr_mean))) %>% 
  # scale SEPR
  select(id, condition, sepr_scaled) %>%
  pivot_wider(
    names_from = condition, 
    values_from = sepr_scaled,
    names_prefix = "SEPR_VO_z" # 
  )

# 4. Prepare df_cvs 
# Keeping only the primary columns of interest
# CEPR already scaled
data_cvs <- df_cvs %>%
  select(id, SEPR_CUED_mean)

# 5. Join all tasks into one master dataframe
# We use full_join to keep all participants, even if they missed a task. 
# (They will just have NAs for the missing task)
df_final <- data_ao %>%
  full_join(data_rss, by = "id") %>%
  full_join(data_vo, by = "id") %>% 
  full_join(data_cvs, by = "id")

df_final <- df_final %>% 
  select(-c(SEPR_RSS_SEPR_early_mean_transition,SEPR_RSS_SEPR_early_mean_control) )

### Correlation matrix 

# We select only the numeric SEPR columns for the correlation
cor_cols <- df_final %>% select(-id)

# This calculates correlations and handles missing values (NA)
cor_results <- cor(cor_cols, use = "pairwise.complete.obs")

print("Correlation Matrix for all conditions:")
print(round(cor_results, 2))

# 7. Visualization
# This creates a matrix of scatterplots, densities, and correlation values
ggpairs(df_final, columns = 2:ncol(df_final)) +
  theme_bw() +
  labs(title = "Battery Validation: Correlations across Pupil Tasks")

