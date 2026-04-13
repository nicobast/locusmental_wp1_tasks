## SETUP ####

sessionInfo()

# REQUIRED PACKAGES
pkgs <- c("tidyverse",
          "data.table", 
          "lme4",
          "lmerTest",
          "emmeans",
          "performance",
          "see",
          "kableExtra")

installed_packages <- pkgs %in% rownames(installed.packages())
if (any(!installed_packages)) {
  install.packages(pkgs[!installed_packages])
}
invisible(lapply(pkgs, library, character.only = TRUE))

# PATHS (adjust to your project)

home_path <- "S:/KJP_Studien"
#home_path <- "//192.168.88.212/daten/KJP_Studien"
data_path <- "/LOCUS_MENTAL/6_Versuchsdaten/visual_search_task/"

# Load files
df <- readRDS(paste0(home_path, data_path, "df_aoi_cleaned.rds"))
df_trial <- readRDS(paste0(home_path, data_path, "trialdata_processed.rds"))
df_trial_hits_only <- readRDS(paste0(home_path, data_path, "trial_hits_only_cleaned.rds"))
df_trial_hits <- readRDS(paste0(home_path, data_path, "trial_hits_cleaned.rds"))


# CREATE TRIAL-LEVEL SUMMARY
# Calculate trial-level averages
trial_level <- df[
  , .(
    mean_baseline_pd = mean(mean_baseline_pd, na.rm = TRUE),
    mean_CEPR = mean(CEPR, na.rm = TRUE),
    mean_SEPR = mean(SEPR, na.rm = TRUE)
    # RPD_short = mean(RPD_short, na.rm = TRUE)
  ), 
  by = .(id, trial_number, trial_type)  
]
df_trial_filtered <- trial_level[df_trial_hits, on = .(id, trial_number), nomatch = 0]

# CEPR by condition model ----

m1 <- lmer(scale(mean_CEPR) ~ trial_type + (1|id) + (1|trial_number), data = df_trial_filtered)

model_performance(m1)
anova(m1)
emmeans(m1, pairwise ~ trial_type)
##--> higher CEPR for cued trials

# SEPR by condition model ----

m2 <- lmer(scale(mean_SEPR) ~ trial_type + (1|id) + (1|trial_number), data = df_trial_filtered)

model_performance(m2)
anova(m2)

emmeans(m2, pairwise ~ trial_type)
##--> higher SEPR for cued trials


# Hit speed models (preliminary models) ----

# Hit time is defined as the duration from the start of the search phase until the first hit.
# A hit occurs when the gaze position first lands on the target and remains there for at least 7 consecutive sampling events (or approximately 100 ms).

trial_hits_only <- df_trial_filtered[df_trial_hits_only, on = .(id, trial_number)]

merged_df <- merge(
  df_trial_filtered[, c("id", "trial_number", "mean_baseline_pd","mean_CEPR", "mean_SEPR")],
  df_trial_hits[, c("id", "trial_number", "hit", "hit_time", "target_position", "trial_type")],
  by = c("id", "trial_number"),
  all.x = TRUE   # optional: left join
)

merged_df_hit <- merged_df[hit == TRUE]

### Hit time basic model

hist(merged_df_hit$hit_time)

#hit_time predicted by trial_type with random intercept for participant
m_hit <- lmer(scale(hit_time) ~ trial_type + (1|id) + (1|trial_number), 
              data = merged_df_hit[merged_df_hit$hit_time>=0.5,])

model_performance(m_hit)
anova(m_hit)

# Check assumptions
plot(m_hit)  # residuals vs fitted
qqnorm(resid(m_hit))  # normality of residuals
qqline(resid(m_hit))

### Hit time + target_position

# Add target positions to basic model
m_hit_position <- lmer(scale(hit_time) ~ trial_type * target_position + (1|id), 
                       data = merged_df_hit)

model_performance(m_hit_position)
anova(m_hit_position)

emm_hit_position <- emmeans(m_hit_position, ~ target_position)
print(emm_hit_position)

print(pairs(emm_hit_position))
#--> faster at top -_> thus consider as covariate


### Hit time + target color 

merged_df_hit <- merged_df_hit %>%
  left_join(
    df_trial %>% select(id, trial_number, target_color),
    by = c("id", "trial_number")
  )

m_rt_color <- lmer(
  scale(hit_time) ~ trial_type + target_color + (1 | id),
  data = subset(merged_df_hit, hit == 1)
)

anova(m_rt_color)

emm_rt_color <- emmeans(m_rt_color, ~ target_color)
print(emm_rt_color)

print(pairs(emm_rt_color))
model_performance(m_rt_color)

### Hit time + target color + target position

m_rt_color_pos <- lmer(
  scale(hit_time) ~ trial_type * target_position + target_color + (1 | id),
  data = subset(merged_df_hit, hit == 1)
)

anova(m_rt_color_pos)

emm_rt_color_pos <- emmeans(m_rt_color_pos, ~ target_color)
print(emm_rt_color_pos)

print(pairs(emm_rt_color_pos))
model_performance(m_rt_color_pos)

### Hit time predicted by trial type, target position and SEPR

merged_df$mean_SEPR_z<-scale(merged_df$mean_SEPR)
m_rt_sepr <- lmer(
  scale(hit_time) ~ trial_type * mean_SEPR_z + target_position + (1 | id) + (1|trial_number),
  data = subset(merged_df, hit == 1)
)

anova(m_rt_sepr)

##--> during cued trials, a higher SEPR is associated with slower hit time

# emm_rt_sepr <- emmeans(
#   m_rt_sepr,
#   pairwise ~ trial_type | mean_SEPR_z + target_position ,
#   at = list(mean_SEPR_z = c(-1, 0, 1))  # z.B. 1 SD unter/über Mittelwert
# )
# 
# summary(emm_rt_sepr)
# pairs(emm_rt_sepr)
# 

