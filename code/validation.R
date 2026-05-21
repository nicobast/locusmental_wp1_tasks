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

# pkgs <- c(, "ggplot2", "dplyr", "patchwork",
#           "knitr", "viridis", "DT", "kableExtra",
#           "lme4", "emmeans", "lmerTest", "performance", "GGally")

pkgs <- c("tidyverse", "GGally", "lme4", "emmeans", "lmerTest", "dplyr", "corrplot",
          "factoextra", "tidyverse")

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
demo_data_path <- "S:/KJP_Studien/LOCUS_MENTAL/6_Versuchsdaten/"

# Load data

# aggregated data
df_ao <- readRDS(paste0(home_path, data_path_ao, "df_sepr_aggregated_AO.rds"))
df_vo <- readRDS(paste0(home_path, data_path_vo, "sepr_condition.rds"))
df_rss <- readRDS(paste0(home_path, data_path_rss, "df_sepr_aggregated_RSS.rds"))
df_cvs <- readRDS(paste0(home_path, data_path_cvs, "df_cued_agg.rds"))

# bps data 
bps_rss <- readRDS(paste0(home_path, data_path_rss, "bps_data.rds"))
bps_ao <- readRDS(paste0(home_path, data_path_ao, "bps_data.rds"))
bps_cvs <- readRDS(paste0(home_path, data_path_cvs, "bps_data.rds"))

# trial data 
df_trial_ao <- readRDS(paste0(home_path, data_path_ao, "df_trial_AO.rds"))
df_trial_rss <- readRDS(paste0(home_path, data_path_rss, "df_trial_RSS.rds"))
df_trial_cvs <- readRDS(paste0(home_path, data_path_cvs, "df_combined.rds"))

# demo data
load(file.path(demo_data_path, "demo_data.rda"))
demo_data <- data

### Data reshaping ----

# 1. Prepare df_ao 
# Keeping only the primary columns of interest
data_ao <- df_ao %>%
  select(id, SEPR_AO_m_oddball, SEPR_AO_m_standard, BPS_oddball, BPS_standard) %>% 
  rename(BPS_AO_standard = BPS_standard, 
         BPS_AO_oddball = BPS_oddball) %>% 
  # scale SEPR
  mutate(
    SEPR_AO_standard_z = as.numeric(scale(SEPR_AO_m_standard)),
    SEPR_AO_oddball_z    = as.numeric(scale(SEPR_AO_m_oddball))
  )

# AO trial-level df
df_t_ao <- df_trial_ao %>% 
  select(id, trial, trial_number, sepr)

# 2. Prepare df_rss (Already wide)
# Keeping only the primary columns of interest
data_rss <- df_rss %>%
  select(id, RSS_SEPR_early_mean_control, RSS_SEPR_early_mean_transition, RSS_BPS_mean_control, RSS_BPS_mean_transition, mean_diff_RAND_to_REG1, mean_diff_REG_to_RAND, mean_diff_RAND_to_REG10 )%>%
  rename(BPR_RSS_control = RSS_BPS_mean_control,
         BPS_RSS_transition = RSS_BPS_mean_transition) %>% 
  # Scale SEPR
  mutate(
    RSS_transition_z = as.numeric(scale(RSS_SEPR_early_mean_transition)),
    RSS_control_z    = as.numeric(scale(RSS_SEPR_early_mean_control))
  )

# RSS trial-level df
df_t_rss <- df_trial_rss %>% 
  select(id, Condition, Trial.Number, SEPR_early, condition_type)

# 3. Prepare df_vo (NEEDS CONVERTING)
# We pivot it from long to wide so conditions become columns
data_vo <- df_vo %>%
  filter(n_trials >= 7) %>%
  group_by(id) %>%
  filter(n() == 2) %>% 
  ungroup() %>%
  mutate(sepr_scaled = as.numeric(scale(sepr_mean))) %>% 
  select(id, condition, sepr_mean,sepr_scaled, BPS, n_trials) %>%
  pivot_wider(
    names_from = condition, 
    # Tell R to pivot all three columns
    values_from = c(sepr_mean,sepr_scaled, BPS, n_trials), 
    names_glue = "{.value}_VO_{condition}" 
  )
