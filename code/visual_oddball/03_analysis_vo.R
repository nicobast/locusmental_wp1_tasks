# =============================================================================
# Visual Oddball – Analysis
#
# Requires: cleaned df_aoi produced by 02_data_quality_vo.R
#
# Author: Iskra Todorova & Nico Bast
# Last Update: 2026-04-09
# R Version: 4.5.1
#
################################################################################
# =============================================================================

# -----------------------------------------------------------------------------
# Packages
# -----------------------------------------------------------------------------
pkgs <- c("tidyverse", "data.table", "lme4", "lmerTest", "emmeans", "performance", "see")

installed_packages <- pkgs %in% rownames(installed.packages())
if (any(!installed_packages)) {
  install.packages(pkgs[!installed_packages])
}
invisible(lapply(pkgs, library, character.only = TRUE))

# -----------------------------------------------------------------------------
# Paths – adjust to your project folder
# -----------------------------------------------------------------------------
home_path <- "//192.168.88.212/daten/KJP_Studien"
#home_path <- "S:/KJP_Studien"
data_path <- "/LOCUS_MENTAL/6_Versuchsdaten/visual_oddball/"
demo_path <- "/LOCUS_MENTAL/6_Versuchsdaten/"

#data cleaed for 50%NA trials and gaze deviation trials
df_aoi <- readRDS(paste0(home_path, data_path, "eyetracking_ao_clean.rds"))

setDT(df_aoi)

# -----------------------------------------------------------------------------
# Data inspection – 
# -----------------------------------------------------------------------------

cat(sprintf("Loaded df_aoi: %d rows, %d participants\n",
            nrow(df_aoi), length(unique(df_aoi$id))))

#trials by participant
trials_by_participant<-with(df_aoi,by(trial_number,id,function(x){length(unique(x))}))
hist(trials_by_participant)

#baseline corrected pupil dilation progression within trials
ggplot(df_aoi,aes(x=ts_trial,y=pd_corr,group=condition,color=condition,fill=condition))+
  geom_smooth()+xlim(c(0,1.5))+theme_bw()

#--> contrast versus uncorrected pupil size
ggplot(df_aoi,aes(x=ts_trial,y=pd,group=condition,color=condition,fill=condition))+
  geom_smooth()+xlim(c(0,1.5))+theme_bw()

#  =============================================================================
# SEPR & BPS
# Stimulus-Evoked Pupil Response = mean rpd in the 1– 2 s window
# Computed per participant x trial, then merged back
# =============================================================================

# Aggregate SEPR per trial
df_sepr<-df_aoi[df_aoi$ts_trial>0.5 & df_aoi$ts_trial<1.5,]
sepr_trial <- df_sepr[
  ,
  .(sepr = mean(rpd, na.rm = TRUE)),
  by = .(id, trial_number, condition)
]

# Aggregate BPS per id and condition
bps_trial <- df_aoi[
  ,
  .(BPS = mean(baseline_pd, na.rm = TRUE)),
  by = .(id,  condition)
]


#  =============================================================================
#
# ADD DEMO DATA
#
# =============================================================================

# Load processed files
load(paste0(home_path, demo_path, "demo_data.rda"))
data_filtered <-data 
data_filtered <- data_filtered %>%
  rename(id = ID)

# Create a clean version of your wide demographic data
data_filtered_clean <- data_filtered %>%
  distinct(id, .keep_all = TRUE)

df_combined <- sepr_trial %>%
  left_join(data_filtered_clean, by = "id")

# scale variables
df_combined <- df_combined %>%
  mutate(
    sex = as.factor(sex),
    age_s = scale(age), # Centers and scales age
    # IQs are already z-scores, so just ensure they are numeric
    iq_v_z = as.numeric(IQ_verbal_z),
    iq_nv_z = as.numeric(IQ_nonverbal_z)
  )

# =============================================================================
# MODEL 1 – SEPR ~ trial condition
# Fixed effect : trial (Oddball vs. Standard)
# Random effect: random intercept per participant
# =============================================================================

hist(df_combined$sepr)

m1 <- lmer(sepr ~ condition + (1 | id) + (1| trial_number), data = df_combined)
summary(m1)

cat("--- ANOVA table (Type III, Satterthwaite df) ---\n")
print(anova(m1))

cat("\n--- Fixed effects summary ---\n")
print(summary(m1)$coefficients)

cat("\n--- Pairwise comparisons (Tukey-adjusted) ---\n")
emm1 <- emmeans(m1, pairwise ~ condition, adjust = "tukey")
print(emm1$contrasts)

cat("\n--- Estimated marginal means ---\n")
print(emm1$emmeans)

# =============================================================================
# MODEL PERFORMANCE
# =============================================================================

# --- R2 (marginal = fixed effects only, conditional = fixed + random) --------
cat("--- R2 (Nakagawa & Schielzeth) ---\n")
print(r2(m1))

# --- Intraclass Correlation Coefficient (ICC) --------------------------------
# Proportion of variance explained by the random (participant) effect
cat("\n--- ICC (random intercept variance / total variance) ---\n")
print(icc(m1))

# --- Full performance summary ------------------------------------------------
cat("\n--- Full performance summary ---\n")
print(model_performance(m1))

# --- Residual diagnostics (plots saved to file) ------------------------------
cat("\n--- Residual diagnostics plots ---\n")

# Check all assumptions at once (normality, homoscedasticity, outliers, etc.)
check_plots <- check_model(m1)
print(check_plots)

# --- Individual checks -------------------------------------------------------
cat("\n--- Normality of residuals (Shapiro-Wilk) ---\n")
print(check_normality(m1))

cat("\n--- Homoscedasticity (Breusch-Pagan) ---\n")
print(check_heteroscedasticity(m1))

cat("\n--- Outliers (Cook's distance) ---\n")
print(check_outliers(m1))

cat("\n--- Singularity check ---\n")
print(check_singularity(m1))

# =============================================================================
#
# MODEL 2 – SEPR ~ trial condition + trial_number + Age + Sex + IQ
#
# =============================================================================

# Adding Age, Sex and IQs as covariates
m_final_full <- lmer(
  sepr ~ condition 
  + sex + age_s + iq_v_z + iq_nv_z + 
    (1 | id) + (1 |trial_number), 
  data = df_combined, 
  REML = T
)

anova(m_final_full)
summary(m_final_full)

model_performance(m_final_full)

# =============================================================================
#
# MODEL 3 – SEPR ~ Clincial measures
#
# =============================================================================

# Adding clincial measures
m_3 <- lmer(
  sepr ~ condition * 
    (CBCL_T_INT + CBCL_T_EXT + 
       CBQ_Kontrollfaehigkeit_Summenwert + CBQ_Negativer_Affekt_Summenwert + CBQ_Offenheit_Summenwert) + 
    (1 | id) + (1 |trial_number), 
  data = df_combined, 
  REML = T
)

anova(m_3)
model_performance(m_3)

require(parameters)
standardize_parameters(m_3)

# =============================================================================
#
# Aggregate Data
#
# =============================================================================

sepr_condition <- sepr_trial[
  ,
  .(
    sepr_mean = mean(sepr, na.rm = TRUE),
    n_trials  = .N
  ),
  by = .(id, condition)
]

sepr_condition <- merge(sepr_condition, bps_trial, by = c("id", "condition"), all.x=TRUE)

# Save 
output_file <- paste0(home_path, data_path, "sepr_condition.rds")
saveRDS(sepr_condition, file = output_file)