# emm_df <- as.data.frame(emm_rt_sepr)
# ggplot(emm_df, aes(x = target_position, y = emmean,
#                    color = factor(mean_SEPR), group = mean_SEPR)) +
#   geom_point(size = 3) +
#   geom_line(linewidth = 1) +
#   geom_errorbar(aes(ymin = lower.CL, ymax = upper.CL), width = 0.15) +
#   labs(
#     title = "Interaction: Target Position × SEPR on Reaction Time",
#     subtitle = "Estimated marginal means (±95% CI)",
#     x = "Target Position",
#     y = "Estimated mean (scaled RT)",
#     color = "SEPR level\n(-1 = low, 0 = avg, 1 = high)"
#   ) +
#   theme_minimal(base_size = 14)


# Hit likelihood by pupillary responses (CEPR, SEPR)-----

# CEPR hit models
##--> limited to cued trials as only for those a CEPR is interpretable

cor(merged_df$mean_CEPR, merged_df$mean_SEPR, use = "complete.obs")
#=0.52

    with(merged_df[merged_df$trial_type=='cued'],
         cor(mean_CEPR, mean_SEPR, use = "complete.obs"))
    with(merged_df[merged_df$trial_type=='standard'],
         cor(mean_CEPR, mean_SEPR, use = "complete.obs"))
    ##--> association of CEPR and SEPR might be lower in standard trials

merged_df$mean_CEPR_z<-scale(merged_df$mean_CEPR)
merged_df$mean_SEPR_z<-scale(merged_df$mean_SEPR)
m_acc_3 <- glmer(hit ~ mean_CEPR_z + mean_SEPR_z + target_position + (1 | id) + (1|trial_number), 
                 data = merged_df[merged_df$trial_type=='cued',], family = binomial)


model_performance(m_acc_3)
summary(m_acc_3)
#=> high CEPR, more accuracy
#=> high SEPR, less accuracy


# Hit speed by pupillary responses (CEPR, SEPR)-----

merged_df_hit$mean_CEPR_z<-scale(merged_df_hit$mean_CEPR)
merged_df_hit$mean_SEPR_z<-scale(merged_df_hit$mean_SEPR)
m_speed <- lmer(scale(hit_time) ~  mean_CEPR_z + mean_SEPR_z + target_position + (1 | id) + (1|trial_number), 
                data = merged_df_hit[merged_df_hit$trial_type=='cued',])

model_performance(m_speed)
summary(m_speed)
#=> high CEPR --> faster to hit
#=> high SEPR -_> slower to hit

# Visualizations ----

## Pupil Corrected Response from the start of the beep phase until the end of the search phase

ggplot(df, aes(x = ts_trial, y = pd_corr, fill= trial_type, color = trial_type)) +
  geom_smooth() +
  xlim(c(0,2))+
  labs(
    title = " baseline corrected PD Oddball vs. Standard, only AOI",
    x = "Time(s)",
    y = "Corrected PD"
  ) +
  theme_minimal()+
  theme(legend.position = "right")


# Demo Data ####

# Load your saved demo_data
#demo_path <- "//192.168.88.212/daten/KJP_Studien/LOCUS_MENTAL/6_Versuchsdaten/"
demo_path <- "/LOCUS_MENTAL/6_Versuchsdaten/"
load(paste0(home_path, demo_path, "demo_data.rda"))
#load(file.path(demo_path, "demo_data.rda"))

data_filtered <- data
data_filtered <- data_filtered %>%
  rename(id = ID)

# Create a clean version of your wide demographic data
data_filtered_clean <- data_filtered %>%
  distinct(id, .keep_all = TRUE)

df_combined <- merged_df %>%
  left_join(data_filtered_clean, by = "id")

df_combined_hits_only <- merged_df_hit %>%
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


# merge with df for the models
df_combined_hits_only <- df_combined_hits_only %>%
  mutate(
    sex = as.factor(sex),
    age_s = scale(age), # Centers and scales age
    # IQs are already z-scores, so just ensure they are numeric
    iq_v_z = as.numeric(IQ_verbal_z),
    iq_nv_z = as.numeric(IQ_nonverbal_z)
  )


m1 <- lmer(mean_CEPR ~ trial_type + (1|id), data = df_trial_filtered, REML = FALSE)

# Adding Age, Sex and IQs as covariates
m_1 <- lmer(
  mean_CEPR ~ trial_type + 
     sex + age_s + iq_v_z + iq_nv_z + 
    (1 | id) , 
  data = df_combined, 
  REML = FALSE
)
anova(m_1)


m_2 <- lmer(
  mean_SEPR ~ trial_type + 
    sex + age_s + iq_v_z + iq_nv_z + 
    (1 | id) , 
  data = df_combined, 
  REML = FALSE
)
anova(m_2)

# To which additional models should i add the covariates to ?

m_1 <- lmer(
  mean_CEPR ~ trial_type + 
    CBCL_T_INT + CBCL_T_EXT + CBQ_Negativer_Affekt_Summenwert + 
    (1 | id) + (1 | trial_number), 
  data = df_combined
)

anova(m_1)


### Aggregate data ----

# Aggregate only the cued trials
# Replace 'df_cued_raw' with the actual name of your 4th task dataframe
df_cued_agg <- df_combined %>%
  filter(trial_type == "cued") %>%
  group_by(id) %>%
  summarize(
    SEPR_CUED_mean = mean(mean_CEPR_z, na.rm = TRUE),
    n_trials_cued  = n() # Good practice to keep track of trial counts
  )

# Save 
output_file <- paste0(home_path, data_path, "df_cued_agg.rds")
saveRDS(df_cued_agg, file = output_file)