print(paste("Participants remaining in VO task:", nrow(data_vo)))

# 4. Prepare df_cvs 
# Keeping only the primary columns of interest
# CEPR already scaled
data_cvs <- df_cvs %>%
  select(id,CEPR_CUED_mean_cued,CEPR_CUED_mean_standard, SEPR_mean_cued, SEPR_mean_standard, BPS_cued, BPS_standard)

# CVS trial-level df
df_t_cvs <- df_trial_cvs %>% 
  select(id, trial_number, mean_SEPR, mean_CEPR, trial_type)

# 5. Join all tasks into one master dataframe
# We use full_join to keep all participants, even if they missed a task. 
# (They will just have NAs for the missing task)
df_final <- data_ao %>%
  full_join(data_rss, by = "id") %>%
  #full_join(data_vo, by = "id") %>% 
  full_join(data_cvs, by = "id")

### Correlation matrix 
# DF only with raw rpd values from the 3 tasks
df_cor_rpd_raw <- df_final %>% 
  select(c(id,
           SEPR_AO_m_oddball,SEPR_AO_m_standard, # AO
           RSS_SEPR_early_mean_control,RSS_SEPR_early_mean_transition, # RSS SEPR
           mean_diff_RAND_to_REG1, mean_diff_REG_to_RAND, mean_diff_RAND_to_REG10, #RSS DIFFERENCES
           SEPR_mean_cued,SEPR_mean_standard, #CVS CUE
           CEPR_CUED_mean_cued, CEPR_CUED_mean_standard)) # CVS SEARCH

# This calculates correlations and handles missing values (NA)
cor_results <- cor(df_cor_rpd_raw %>% select(-id), use = "pairwise.complete.obs")

print("Correlation Matrix for all conditions:")
print(round(cor_results, 2))

# 7. Visualization
# This creates a matrix of scatterplots, densities, and correlation values
ggpairs(df_cor_rpd_raw%>% select(-id), columns = 1:ncol(df_cor_rpd_raw)) +
  theme_bw() +
  labs(title = "Battery Validation: Correlations across Pupil Tasks")

### Spearman correlation----
cor(df_cor_rpd_raw%>% select(-id) , use = "pairwise.complete.obs", method = "spearman")


# Load necessary libraries
library(factoextra) # Best for PCA visualization
library(tidyverse)

#PCA 6 Components than 3
# 1. Select only your 8 variables
pca_data <- df_cor_rpd_raw[, 2:ncol(df_cor_rpd_raw)]

# 2. Handle missing values (PCA will fail if there are NAs)
pca_data_clean <- na.omit(pca_data)

# 3. Run the PCA
# scale. = TRUE is CRITICAL: it ensures all tasks are treated equally 
# regardless of the raw units of pupil dilation.
pca_result <- prcomp(pca_data_clean, center = TRUE, scale. = TRUE)

fviz_eig(pca_result, addlabels = TRUE) +
  labs(title = "Scree Plot: Variance explained by each Component")

fviz_pca_var(pca_result,
             col.var = "contrib", # Color by contribution to the components
             gradient.cols = c("#00AFBB", "#E7B800", "#FC4E07"),
             repel = TRUE) +
  labs(title = "Task Groupings (PCA Variable Factor Map)")

# Look at the first 3 Principal Components
loadings <- pca_result$rotation[, 1:3]
print(round(loadings, 3))

# PCA with 2

# 1. Select only your variables
pca_data <- df_cor_rpd_raw[, 2:ncol(df_cor_rpd_raw)]

# 2. Handle missing values
pca_data_clean <- na.omit(pca_data)

