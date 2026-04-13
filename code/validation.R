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
  select(-c(SEPR_RSS_SEPR_early_mean_transition,SEPR_RSS_SEPR_early_mean_control,SEPR_AO_m_oddball, SEPR_AO_m_standard) )

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

### Spearman correlation----
cor(df_final %>% select(-id), use = "pairwise.complete.obs", method = "spearman")

### Difference scores?----
# Calculate Difference Scores (Experimental - Control)
df_diffs <- df_final %>%
  mutate(
    AO_effect  = SEPR_AO_oddball_z - SEPR_AO_standard_z,
    RSS_effect = RSS_transition_z - RSS_control_z,
    VO_effect  = SEPR_VO_zoddball - SEPR_VO_zstandard
  )

# Correlate the Effects (using Spearman)
cor_diffs <- df_diffs %>%
  select(AO_effect, RSS_effect, VO_effect, SEPR_CUED_mean) %>%
  cor(use = "pairwise.complete.obs", method = "spearman")

print("--- Correlation of Task Effects (Differences) ---")
print(round(cor_diffs, 2))

### Cohens d 
# --- 1. TASK 1: AO ---
t_ao <- t.test(df_ao$SEPR_AO_m_oddball, df_ao$SEPR_AO_m_standard, paired = TRUE)
d_ao <- cohen.d(df_ao$SEPR_AO_m_oddball, df_ao$SEPR_AO_m_standard, paired = TRUE)

# --- 2. TASK 2: RSS ---
t_rss <- t.test(df_rss$SEPR_RSS_SEPR_early_mean_transition, 
                df_rss$SEPR_RSS_SEPR_early_mean_control, paired = TRUE)
d_rss <- cohen.d(df_rss$SEPR_RSS_SEPR_early_mean_transition, 
                 df_rss$SEPR_RSS_SEPR_early_mean_control, paired = TRUE)

# --- 3. TASK 3: VO  ---
df_vo_wide <- df_vo %>%
  select(id, condition, sepr_mean) %>%
  pivot_wider(names_from = condition, values_from = sepr_mean) %>%
  drop_na(standard, oddball) # Keeps only participants with BOTH conditions

t_vo <- t.test(df_vo_wide$standard, df_vo_wide$oddball, paired = TRUE)
d_vo <- cohen.d(df_vo_wide$standard, df_vo_wide$oddball, paired = TRUE)

# --- 4. TASK 4: Cued Task (Comparison against zero) ---
# Assuming 'mean_CEPR_z' is z-scored, a value significantly > 0 
# means the cued trials elicited a response.

t_cued <- t.test(df_cvs$SEPR_CUED_mean, mu = 0) # One-sample t-test
d_cued <- mean(df_cvs$SEPR_CUED_mean) / sd(df_cvs$SEPR_CUED_mean) # Simple effect size

# --- PRINT FINAL TABLE ---
results <- data.frame(
  Task = c("Auditory Oddball", "RSS (Transition)", "Visual Oddball", "Cued Task"),
  t_stat = c(t_ao$statistic, t_rss$statistic, t_vo$statistic, t_cued$statistic),
  p_val = c(t_ao$p.value, t_rss$p.value, t_vo$p.value, t_cued$p.value),
  Cohen_d = c(d_ao$estimate, d_rss$estimate, d_vo$estimate, d_cued)
)

print(results)
