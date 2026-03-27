################################################################################
#
# Rapid Sound Sequences Data Analysis
# Author: Iskra Todorova & Nico Bast
# Last Update: 26.03.2026
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
          "ggeffects"
          
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
#home_path <- "S:/KJP_Studien"
home_path <- "C:/Users/nico/Nextcloud/project_locusmental_wp1"
#data_path <- "/LOCUS_MENTAL/6_Versuchsdaten/rapid_sound_sequences/"
data_path <- "/data/rapid_sound_sequences/preprocessed/"


# Load processed files
df <- readRDS(paste0(home_path, data_path, "df_loose_high.rds")) # use the most intermediate version, gaze in the center 200 px, Control: min 4 trial, Transition: min 6 trials
df_et <- readRDS(paste0(home_path, data_path, "eyetracking_rss_revNB.rds"))

###############################################################################

### Filter the raw data ----
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

# convert transition timestamp to numeric for further calculations
df_et_filtered$transition_timestamp_1 <- as.numeric(df_et_filtered$transition_timestamp_1)

#create relative timestamp (relative to transition, for control trials relative to 3 sec)
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

hist(df_et_filtered$ts_sequence)
hist(df_et_filtered$rel_time)
hist(df_et_filtered$ts_trial) #does not make much sense to use

### BPS and SEPR anaylsis -----
### As in other tasks

#  Define BPS as 500 ms and 1000 ms before transition
df_bps <- df_et_filtered %>%
  filter(rel_time >= -1.000 & rel_time <= 0) %>%
  group_by(id, Condition, Trial.Number) %>%
  summarise(
    BPS_start_500ms = mean(pd[rel_time >= -0.500 & rel_time <= 0], na.rm = TRUE),
    BPS_start_1000ms = mean(pd, na.rm = TRUE),
    .groups = "drop"
  )

# JOin with pupil data to calculate corrected pd
df_et_filtered <- df_et_filtered %>%
  left_join(df_bps,
            by = c("id", "Condition", "Trial.Number"))


df_et_filtered <- df_et_filtered %>%
  mutate(
    pd_corr_500 = pd - BPS_start_500ms,
    pd_corr_1000 = pd - BPS_start_1000ms
  )

# Response time Window 1.5 ms till 3 seconds
df_sepr<- df_et_filtered %>%
  filter(rel_time >= 0.5 & rel_time <= 3) %>%
  group_by(id, Condition, Trial.Number) %>%
  summarise(
    SEPR_500 = mean(pd_corr_500, na.rm = TRUE),
    SEPR_1000 = mean(pd_corr_1000, na.rm = TRUE),
    .groups = "drop"
  )

# Response time Window 1.5 ms till 3 seconds
df_sepr_early<- df_et_filtered %>%
  filter(rel_time >= 0.5 & rel_time <= 1.5) %>%
  group_by(id, condition_type, initial_sequence, Trial.Number) %>%
  summarise(
    SEPR = mean(pd_corr_500, na.rm = TRUE),
    .groups = "drop"
  )

# Response time Window 1.5 ms till 3 seconds
df_sepr_late<- df_et_filtered %>%
  filter(rel_time >= 2 & rel_time <= 3) %>%
  group_by(id, condition_type, initial_sequence, Trial.Number) %>%
  summarise(
    SEPR = mean(pd_corr_500, na.rm = TRUE),
    .groups = "drop"
  )

# scale the pipul response
df_sepr<- df_sepr%>%
  mutate(
    SEPR_500_z = as.numeric(scale(SEPR_500)),
    SEPR_1000_z =as.numeric(scale(SEPR_1000))
  )

df_sepr_early<- df_sepr_early%>%
  mutate(
    SEPR_z = as.numeric(scale(SEPR))
  ) 

df_sepr_late<- df_sepr_late%>%
  mutate(
    SEPR_z = as.numeric(scale(SEPR))
  ) 


# Model with correction for BPS 500 ms
model1 <- lmer(SEPR_500_z ~ Condition + Trial.Number +
                 (1 | id),
               data = df_sepr)


#
model1 <- lmer(SEPR_z ~ condition_type * initial_sequence +
                 (1 | id) + (1|Trial.Number),
               data = df_sepr_early)
anova(model1)
emmeans(model1, pairwise ~ initial_sequence | condition_type)


model1 <- lmer(SEPR_z ~ condition_type * initial_sequence +
                 (1 | id) + (1|Trial.Number),
               data = df_sepr_late)