# 3. Run the PCA
# Note: prcomp calculates all components, we filter them in the next steps
pca_result <- prcomp(pca_data_clean, center = TRUE, scale. = TRUE)

# 4. Scree Plot (Visualizing how much variance the 2 components capture)
fviz_eig(pca_result, addlabels = TRUE) +
  labs(title = "Scree Plot: Variance explained by each Component")

# 5. Variable Factor Map
# By default, fviz_pca_var plots Component 1 vs Component 2
fviz_pca_var(pca_result,
             col.var = "contrib", 
             gradient.cols = c("#00AFBB", "#E7B800", "#FC4E07"),
             repel = TRUE) +
  labs(title = "Task Groupings (PCA Variable Factor Map: PC1 and PC2)")

# 6. Extract Loadings for the first 2 Principal Components
# Changed [ , 1:3] to [ , 1:2]
loadings_2pc <- pca_result$rotation[, 1:2]
print(round(loadings_2pc, 3))

# Extract the scores (where each person sits on PC1 and PC2)
pca_scores <- as.data.frame(pca_result$x[, 1:2])

# Confirmatory

if(!require(lavaan)) install.packages("lavaan")
library(lavaan)



# # Model 1: General factor (including RSS)
model_1_general <- '
  General_Reaction =~ RSS_SEPR_early_mean_transition + 
                      SEPR_AO_m_oddball + 
                      CEPR_CUED_mean_cued +
                      SEPR_mean_cued 
'

# Model 2: General factor (including RSS + pattern variables)
model_2_general_extended <- '
  General_Reaction =~ mean_diff_RAND_to_REG1 +
                      mean_diff_RAND_to_REG10 +  
                      RSS_SEPR_early_mean_transition +            
                      SEPR_AO_m_oddball + 
                      CEPR_CUED_mean_cued +
                      SEPR_mean_cued 
'

# Model 3: General factor (AO + cued visual search only)
model_3_reactivity_only <- '
  General_Reaction =~ SEPR_AO_m_oddball + 
                      CEPR_CUED_mean_cued +
                      SEPR_mean_cued 
'

# Model 4: Two-factor model
model_4_two_factor <- '
  # Pattern Detection
  Pattern_Tracking =~ mean_diff_RAND_to_REG1 +
                      mean_diff_RAND_to_REG10 +
                      RSS_SEPR_early_mean_transition
  
  # Event Reactivity
  Event_Reactivity =~ SEPR_AO_m_oddball + 
                      CEPR_CUED_mean_cued + 
                      SEPR_mean_cued 
'

# Fit models

fit_1 <- cfa(model_1_general, data = pca_data_clean, std.lv = TRUE, estimator = "MLR")
fit_2 <- cfa(model_2_general_extended, data = pca_data_clean, std.lv = TRUE, estimator = "MLR")
fit_3 <- cfa(model_3_reactivity_only, data = pca_data_clean, std.lv = TRUE, estimator = "MLR")
fit_4 <- cfa(model_4_two_factor, data = pca_data_clean, std.lv = TRUE, estimator = "MLR")

# Inspect

summary(fit_1, standardized = TRUE, fit.measures = TRUE)
summary(fit_2, standardized = TRUE, fit.measures = TRUE)
summary(fit_3, standardized = TRUE, fit.measures = TRUE)
summary(fit_4, standardized = TRUE, fit.measures = TRUE)

# Extract Fits

get_fit <- function(fit) {
  fitMeasures(fit, c("chisq", "df", "pvalue",
                     "cfi", "tli", 
                     "rmsea", "rmsea.ci.lower", "rmsea.ci.upper",
                     "srmr", "aic", "bic"))
}

fit_table <- rbind(
  Model_1 = get_fit(fit_1),
  Model_2 = get_fit(fit_2),
  Model_3 = get_fit(fit_3),
  Model_4 = get_fit(fit_4)
)

round(fit_table, 3)

