################################################################################
#
# Rapid Sound Sequences Data Analysis
# Author: Iskra Todorova & Nico Bast
# Last Update: 01.04.2026
# R Version: 4.5.1
#
################################################################################


## SETUP ####

sessionInfo()

# REQUIRED PACKAGES

pkgs <- c("tidyverse",
          "ggplot2", # creating graphs
          "dplyr",
          "patchwork",
          "knitr",
          "viridis",
          "DT",
          "kableExtra",
          "lme4", 
          "emmeans",
          "lmerTest",
          "performance",
          "DHARMa",
          "sjPlot",
          "ggeffects",
          "car",
          "clubSandwich",
          "effectsize"
)

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


# Define paths (adjust to your project)
home_path <- "S:/KJP_Studien"
data_path <- "/LOCUS_MENTAL/6_Versuchsdaten/rapid_sound_sequences/"
demo_data_path <- "/LOCUS_MENTAL/6_Versuchsdaten/"
#home_path <- "C:/Users/nico/Nextcloud/project_locusmental_wp1"
#data_path <- "/data/rapid_sound_sequences/preprocessed/"


# Load processed files eye tracking
df <- readRDS(paste0(home_path, data_path, "df_loose_high.rds")) # use the most strict version, gaze in the center 135 px, Control: min 4 trial, Transition: min 6 trials
df_et <- readRDS(paste0(home_path, data_path, "preprocessed_et_rss.rds"))

# Load demographic data and questionnaires 
load(paste0(home_path, demo_data_path, "demo_data.rda"))

###############################################################################
### 1. Filter the raw data ----
##############################################################################

# This keeps all columns from df_et, but ONLY for the IDs and Trials in your clean df
df_et_filtered <- df_et %>%
  semi_join(df, by = c("id", "Trial.Number"))

# 2. Verification check
cat("Original raw rows: ", nrow(df_et), "\n")
cat("Filtered raw rows: ", nrow(df_et_filtered), "\n")

# 2. Row counts
original_rows <- nrow(df_et)
filtered_rows <- nrow(df_et_filtered)

# 3. Calculate loss
lost_rows <- original_rows - filtered_rows
loss_pct  <- lost_rows / original_rows * 100

# 4. Report
cat("\n--- RAW DATA LOSS REPORT ---\n")

cat("Original raw rows: ", original_rows, "\n")
cat("Filtered raw rows: ", filtered_rows, "\n")
cat("Rows lost (n):     ", lost_rows, "\n")
cat("Rows lost (%):     ", round(loss_pct, 2), "%\n")

###############################################################################
### 2. Compute relative time ----
##############################################################################

# convert transition timestamp to numeric for further calculations
df_et_filtered$transition_timestamp_1 <- as.numeric(df_et_filtered$transition_timestamp_1)


df_et_filtered <- df_et_filtered %>%
  mutate(
    # Define event time in seconds
    event_time = case_when(
      condition_type == "transition" ~ transition_timestamp_1 - start_timestamp_0,
      condition_type == "control" ~ 3,
      TRUE ~ NA_real_
    ),
    
    # Relative time to event
    rel_time = ts_sequence - event_time
  )

# Sanity plots
hist(df_et_filtered$ts_sequence)
hist(df_et_filtered$rel_time)

################################################################################
### 3. BASELINE (BPS) CORRECTION ----
# BPS = mean pupil diameter in 500 ms window immediately before transition
################################################################################

#  Define BPS as 500 ms before transition
df_bps <- df_et_filtered %>%
  filter(rel_time >= -1.000 & rel_time <= 0) %>%
  group_by(id, Condition, Trial.Number) %>%
  summarise(
    BPS_start_500ms = mean(pd[rel_time >= -0.500 & rel_time <= 0], na.rm = TRUE),
    condition_type  = first(condition_type), # Grab the label here
    .groups = "drop"
  )

# Join with pupil data to calculate corrected pd
df_et_filtered <- df_et_filtered %>%
  left_join(df_bps, by = c("id", "Condition", "Trial.Number"))%>%
  mutate(pd_corr_500 = pd - BPS_start_500ms)

################################################################################
### 4. COMPUTE SEPR PER TRIAL -----
# Early SEPR: 0.5 s to 2.0 s post-event
# Late  SEPR: 1.5 s to 3.0 s post-event
################################################################################
df_sepr <- df_et_filtered %>%
  group_by(id, Condition,condition_type, initial_sequence, Trial.Number) %>%
  summarise(
    # Mean for the 500ms to 2s window
    SEPR_early = mean(pd_corr_500[rel_time >= 0.5 & rel_time <= 2.0], na.rm = TRUE),
    
    # Mean for the 1.5s to 2.5s window
    SEPR_late  = mean(pd_corr_500[rel_time >= 1.5 & rel_time <= 3], na.rm = TRUE),
    
    .groups = "drop"
  )