anova(model1)
emmeans(model1, pairwise ~ condition_type | initial_sequence)


model1 <- lmer(SEPR_500_z ~ Condition +
                 (1 | id) + (1|Trial.Number),
               data = df_sepr)
anova(model1)
emmeans(model1, pairwise ~ condition_type | initial_sequence)


#### visualization ####
names(df_et_filtered)

#pupil size in control versus transition
ggplot(df_et_filtered, aes(x = rel_time, y = pd_corr_500,fill = condition_type, color =condition_type)) +
  geom_smooth()+
  xlim(-0.5,3)+
  theme_bw()

ggplot(df_et_filtered, aes(x = rel_time, y = pd,fill = condition_type, color =condition_type)) +
  geom_smooth()+
  xlim(-3,3)+
  theme_bw()


#pupil size in control versus transition
ggplot(df_et_filtered, aes(x = rel_time, y = pd_corr_500,
                           group=interaction(condition_type,initial_sequence),
                           fill = condition_type, color =condition_type, linetype=initial_sequence)) +
  geom_smooth()+
  xlim(-0.5,3)+
  theme_bw()


ggplot(df_et_filtered, aes(x = rel_time, y = pd,
                           group=interaction(condition_type,initial_sequence),
                           fill = condition_type, color =condition_type, linetype=initial_sequence)) +
  geom_smooth()+
  xlim(-3,3)+
  theme_bw()



#pupil size in control versus transition
ggplot(df_et_filtered, aes(x = rel_time, y = pd_corr_500,color=Condition,fill=Condition)) +
  geom_smooth()+
  xlim(-0.5,3)+
  theme_bw()

ggplot(df_et_filtered, aes(x = rel_time, y = pd,color=Condition,fill=Condition)) +
  geom_smooth()+
  xlim(-3,3)+
  theme_bw()




#rel_time - time from transition
ggplot(df_et_filtered, aes(x = rel_time, y = pd_corr_500, color=condition_type)) +
  geom_smooth()+
  xlim(-3,3)




# a<-ggplot(df_et_filtered, aes(x = ts_sequence, y = pd_corr_500, fill = Condition, color =Condition)) +
#   geom_smooth() +
#   scale_fill_brewer(palette = "Set1") + 
#   scale_color_brewer(palette = "Set1", guide= "none") + 
#   theme_minimal() +
#   theme(
#     plot.background = element_rect(fill = "white", color = NA),  # Changes entire plot background
#   )+
#   xlim(2.5,6)+
#   labs(
#     x = "Sequence Time (seconds)",
#     y = "Pupil Dilation Corrected (mm)",
#     title = "Pupil Dilation Changes Across Conditions"
#   ) +  
#   geom_vline(xintercept = 3, linetype = "dashed", color = "black", alpha = 0.7) +
#   annotate("text", x = 3.2, y = 0.05, 
#            label = "Transition", hjust = 0, fontface = "bold") +
#   theme(
#     legend.title = element_text(face = "bold", size = 12),
#     legend.position = "bottom",
#     axis.title = element_text(size = 12, face = "bold"),
#     axis.text = element_text(size = 11),
#     plot.title = element_text(hjust = 0.5, face = "bold", size = 14)
#   )
# print(a)


### Subject -Level Anaylsis ------

# 1. Subject-level Averages using Tracker Precision
df_subject_avg <- df_et_filtered %>%
  # We convert rel_time into "sample counts" (60 samples per second)
  # This aligns every participant to the exact 16.67ms tracker grid
  mutate(sample_idx = round(rel_time * 60)) %>%
  
  # Group by ID, Condition, and the specific Sample
  group_by(id, Condition, sample_idx) %>%
  summarise(pd_subject = mean(pd_corr_500, na.rm = TRUE), .groups = "drop") %>%
  
  # Optional: Convert sample_idx back to real time for plotting later
  mutate(time_seconds = sample_idx / 60)

# 2. Pivot to calculate the difference (Transition - Control) per participant
df_subject_diffs <- df_subject_avg %>%
  select(id, sample_idx, time_seconds, Condition, pd_subject) %>%
  pivot_wider(names_from = Condition, values_from = pd_subject) %>%
  mutate(
    diff_REG10_to_RAND20 = `REG10-RAND20` - `REG10`,
    diff_RAND20_to_REG10 = `RAND20-REG10` - `RAND20`,
    diff_RAND20_to_REG1   = `RAND20-REG1` - `RAND20`
  )