# Comparison
anova(fit_1, fit_2)  # Model 1 vs extended
anova(fit_1, fit_3)  # removing RSS → nested comparison

fit_table[, c("aic", "bic")]

# Model 5
model_5_structural <- '
  # Measurement part
  Pattern_Tracking =~ mean_diff_RAND_to_REG1 +
                      mean_diff_RAND_to_REG10 +
                      RSS_SEPR_early_mean_transition
  
  Event_Reactivity =~ SEPR_AO_m_oddball + 
                      CEPR_CUED_mean_cued + 
                      SEPR_mean_cued 
  
  # Structural path (directional)
  Event_Reactivity ~ Pattern_Tracking
'

fit_5 <- sem(model_5_structural, 
             data = pca_data_clean, 
             std.lv = TRUE, 
             estimator = "MLR")

summary(fit_5, standardized = TRUE, fit.measures = TRUE)


# Model 5b

model_5b_structural_reverse <- '
  Pattern_Tracking =~ mean_diff_RAND_to_REG1 +
                      mean_diff_RAND_to_REG10 +
                      RSS_SEPR_early_mean_transition
  
  Event_Reactivity =~ SEPR_AO_m_oddball + 
                      CEPR_CUED_mean_cued + 
                      SEPR_mean_cued 
  
  Pattern_Tracking ~ Event_Reactivity
'

fit_5b <- sem(model_5b_structural_reverse, 
              data = pca_data_clean, 
              std.lv = TRUE, 
              estimator = "MLR")

summary(fit_5b, standardized = TRUE, fit.measures = TRUE)

# Model 6

model_6_higher_order <- '
  # First-order factors
  Pattern_Tracking =~ mean_diff_RAND_to_REG1 +
                      mean_diff_RAND_to_REG10 +
                      RSS_SEPR_early_mean_transition
  
  Event_Reactivity =~ SEPR_AO_m_oddball + 
                      CEPR_CUED_mean_cued + 
                      SEPR_mean_cued 
  
  # Second-order factor
  LCNE =~ Pattern_Tracking + Event_Reactivity
'

fit_6 <- cfa(model_6_higher_order, 
             data = pca_data_clean, 
             std.lv = TRUE, 
             estimator = "MLR")

summary(fit_6, standardized = TRUE, fit.measures = TRUE)


# Reliability (Composite Reliability / Omega)
library(semTools)

reliability(fit_4)

# Hierarchical Clustering of Participants
dist_mat <- dist(scale(pca_data_clean)) # Distance between people
clusters <- hclust(dist_mat, method = "ward.D2")

# Plot the Dendrogram
plot(clusters, main = "Participant Clusters", xlab = "", sub = "")
rect.hclust(clusters, k = 3, border = 2:4) # Highlights 3 groups

# Example: Compare AO Oddball vs AO Standard
# This requires reshaping data to 'long' format
library(ggpubr)
df_long <- df_cor_rpd_raw %>%
  select(SEPR_AO_m_oddball, SEPR_AO_m_standard) %>%
  pivot_longer(everything(), names_to = "Condition", values_to = "Pupil")

ggpaired(df_long, x = "Condition", y = "Pupil", 
         color = "Condition", line.color = "gray", line.size = 0.4,
         palette = "jco")+
  stat_compare_means(paired = TRUE)

library(qgraph)
N <- nrow(pca_data_clean) 
cor_mat <- cor(pca_data_clean, use = "pairwise.complete.obs")
# 2. Das Netzwerk zeichnen
library(qgraph)
qgraph(cor_mat, 
       graph = "cor",            # Einfache Korrelation statt glasso
       layout = "spring", 
       labels = colnames(cor_mat), 
       vsize = 7, 
       cut = 0.1,                # Zeige keine Linien unter r = 0.1
       minimum = 0.1,
       label.cex = 1.2,
       legend = TRUE)

### Baseline Pupil ----