# scale the pipul response
df_sepr <- df_sepr %>%
  mutate(
    SEPR_early_z = as.numeric(scale(SEPR_early)),
    SEPR_late_z  = as.numeric(scale(SEPR_late))
  )


################################################################################
### 5. INITIAL MODELS — CONDITION EFFECT -----
################################################################################

# --- Early SEPR ---

# 5.1 Condition 
m1 <- lmer(SEPR_early_z ~ Condition + (1 | id), data = df_sepr)
anova(m1)

# 5.2 Condition + trial 
m1_1 <- lmer(SEPR_early_z ~ Condition + Trial.Number + (1 | id), data = df_sepr)
anova(m1_1)

# 5.3 Binary: control vs transition
m1_2 <- lmer(SEPR_early_z ~ condition_type + (1 | id), data = df_sepr)
anova(m1_2)

# 5.4 Binary + trial
m1_3 <- lmer(SEPR_early_z ~ condition_type + Trial.Number + (1 | id), data = df_sepr)
anova(m1_3)

# 5.5 Interaction with initial sequence
m1_4 <- lmer(SEPR_early_z ~ condition_type * initial_sequence + Trial.Number + (1 | id),
             data = df_sepr)
anova(m1_4)

m_interaction <- lmer(SEPR_early_z ~ condition_type * initial_sequence + 
                        Trial.Number + (1 | id),
                      data = df_sepr, REML = FALSE)

m_no_interaction <- lmer(SEPR_early_z ~ condition_type + initial_sequence + 
                           Trial.Number + (1 | id),
                         data = df_sepr, REML = FALSE)

anova(m_no_interaction, m_interaction)

# --- Late SEPR ---

m2   <- lmer(SEPR_late_z ~ Condition + (1 | id), data = df_sepr)
anova(m2)

m2_1 <- lmer(SEPR_late_z ~ Condition + Trial.Number + (1 | id), data = df_sepr)
anova(m2_1)

m2_2 <- lmer(SEPR_late_z ~ condition_type + (1 | id), data = df_sepr)
anova(m2_2)

m2_3 <- lmer(SEPR_late_z ~ condition_type + Trial.Number + (1 | id), data = df_sepr)
anova(m2_3)

m2_4 <- lmer(SEPR_late_z ~ condition_type * initial_sequence + Trial.Number + (1 | id),
             data = df_sepr)
anova(m2_4)

# => Late SEPR not significant: use early SEPR for all subsequent models

################################################################################
### 6. MODELS BY INITIAL SEQUENCE ------
################################################################################

# --- REG-starting trials ---
m3 <- lmer(SEPR_early_z ~ condition_type + Trial.Number + (1 | id),
           data = df_sepr[df_sepr$initial_sequence == "REG", ])
anova(m3)
emmeans(m3, ~ condition_type) %>% pairs() %>% confint()
model_performance(m3)

# --- RAND-starting trials ---
m4 <- lmer(SEPR_early_z ~ condition_type + Trial.Number + (1 | id),
           data = df_sepr[df_sepr$initial_sequence == "RAND", ])
anova(m4)
emmeans(m4, ~ condition_type) %>% pairs() %>% confint()


################################################################################
### 7. MERGE DEMOGRAPHIC DATA ------
################################################################################

data_filtered <- data %>%
  rename(id = ID) %>%
  distinct(id, .keep_all = TRUE)

df_combined <- df_sepr %>%
  left_join(data_filtered, by = "id") %>%
  mutate(
    Trial.Number_c = as.numeric(scale(Trial.Number, center = TRUE, scale = TRUE)),
    sex    = as.factor(sex),
    age_s  = as.numeric(scale(age)),
    iq_v_z = as.numeric(IQ_verbal_z),
    iq_nv_z = as.numeric(IQ_nonverbal_z)
  )

cat("N participants after merge:", n_distinct(df_combined$id), "\n")

################################################################################
### 8. MODELS WITH DEMOGRAPHIC COVARIATES -------
################################################################################

