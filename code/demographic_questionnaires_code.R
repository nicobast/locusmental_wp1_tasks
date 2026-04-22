################################################################################
# 
# Demographic and Questionnaires Data
# Author: Iskra Todorova
# Last Update: 22.04.2026
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

pkgs <- c("readxl",
          "data.table", # efficient due to parallelization
          "ggplot2", # creating graphs
          "dplyr",
          "psych",
          "dplyr",
          "lubridate"
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


# PATHS

data_path <- "S:/KJP_Studien/LOCUS_MENTAL/8_Datenbank/Export"
cbcl_file <- file.path(data_path, "cbcl_4_18.xlsx")
ari_file <- file.path(data_path, "ari_eltern.xlsx")
biq_file <- file.path(data_path, "biq.xlsx")
cbq_file <- file.path(data_path, "cbq.xlsx")
fsozu_file <- file.path(data_path, "f_sozu.xlsx")
iq_file <- file.path(data_path, "iq.xlsx")
ace_file <- file.path(data_path, "ace.xlsx")

iq_file_2 <- read_excel("S:/KJP_Studien/LOCUS_MENTAL/6_Versuchsdaten/IQ_selbsteingabe.xlsx") # table with different iq tests than WPPSI-IV
ids <- read_excel("S:/KJP_Studien/LOCUS_MENTAL/6_Versuchsdaten/Studienids.xlsx")

# 070 - keine Teilnahme an Batterie, Testung nicht möglich

# LOAD Data

cbcl <- read_excel(cbcl_file)
ari <- read_excel(ari_file)
biq <- read_excel(biq_file)
cbq <- read_excel(cbq_file)
f_sozu <- read_excel(fsozu_file)
iq <-read_excel(iq_file)
ace <- read_excel(ace_file)

# Keep only relevant variables 
# Adjust 
cbcl <- cbcl %>%
  select(
    ID_Bado,
    Geschlecht_Index,
    Meßzeit_CBCL,
    CBCL_T_INT,
    CBCL_T_EXT,
    CBCL_T_GES
  ) %>%
  left_join(ids, by = "ID_Bado") %>%
  select(
    ID,
    Geschlecht_Index,
    Meßzeit_CBCL,
    CBCL_T_INT,
    CBCL_T_EXT,
    CBCL_T_GES
  ) %>% filter(!is.na(ID))

ari <- ari %>%
  select(ID_Bado, ARI_Eltern_Score_total)%>%
  left_join(ids, by = "ID_Bado") %>%
  select(ID, ARI_Eltern_Score_total)%>%
  filter(!is.na(ID))
  
  
biq <- biq %>%
  select(ID_Bado, BIQ_Z_Score,BIQ_Z_Score_Urteil)%>%
  left_join(ids, by = "ID_Bado") %>%
  select(ID, BIQ_Z_Score,BIQ_Z_Score_Urteil)%>%
  filter(!is.na(ID))

cbq <- cbq %>% 
  rename(ID_Bado=ID_BADO)

cbq <- cbq %>%
  select(ID_Bado, 
         CBQ_Offenheit_Summenwert,
         CBQ_Negativer_Affekt_Summenwert, 
         CBQ_Kontrollfaehigkeit_Summenwert, 
         CBQ_Ges_Summenwert)%>%
  left_join(ids, by = "ID_Bado") %>%
  select(ID,CBQ_Offenheit_Summenwert,
         CBQ_Negativer_Affekt_Summenwert, 
         CBQ_Kontrollfaehigkeit_Summenwert, 
         CBQ_Ges_Summenwert)%>%
  filter(!is.na(ID))


f_sozu <- f_sozu %>%
  select(ID_Bado, F_SozU_Score)%>%
  left_join(ids, by = "ID_Bado") %>%
  select(ID, F_SozU_Score)%>%
  filter(!is.na(ID))

ace <- ace %>% 
  select(ID_Bado, ACE_Score_total) %>%
  left_join(ids, by = "ID_Bado") %>%
  select(ID, ACE_Score_total)%>%
  filter(!is.na(ID))

iq <- iq %>% 
  select(ID_Bado, 
         IQ_Alter,
         IQ_verbal,
         IQ_nonverbal)%>%
  left_join(ids, by = "ID_Bado") %>%
  select(ID, 
         IQ_Alter,
         IQ_verbal,
         IQ_nonverbal)%>%
  filter(!is.na(ID))

# Transformation from wertpunkte auf IQ scale 
# function
wertp_to_iq <- function(wp) {
  ((wp - 10) / 3) * 15 + 100
}
# transformation
iq <- iq %>%
  mutate(
    IQ_verbal_z     = round(wertp_to_iq(IQ_verbal)),
    IQ_nonverbal_z  = round(wertp_to_iq(IQ_nonverbal))
)

library(lubridate)
iq_file_2 <- iq_file_2 %>%
  mutate(
    IQ_Alter = time_length(
      interval(Gdatum, `IQ-Datum`),
      unit = "years"
    )
  ) 

iq <- dplyr::bind_rows(
  iq,
  iq_file_2 %>%
    dplyr::select(
      ID,
      IQ_Alter,
      IQ_verbal,
      IQ_nonverbal,
      IQ_verbal_z,
      IQ_nonverbal_z
    )
)

# Check for duplicates in each dataframe
cbcl %>% count(ID) %>% filter(n > 1)
ari %>% count(ID) %>% filter(n > 1)
biq %>% count(ID) %>% filter(n > 1)
cbq %>% count(ID) %>% filter(n > 1)
f_sozu %>% count(ID) %>% filter(n > 1)
# => currently no duplicates in the questionnaires

iq %>% count(ID) %>% filter(n>1)
# ID         n
# <chr>  <int>
# 1 LM_066     2
# 2 LM_084     2
# 3 LM_085     4
# 4 LM_091     2
#=> code to adjust those below, aks Heiko to delete the duplicates

iq <- iq %>%
  dplyr::filter(
    ID != "LM_085" |
      (ID == "LM_085" & IQ_verbal == 8 & IQ_nonverbal == 8)
  )

iq <- iq %>%
  distinct(ID, .keep_all = TRUE)

# IF the duplicates are the same after inspection, keep only one distinct row
# cbcl <- cbcl %>%
#   distinct(ID, .keep_all = TRUE)
# 
# ari <- ari %>%
#   distinct(ID, .keep_all = TRUE)
# 
# biq <- biq %>%
#   distinct(ID, .keep_all = TRUE)
# 
# cbq <- cbq %>%
#   distinct(ID, .keep_all = TRUE)
# 
# f_sozu <- f_sozu %>%
#   distinct(ID, .keep_all = TRUE)

# merge
sample_merged <- cbcl %>%
  left_join(ari,    by = "ID") %>%
  left_join(biq,    by = "ID") %>%
  left_join(cbq,    by = "ID") %>%
  left_join(f_sozu, by = "ID") %>% 
  left_join(iq, by = "ID")

# inspect
sample_merged %>%
  count(ID) %>%
  filter(n > 1)


data <- sample_merged %>% 
  rename(sex=Geschlecht_Index,
         age = IQ_Alter)

save_path <- "S:/KJP_Studien/LOCUS_MENTAL/6_Versuchsdaten/"
save(data, file = paste0(save_path, "demo_data.rda"))