bps_matrix <- df_final %>% select(id, starts_with("BPS"))
# Correlation of baselines
cor_bps <- cor(bps_matrix %>% select(-id), use = "pairwise.complete.obs", method = "spearman")
print("Consistency of Baseline Pupil Size across the battery:")
print(round(cor_bps, 2))

bps_summary <- data.frame(
  Task = c("AO", "RSS", "VO", "Cued"),
  Mean_BPS = c(
    mean(df_final$BPS_AO_standard, na.rm=TRUE),
    mean(df_final$BPS_RSS_transition, na.rm=TRUE),
    mean(df_final$BPS_VO_standard, na.rm=TRUE),
    mean(df_final$BPS_cued, na.rm=TRUE)
  )
)
print(bps_summary)


cor_means <- df_final %>%
  select(
    AO_Oddball = SEPR_AO_m_oddball,
    RSS_Transition = RSS_SEPR_early_mean_transition,
    Cued_Task = CEPR_CUED_mean_cued
  ) %>%
  cor(use = "pairwise.complete.obs", method = "spearman")

print(round(cor_means, 2))

#### Habituation ---

# Auditory Oddball

# Ensure task/condition is a factor
bps_ao$condition <- as.factor(bps_ao$condition)

# Model: BPS predicted by trial number, with a random intercept for each participant
m_ao_hab <- lmer(BPS ~ trial_number + (1 | id), data = bps_ao)

anova(m_ao_hab)

# interaction with condition
m_ao_int <- lmer(BPS ~ trial_number*condition + (1 | id), data = bps_ao)

anova(m_ao_int)

# Cued Visual Search

# Ensure task/condition is a factor
bps_cvs$Condition <- as.factor(bps_cvs$Condition)
# ensure trial number is num
bps_cvs$trial_number <- as.numeric(bps_cvs$trial_number)

# Model: BPS predicted by trial number, with a random intercept for each participant
m_cvs_hab <- lmer(BPS ~ trial_number + (1 | id), data = bps_cvs)

anova(m_cvs_hab)
summary(m_cvs_hab)

# Model:Interaction with condition
m_cvs_int <- lmer(BPS ~ trial_number*Condition + (1 | id), data = bps_cvs)

anova(m_cvs_int)
summary(m_cvs_int)

# rapid sound sequences

# Ensure task/condition is a factor
bps_rss$Condition <- as.factor(bps_rss$Condition)
# ensure trial number is num
bps_rss$Trial.Number <- as.numeric(bps_rss$Trial.Number)

# Model: BPS predicted by trial number, with a random intercept for each participant
m_rss_hab <- lmer(BPS ~ Trial.Number + (1 | id), data = bps_rss)

anova(m_rss_hab)
summary(m_rss_hab)

# Model: Interaction with Condition
m_rss_int <- lmer(BPS ~ Trial.Number*Condition + (1 | id), data = bps_rss)

anova(m_rss_int)
summary(m_rss_int)

### Add Demo Data

# to BPS measures

# Assuming your demographic dataframe is called 'demodata'
bps_matrix_d <- bps_matrix %>%
  inner_join(
    demo_data %>%
      rename(id = ID) %>% # Change ID to id
      select(id, sex, CBCL_T_INT, CBCL_T_EXT, CBCL_T_GES, IQ_verbal_z, IQ_nonverbal_z),
    by = "id"
  )

# Create a numeric-only version for correlation
# We exclude 'id' and make sure 'sex' is numeric if you want to include it
cor_data <- bps_matrix_d %>%
  mutate(sex = as.numeric(as.factor(sex))) %>% # Male/Female becomes 1/2
  select(-id) # Remove ID column

# compute correlation matrix
# use = "pairwise.complete.obs" handles missing data (NAs)
cor_matrix <- cor(cor_data, use = "pairwise.complete.obs", method = "pearson")

# View the correlations of the BPS variables against the demographic ones
# (Assuming your BPS columns are 1 to 10 and your new vars are at the end)
round(cor_matrix, 2)