# 3. Grand Average of the Differences
df_grand_avg_diffs <- df_subject_diffs %>%
  # Select only the difference columns
  select(sample_idx, time_seconds, starts_with("diff_")) %>%
  # Make it long for averaging and plotting
  pivot_longer(cols = starts_with("diff_"), 
               names_to = "Transition_Type", 
               values_to = "PD_Diff") %>%
  # Average across all participants
  group_by(Transition_Type, time_seconds) %>%
  summarise(
    mean_diff = mean(PD_Diff, na.rm = TRUE),
    se_diff = sd(PD_Diff, na.rm = TRUE) / sqrt(n()),
    .groups = "drop"
  )

# 4. Reshape for ggplot
df_plot_long <- df_subject_diffs %>%
  select(id, time_seconds, `diff_REG10_to_RAND20`, `diff_RAND20_to_REG10`, `diff_RAND20_to_REG1`) %>%
  pivot_longer(
    cols = -c(id, time_seconds), 
    names_to = "Transition_Type", 
    values_to = "PD_Difference"
  )

# 5.  plot
ggplot(df_plot_long, aes(x = time_seconds, y = PD_Difference, color = Transition_Type, fill = Transition_Type)) +
  # geom_smooth calculates the mean line AND the confidence interval automatically
  # method = "gam" or "loess" works well for pupil data
  geom_smooth(method = "gam", formula = y ~ s(x, bs = "cs"), size = 1.2) +
  xlim(-0.5,3)+
  
  # Add a horizontal line at 0 (No difference)
  geom_hline(yintercept = 0, linetype = "dashed", color = "black", alpha = 0.6) +
  
  # Add a vertical line at the event onset
  geom_vline(xintercept = 0, color = "darkgrey") +
  
  theme_minimal() +
  labs(
    title = "Sequential Difference Waves (SEPR)",
    subtitle = "Smoothed Mean with 95% Confidence Interval (Subject-Level)",
    x = "Time from Event (seconds)",
    y = "Δ Pupil Diameter (Absolute units)",
    color = "Transition Type",
    fill = "Transition Type"
  ) +
  scale_color_brewer(palette = "Set1") +
  scale_fill_brewer(palette = "Set1")

# ==============================================================================
# PUPILLOMETRY ANALYSIS SCRIPT: TASK EFFECTS & SEPR
# Focus: Transitions between Regularity and Randomness
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. PRE-PROCESSING & BASELINE CORRECTION
# ------------------------------------------------------------------------------

# Step A: Calculate Baseline (Mean PD during 500ms before transition)
df_baseline <- df_et_filtered %>%
  filter(rel_time >= -0.500 & rel_time <= 0) %>%
  group_by(id, Condition, Trial.Number) %>%
  summarise(baseline_pd = mean(pd, na.rm = TRUE), .groups = "drop")

# Step B: Apply Baseline & Filter Analysis Window (0 to 3 seconds) 
# !!! NOTE: WITHOUT TRIAL NUMBER, AVERAGE ACROSS ALL TRIALS PER PARTICIPANT
df_clean <- df_et_filtered %>%
  left_join(df_baseline, by = c("id", "Condition", "Trial.Number")) %>%
  mutate(pd_corr = pd - baseline_pd) %>%
  filter(rel_time >= 0 & rel_time <= 3.0)

# Step C: Downsample/Bin for Statistical Validity (100ms bins)
# This reduces autocorrelation and makes Mixed Models computationally feasible
df_stats_bins <- df_clean %>%
  mutate(time_bin = round(rel_time, 1)) %>% # 0.1s = 100ms bins
  group_by(id, Condition, time_bin) %>%
  summarise(pd_binned = mean(pd_corr, na.rm = TRUE), .groups = "drop")

# ------------------------------------------------------------------------------
# 2. GROWTH CURVE ANALYSIS (GCA) 
# ------------------------------------------------------------------------------

# Run the Linear Mixed Model
# Fixed Effects: Condition * Time interaction (detects slope differences)
# Random Effects: Random intercepts and slopes per participant
model_gca <- lmer(pd_binned ~ Condition * time_bin + (1 | id), 
                  data = df_stats_bins)

# View the ANOVA table (Overall effects)
anova(model_gca)

# ------------------------------------------------------------------------------
# 3. POST-HOC COMPARISONS 
# ------------------------------------------------------------------------------