# --- REG-starting trials with covariates ---
m_REG <- lmer(
  SEPR_early_z ~ condition_type + Trial.Number_c + sex + age_s + iq_v_z + iq_nv_z +
    (1 | id),
  data = df_combined[df_combined$initial_sequence == "REG", ]
)
anova(m_REG)
emmeans(m_REG, ~ condition_type) %>% pairs() %>% confint()
model_performance(m_REG)

# --- RAND-starting trials with covariates ---
m_RAND <- lmer(
  SEPR_early_z ~ condition_type + Trial.Number_c + sex + age_s + iq_v_z + iq_nv_z +
    (1 | id),
  data = df_combined[df_combined$initial_sequence == "RAND", ]
)
anova(m_RAND)
emmeans(m_RAND, ~ condition_type) %>% pairs() %>% confint()

################################################################################
### 9.  DO DEMOGRAPHICS IMPROVE MODEL FIT? -------------------------------
# Goal: show demographics do NOT significantly improve fit (null result support)
# REML = FALSE required for likelihood ratio test between nested models
################################################################################
df_combined_complete <- df_combined %>%
  filter(!is.na(sex), !is.na(age_s), !is.na(iq_v_z), !is.na(iq_nv_z))

m_base <- lmer(SEPR_early_z ~ condition_type + Trial.Number_c + (1 | id),
               data = df_combined_complete, REML = FALSE)

m_demo <- lmer(SEPR_early_z ~ condition_type + Trial.Number_c +
                 sex + age_s + iq_v_z + iq_nv_z + (1 | id),
               data = df_combined_complete, REML = FALSE)

anova(m_base, m_demo)

################################################################################
### 10. MODEL CHECKS FOR KEY MODELS -------------------------------------------
################################################################################

run_model_checks <- function(model, model_name) {
  cat("\n====", model_name, "====\n")
  
  # Singular fit
  cat("Singular fit:", isSingular(model), "\n")
  
  # VIF (collinearity)
  cat("\nVIF:\n")
  print(car::vif(model))
  
  # Robust standard errors (Satterthwaite, handles mild heteroscedasticity)
  cat("\nRobust coef test (CR1):\n")
  print(coef_test(model, vcov = "CR1", test = "Satterthwaite"))
  
  # Visual diagnostics
  check_model(model)                                    # 6-panel performance plot
  simulateResiduals(fittedModel = model, plot = TRUE)  # DHARMa residuals
  
  # Effect size
  cat("\nEffect sizes (eta squared):\n")
  print(eta_squared(model, partial = TRUE))
}

run_model_checks(m_REG,  "m_REG")
run_model_checks(m_RAND, "m_RAND")
run_model_checks(m_demo, "m_demo (full)")

#=> main model m_REG
cohens_f(m_REG, partial = TRUE)

df_combined %>% 
  filter(initial_sequence == "REG") %>%
  count(id, sex) %>% 
  count(sex)

################################################################################
### 11. AGGREGATE SEPR & BPS PER PERSON FOR CROSS-TASK CORRELATION ------------------
################################################################################

# Aggregate BPS data (Mean of BPS_start_500ms per ID and Condition)
bps_agg <- df_bps %>%
  group_by(id, condition_type) %>%
  summarise(
    BPS_mean = mean(BPS_start_500ms, na.rm = TRUE),
    .groups = "drop"
  )

# Aggregate SEPR data, add BPS
df_sepr_person <- df_sepr %>%
  group_by(id, condition_type) %>%
  summarise(
    SEPR_early_mean = mean(SEPR_early, na.rm = TRUE),
    SEPR_early_sd   = sd(SEPR_early,   na.rm = TRUE),
    n_trials        = n(),
    .groups = "drop"
  )%>%
  left_join(bps_agg, by = c("id", "condition_type" ))

# Wide format: one row per participant
df_sepr_wide <- df_sepr_person %>%
  pivot_wider(
    id_cols     = id,
    names_from  = condition_type,
    values_from = c(SEPR_early_mean, SEPR_early_sd, n_trials, BPS_mean),
    names_glue  = "SEPR_RSS_{.value}_{condition_type}"
  )

# Difference score (transition - control): removes individual baseline reactivity
df_sepr_wide <- df_sepr_wide %>%
  mutate(
    SEPR_RSS_diff = SEPR_RSS_SEPR_early_mean_transition - SEPR_RSS_SEPR_early_mean_control
  )

# Save for cross-task correlation
saveRDS(df_sepr_wide, paste0(home_path, data_path, "df_sepr_aggregated_RSS.rds"))

cat("\nAggregated SEPR saved. N =", nrow(df_sepr_wide), "participants\n")