corrplot(cor_matrix, 
         method = "color", 
         type = "upper", 
         tl.col = "black", 
         tl.srt = 45, 
         addCoef.col = "black", # Adds the correlation coefficient numbers
         number.cex = 0.7)

# to SEPR measures

df_cor_rpd_raw_d <- df_cor_rpd_raw %>%
  inner_join(
    demo_data %>%
      rename(id = ID) %>% # Change ID to id
      select(id, sex, CBCL_T_INT, CBCL_T_EXT, CBCL_T_GES, IQ_verbal_z, IQ_nonverbal_z),
    by = "id"
  )

# Create a numeric-only version for correlation
# We exclude 'id' and make sure 'sex' is numeric if you want to include it
cor_df <- df_cor_rpd_raw_d %>%
  mutate(sex = as.numeric(as.factor(sex))) %>% # Male/Female becomes 1/2
  select(-id) # Remove ID column

# compute correlation matrix
# use = "pairwise.complete.obs" handles missing data (NAs)
cor_m <- cor(cor_df, use = "pairwise.complete.obs", method = "pearson")

# View the correlations of the BPS variables against the demographic ones
# (Assuming your BPS columns are 1 to 10 and your new vars are at the end)
round(cor_m, 2)

corrplot(cor_m, 
         method = "color", 
         type = "upper", 
         tl.col = "black", 
         tl.srt = 45, 
         addCoef.col = "black", # Adds the correlation coefficient numbers
         number.cex = 0.7)

model1 <- lm(CBCL_T_GES ~ mean_diff_REG_to_RAND + sex + IQ_verbal_z, data = df_cor_rpd_raw_d)
summary(model1)

library(ggplot2)
ggplot(df_cor_rpd_raw_d, aes(x = mean_diff_REG_to_RAND, y = CBCL_T_GES)) +
  geom_point(alpha = 0.6) +
  geom_smooth(method = "lm", color = "red") +
  labs(title = "BPS Metric vs. Total Symptoms",
       x = "Mean Difference (REG to RAND)",
       y = "CBCL Total Score") +
  theme_minimal()
t.test(CBCL_T_GES ~ sex, data = bps_matrix)

# Trial-level data analysis

library(dplyr)
library(tidyr)

# 1. Filter and Parcel AO (e.g., only Oddball trials if you have a condition column)
# If you don't have a condition column in df_t_ao, skip the filter step
df_ao_p <- df_t_ao %>%
  # filter(condition == "oddball") %>% # Uncomment and change name if applicable
  group_by(id) %>%
  mutate(parcel = ceiling(row_number() / 5)) %>%
  group_by(id, parcel) %>%
  summarise(val = mean(sepr, na.rm = TRUE), .groups = "drop") %>%
  mutate(v_name = paste0("AO_p", parcel)) %>%
  pivot_wider(id_cols = id, names_from = v_name, values_from = val)

# 2. Filter and Parcel RSS (Only Transition trials)
df_rss_p <- df_t_rss %>%
  filter(condition_type == "transition") %>% 
  group_by(id) %>%
  mutate(parcel = ceiling(row_number() / 4)) %>% # Smaller parcel if fewer trials
  group_by(id, parcel) %>%
  summarise(val = mean(SEPR_early, na.rm = TRUE), .groups = "drop") %>%
  mutate(v_name = paste0("RSS_p", parcel)) %>%
  pivot_wider(id_cols = id, names_from = v_name, values_from = val)

# 3. Filter and Parcel CVS
df_cvs_p <- df_t_cvs %>%
  # filter(trial_type == "interest") %>% # Uncomment if applicable
  group_by(id) %>%
  mutate(parcel = ceiling(row_number() / 5)) %>%
  group_by(id, parcel) %>%
  summarise(val = mean(mean_SEPR, na.rm = TRUE), .groups = "drop") %>%
  mutate(v_name = paste0("CVS_p", parcel)) %>%
  pivot_wider(id_cols = id, names_from = v_name, values_from = val)