# Comparison A: Compare the SLOPES (Rate of Habituation vs. Recognition)
# This proves that breaking regularity stops habituation.
slopes_comp <- emtrends(model_gca, pairwise ~ Condition, var = "time_bin")
print(slopes_comp)

# Comparison B: Compare the Overall Levels (Intercepts)
# This proves if one condition caused an overall "Shock" shift.
means_comp <- emmeans(model_gca, pairwise ~ Condition)
print(means_comp)

model_performance(model_gca)
check_residuals(model_gca)
check_heteroscedasticity(model_gca)
check_normality(model_gca)
# => Not Good, everything violated, model is not appropriate

# ------------------------------------------------------------------------------
# 4. FIND THE RIGHT MODEL
# ------------------------------------------------------------------------------

# Ensure time_bin is treated as a continuous numeric variable
df_stats_bins$time_bin <- as.numeric(df_stats_bins$time_bin)

# --- MODEL 1: LINEAR ---
m_linear <- lmer(pd_binned ~ Condition * time_bin + (1 | id), 
                 data = df_stats_bins, REML = FALSE)

# --- MODEL 2: QUADRATIC  ---
# poly(time_bin, 2) creates a linear and a quadratic term
m_quadratic <- lmer(pd_binned ~ Condition * poly(time_bin, 2) + (1 | id), 
                    data = df_stats_bins, REML = FALSE)

# --- MODEL 3: CUBIC  ---
m_cubic <- lmer(pd_binned ~ Condition * poly(time_bin, 3) + (1 | id), 
                data = df_stats_bins, REML = FALSE)

# 1. Compare using Likelihood Ratio Test (LRT)
comparison_table <- anova( m_linear, m_quadratic, m_cubic)
print(comparison_table)

# 2. Extract R2 (Marginal and Conditional)
performance_summary <- model_performance(m_linear, estimator = "ML") %>%
  bind_rows(model_performance(m_quadratic, estimator = "ML")) %>%
  bind_rows(model_performance(m_cubic, estimator = "ML")) %>%
  mutate(Model = c("Linear", "Quadratic", "Cubic"))

print(performance_summary)
# => R2 Cond for linear and cubic cant be estimated,liner to quadratic big improvement, quadratic to cubic moderate improvement
# cubic lowest AIC

# CUBIC MODEL IMPROVED

# uncorrelated random slopes
m_cubic_clean <- lmer(
  pd_binned ~ Condition * poly(time_bin, 3) +
    (1 | id),
  data = df_stats_bins,
  REML = FALSE
)
# => failed to converge

summary(m_cubic_clean)

#compare
anova(m_quadratic, m_cubic_clean)
#=> quadratic better

# Quadratic model
summary(m_quadratic)

model_performance(m_quadratic)
check_residuals(m_quadratic)
check_heteroscedasticity(m_quadratic)
check_normality(m_quadratic)
# => violated

# ADDING TRIAL NUMBER FOR THE MODELING
df_trial_stats_bins <- df_clean %>%
  mutate(time_bin = round(rel_time, 1)) %>% # 0.1s = 100ms bins
  group_by(id, Condition,Trial.Number, time_bin) %>%
  summarise(pd_binned = mean(pd_corr, na.rm = TRUE), .groups = "drop")

# --- MODEL 1: LINEAR ---
m_linear <- lmer(pd_binned ~ Condition * time_bin + 
                   (1 + time_bin | id) +  # participant-level intercept + slope
                   (1 | id:Trial.Number),  # trial-level intercept
                 data = df_trial_stats_bins, REML = FALSE)

# --- MODEL 1: QUADRATIC ---
# Only random intercepts at participant level; trial intercepts included
m_quadratic <- lmer(pd_binned ~ Condition * poly(time_bin, 2) + 
                      (1 | id) + (1 | id:Trial.Number), 
                    data = df_trial_stats_bins, REML = FALSE)


# --- MODEL 1: CUBIC ---
m_cubic <- lmer(pd_binned ~ Condition * poly(time_bin, 3) + 
                  (1 | id) + (1 | id:Trial.Number), 
                data = df_trial_stats_bins, REML = FALSE)


anova(m_linear, m_quadratic, m_cubic)
anova(m_quadratic, m_cubic)

# => Problems so center time and trial number

