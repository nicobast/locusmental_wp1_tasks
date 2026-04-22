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

# aggregated data
df_ao <- readRDS(paste0(home_path, data_path_ao, "df_sepr_aggregated_AO.rds"))
df_vo <- readRDS(paste0(home_path, data_path_vo, "sepr_condition.rds"))
df_rss <- readRDS(paste0(home_path, data_path_rss, "df_sepr_aggregated_RSS.rds"))
df_cvs <- readRDS(paste0(home_path, data_path_cvs, "df_cued_agg.rds"))

# bps data 
bps_rss <- readRDS(paste0(home_path, data_path_rss, "bps_data.rds"))
bps_ao <- readRDS(paste0(home_path, data_path_ao, "bps_data.rds"))
bps_cvs <- readRDS(paste0(home_path, data_path_cvs, "bps_data.rds"))


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
  select(c(SEPR_AO_m_oddball,SEPR_AO_m_standard, # AO
           RSS_SEPR_early_mean_control,RSS_SEPR_early_mean_transition, # RSS SEPR
           mean_diff_RAND_to_REG1, mean_diff_REG_to_RAND, mean_diff_RAND_to_REG10, #RSS DIFFERENCES
           SEPR_mean_cued,SEPR_mean_standard, #CVS CUE
           CEPR_CUED_mean_cued, CEPR_CUED_mean_standard)) # CVS SEARCH

# This calculates correlations and handles missing values (NA)
cor_results <- cor(df_cor_rpd_raw, use = "pairwise.complete.obs")

print("Correlation Matrix for all conditions:")
print(round(cor_results, 2))

# 7. Visualization
# This creates a matrix of scatterplots, densities, and correlation values
ggpairs(df_cor_rpd_raw, columns = 1:ncol(df_cor_rpd_raw)) +
  theme_bw() +
  labs(title = "Battery Validation: Correlations across Pupil Tasks")

### Spearman correlation----
cor(df_cor_rpd_raw , use = "pairwise.complete.obs", method = "spearman")


# Load necessary libraries
library(factoextra) # Best for PCA visualization
library(tidyverse)

# 1. Select only your 8 variables
pca_data <- df_cor_rpd_raw[, 1:ncol(df_cor_rpd_raw)]

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
### Difference scores?----
# Calculate Difference Scores (Experimental - Control)
df_diffs <- df_final %>% # Nutze die Rohwerte (nicht die z-Spalten)
  mutate(
    # 1. Berechne die echten Differenzen (Roh-Millimeter oder Roh-Pixel)
    AO_diff_raw  = SEPR_AO_m_oddball - SEPR_AO_m_standard,
    RSS_diff_raw = SEPR_RSS_SEPR_early_mean_transition - SEPR_RSS_SEPR_early_mean_control,
    VO_diff_raw  = sepr_mean_VO_oddball - sepr_mean_VO_standard,
    VS_diff_raw  = CEPR_CUED_mean_cued - CEPR_CUED_mean_standard,
    
    # 2. Skaliere erst JETZT die Differenzwerte, um sie vergleichbar zu machen
    AO_effect  = as.numeric(scale(AO_diff_raw)),
    RSS_effect = as.numeric(scale(RSS_diff_raw)),
    VO_effect  = as.numeric(scale(VO_diff_raw)),
    VS_effects = as.numeric(scale(VS_diff_raw))
  )

# Jetzt die Korrelation neu berechnen
cor_matrix_new <- df_diffs %>% 
  select(AO_effect, RSS_effect, VO_effect, VS_effects) %>% 
  cor(use = "pairwise.complete.obs", method = "spearman")

print(round(cor_matrix_new, 2))

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

t_cued <- t.test(df_cvs$CEPR_mean_z_cued, df_cvs$CEPR_mean_z_standard, paired = TRUE) # One-sample t-test
d_cued <- cohen.d(df_cvs$CEPR_mean_z_cued, df_cvs$CEPR_mean_z_standard, paired = TRUE) # Simple effect size

# --- PRINT FINAL TABLE ---
results <- data.frame(
  Task = c("Auditory Oddball", "RSS (Transition)", "Visual Oddball", "Cued Task"),
  t_stat = c(t_ao$statistic, t_rss$statistic, t_vo$statistic, t_cued$statistic),
  p_val = c(t_ao$p.value, t_rss$p.value, t_vo$p.value, t_cued$p.value),
  Cohen_d = c(d_ao$estimate, d_rss$estimate, d_vo$estimate, d_cued$estimate)
)

print(results)


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

library(psych)
lc_tasks <- df_diffs %>% select(AO_effect, RSS_effect, VO_effect,VS_effects) %>% drop_na()
pca_result <- principal(lc_tasks, nfactors = 1)
print(pca_result$loadings)


# Wir berechnen für jeden Task ein Maß der "Zusatz-Reaktion"
# 1. AO Task
fit_ao <- lm(SEPR_AO_m_oddball ~ SEPR_AO_m_standard, data = df_final, na.action = na.exclude)
df_final$AO_reactivity <- resid(fit_ao)

# 2. RSS Task
fit_rss <- lm(SEPR_RSS_SEPR_early_mean_transition ~ SEPR_RSS_SEPR_early_mean_control, data = df_final, na.action = na.exclude)
df_final$RSS_reactivity <- resid(fit_rss)

# 3. Cued Task 
fit_cued <- lm(CEPR_CUED_mean_cued ~ CEPR_CUED_mean_standard, data = df_final, na.action = na.exclude)
df_final$Cued_reactivity <- resid(fit_cued)

# JETZT korreliere diese Residuen
cor_resid <- df_final %>% 
  select(AO_reactivity, RSS_reactivity, Cued_reactivity) %>% 
  cor(use = "pairwise.complete.obs", method = "spearman")

print(round(cor_resid, 2))


cor_means <- df_final %>%
  select(
    AO_Oddball = SEPR_AO_m_oddball,
    RSS_Transition = SEPR_RSS_SEPR_early_mean_transition,
    Cued_Task = CEPR_CUED_mean_cued
  ) %>%
  cor(use = "pairwise.complete.obs", method = "spearman")

print(round(cor_means, 2))

#### Habituation ---

library(lme4)
library(lmerTest) # Adds p-values to the lme4 output

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