# Merge
df_final_parceled <- df_ao_p %>%
  full_join(df_rss_p, by = "id") %>%
  full_join(df_cvs_p, by = "id")

ao_vars  <- names(df_ao_p)[-1]
rss_vars <- names(df_rss_p)[-1]
cvs_vars <- names(df_cvs_p)[-1]

model_parceled <- paste0('
  # Latent Factors
  AO  =~ ', paste(ao_vars, collapse = " + "), '
  RSS =~ ', paste(rss_vars, collapse = " + "), '
  CVS =~ ', paste(cvs_vars, collapse = " + "), '

  # Higher order General Factor
  General_Pupil =~ AO + RSS + CVS
')

fit_p <- cfa(model_parceled, data = df_final_parceled, missing = "ml")
summary(fit_p, fit.measures = TRUE, standardized = TRUE)


# Function to create exactly 3 parcels per task regardless of trial count
make_3_parcels <- function(df, val_col, task_name) {
  df %>%
    group_by(id) %>%
    mutate(pos = row_number() / n()) %>%
    mutate(parcel = case_when(
      pos <= 0.33 ~ 1,
      pos <= 0.66 ~ 2,
      TRUE        ~ 3
    )) %>%
    group_by(id, parcel) %>%
    summarise(mean_val = mean(!!sym(val_col), na.rm = TRUE), .groups = "drop") %>%
    mutate(v_name = paste0(task_name, "_p", parcel)) %>%
    pivot_wider(id_cols = id, names_from = v_name, values_from = mean_val)
}

# Re-process the data
df_ao_3 <- make_3_parcels(df_t_ao %>% filter(trial == "oddball"), "sepr", "AO")
df_rss_3 <- make_3_parcels(df_t_rss %>% filter(condition_type == "transition"), "SEPR_early", "RSS")
df_cvs_3 <- make_3_parcels(df_t_cvs %>% filter(trial_type == "cued"),"mean_SEPR", "CVS")

df_final_simple <- df_ao_3 %>%
  inner_join(df_rss_3, by = "id") %>%
  inner_join(df_cvs_3, by = "id")

# Test CVS first (It looked the strongest in your output)
model_cvs <- ' CVS =~ CVS_p1 + CVS_p2 + CVS_p3 '
fit_cvs <- cfa(model_cvs, data = df_final_simple, std.lv = TRUE)
summary(fit_cvs, fit.measures = TRUE, standardized = TRUE)

# Test AO (This one is the most likely to fail)
model_ao <- ' AO =~ AO_p1 + AO_p2 + AO_p3 '
fit_ao <- cfa(model_ao, data = df_final_simple, std.lv = TRUE)
summary(fit_ao, fit.measures = TRUE, standardized = TRUE)

# 1. Create task-level averages
df_composite <- df_combined_cfa %>%
  group_by(id, task) %>%
  summarise(score = mean(sepr_val, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = task, values_from = score)

# 2. Run a CFA with only 3 indicators (The tasks themselves)
model_simple <- ' General_Pupil =~ AO + RSS + CVS '
fit_simple <- cfa(model_simple, data = df_composite, std.lv = TRUE)
summary(fit_simple, fit.measures = TRUE, standardized = TRUE)


df_composite <- df_final_simple %>%
  transmute(
    id,
    AO  = rowMeans(across(starts_with("AO_p")),  na.rm = TRUE),
    RSS = rowMeans(across(starts_with("RSS_p")), na.rm = TRUE),
    CVS = rowMeans(across(starts_with("CVS_p")), na.rm = TRUE)
  )

cor(df_composite[,-1], use = "pairwise.complete.obs")


# Quick sanity check per task
df_t_ao  %>% group_by(id) %>% summarise(n=n(), m=mean(sepr, na.rm=TRUE)) %>% summary()
df_t_rss %>% filter(condition_type=="transition") %>% 
  group_by(id) %>% summarise(n=n(), m=mean(SEPR_early, na.rm=TRUE)) %>% summary()
df_t_cvs %>% group_by(id) %>% summarise(n=n(), m=mean(mean_SEPR, na.rm=TRUE)) %>% summary()


head(df_t_cvs[, c("id", "mean_SEPR")])  # spot check values

# Also check: are ALL CVS trials negative, or is it condition-specific?
df_t_cvs %>%
  group_by(id) %>%
  summarise(
    prop_negative = mean(mean_SEPR < 0, na.rm = TRUE),
    m = mean(mean_SEPR, na.rm = TRUE)
  ) %>%
  summary()

table(df_t_ao$condition) 


library(lavaan)
library(lme4)
library(performance)
library(tidyverse)

# ── 1. Prepare trial-level data (relevant trials only) ────────────────────

df_ao_ml <- df_t_ao %>%
  filter(trial == "oddball") %>%
  transmute(id, AO = sepr) %>%
  group_by(id) %>%
  mutate(trial_rank = row_number()) %>%
  ungroup()

df_rss_ml <- df_t_rss %>%
  filter(condition_type == "transition") %>%
  transmute(id, RSS = SEPR_early) %>%
  group_by(id) %>%
  mutate(trial_rank = row_number()) %>%
  ungroup()

df_cvs_ml <- df_t_cvs %>%
  filter(trial_type == "cued") %>%
  transmute(id, CVS = mean_SEPR) %>%
  group_by(id) %>%
  mutate(trial_rank = row_number()) %>%
  ungroup()

# ── 2. ICC per task BEFORE running MLCFA ─────────────────────────────────
# Critical diagnostic: ICC tells you how much stable between-person
# variance each task has. If ICC ≈ 0, there's no person-level signal
# to recover, and MLCFA won't help.

icc(lmer(AO  ~ 1 + (1|id), data = df_ao_ml))
icc(lmer(RSS ~ 1 + (1|id), data = df_rss_ml))
icc(lmer(CVS ~ 1 + (1|id), data = df_cvs_ml))

# ── 3. Pair trials across tasks by rank ──────────────────────────────────
# inner_join limits each person to their minimum trial count across tasks

df_ml_wide <- df_ao_ml %>%
  inner_join(df_rss_ml, by = c("id", "trial_rank")) %>%
  inner_join(df_cvs_ml, by = c("id", "trial_rank")) %>%
  ungroup()

# Sanity check: how many persons and trials remain?
df_ml_wide %>%
  group_by(id) %>%
  summarise(n_trials = n()) %>%
  summary()

# ── 4. Multilevel CFA ────────────────────────────────────────────────────

model_mlcfa <- '
  level: 1
    # Within-person: trial-level noise per task (no latent structure needed)
    AO  ~~ AO
    RSS ~~ RSS
    CVS ~~ CVS

  level: 2
    # Between-person: general LC-NE factor (disattenuated for trial noise)
    LC_NE =~ AO + RSS + CVS
'

fit_mlcfa <- cfa(
  model_mlcfa,
  data      = df_ml_wide,
  cluster   = "id",
  std.lv    = TRUE,
  estimator = "MLR"    # robust ML handles non-normality in pupil data
)

summary(fit_mlcfa, fit.measures = TRUE, standardized = TRUE)

# ── 5. If the factor model won't converge, inspect the between-level ──────
# covariance matrix directly (the disattenuated correlations)

model_saturated <- '
  level: 1
    AO  ~~ AO
    RSS ~~ RSS
    CVS ~~ CVS
  level: 2
    AO  ~~ AO + RSS + CVS
    RSS ~~ RSS + CVS
    CVS ~~ CVS
'

fit_sat <- cfa(
  model_saturated,
  data      = df_ml_wide,
  cluster   = "id",
  estimator = "MLR"
)

# Extract between-person correlation matrix (disattenuated)
lavInspect(fit_sat, "cor.lv")