df_trial_stats_bins <- df_trial_stats_bins %>%
  mutate(
    time_bin_c = scale(time_bin, center = TRUE, scale = TRUE),
    Trial.Number_c = scale(Trial.Number, center = TRUE, scale = TRUE)
  )

# Cubic model with raw, later easier for trends and emmeans calculations
m_cubic <- lmer(pd_binned ~ Condition * poly(time_bin_c, 3, raw =TRUE) + Trial.Number_c + 
                  (1 | id) + (1 | id:Trial.Number), 
                data = df_trial_stats_bins, REML = FALSE)

model_performance(m_cubic)
plot(resid(m_cubic) ~ fitted(m_cubic))
abline(h = 0, col = "red")
qqnorm(resid(m_cubic))
qqline(resid(m_cubic))

anova(m_cubic)
emmeans(m_cubic, pairwise ~Condition)
emtrends(m_cubic, pairwise ~ Condition, var="time_bin_c")

# Plot the model
plot_data <- ggpredict(m_cubic, terms = c("time_bin_c [all]", "Condition"))

# Create the "S-Curve" Plot
ggplot(plot_data, aes(x = x, y = predicted, color = group, fill = group)) +
  # Add shaded confidence intervals (95% CI)
  #geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = 0.15, color = NA) +
  # Add the main cubic lines
  geom_line(linewidth = 1.2) +
  # Customize the look
  labs(
    title = "Pupil Dilation Trajectories by Condition",
    subtitle = "Modeled using Cubic Growth Curve Analysis",
    x = "Time (centered and scaled)",
    y = "Predicted Pupil Dilation",
    color = "Condition",
    fill = "Condition"
  ) +
  theme_minimal() +
  theme(
    legend.position = "bottom",
    text = element_text(size = 14),
    panel.grid.minor = element_blank()
  ) +
  # Use a distinct color palette
  scale_color_brewer(palette = "Set1") +
  scale_fill_brewer(palette = "Set1")

###### ADD DEMO DATA ----

# Load processed files
load("C:/Users/nico/Nextcloud/project_locusmental_wp1/data/demo_data_rss.rda")
data <- data_filtered
data_filtered <- data_filtered %>%
  rename(id = ID)

# Create a clean version of your wide demographic data
data_filtered_clean <- data_filtered %>%
  distinct(id, .keep_all = TRUE)
# Verification: This should now return 1
nrow(data_filtered_clean %>% filter(id == "LM_104"))

df_combined <- df_trial_stats_bins %>%
  left_join(data_filtered_clean, by = "id")

# merge with df for the models
df_combined <- df_combined %>%
  mutate(
    sex = as.factor(sex),
    age_s = scale(age), # Centers and scales age
    # IQs are already z-scores, so just ensure they are numeric
    iq_v_z = as.numeric(IQ_verbal_z),
    iq_nv_z = as.numeric(IQ_nonverbal_z)
  )

# Adding Age, Sex and IQs as covariates
m_final_full <- lmer(
  pd_binned ~ Condition * poly(time_bin_c, 5, raw = TRUE) + 
    Trial.Number_c + sex + age_s + iq_v_z + iq_nv_z + 
    (1 | id) + (1 | id:Trial.Number), 
  data = df_combined, 
  REML = FALSE
)
anova(m_final_full)
summary(m_final_full)
#=> lost 10 participant since IQ is still not in the Database

# Model without IQ
m_final <- lmer(
  pd_binned ~ Condition * poly(time_bin, 7, raw = TRUE) + 
    Trial.Number_c + sex + age_s + 
    (1 | id) + (1 | id:Trial.Number), 
  data = df_combined, 
  REML = FALSE
)

#compare pupil size at different timepoints
emmeans(m_final,pairwise~Condition|time_bin,at=list(time_bin=c(0,1,2,3)))

anova(m_final)
summary(m_final)
model_performance(m_final)

# Plot
plot_data_final <- ggpredict(m_final, terms = c("time_bin [all]", "Condition"))

ggplot(plot_data_final, aes(x = x, y = predicted, color = group, fill = group)) +
  #geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = 0.1, color = NA) +
  geom_line(linewidth = 1.2) +
  scale_color_brewer(palette = "Set1") +
  labs(
    title = "Adjusted Pupil Trajectories",
    subtitle = "Controlled for Age, Sex)",
    x = "Time (Standardized)",
    y = "Predicted Pupil Dilation",
    color = "Condition"
  ) +
  theme_minimal()
