#read demo_data.rda as created by demographic_questionnaires_code

#setup
require(ggplot2)
require(gridExtra)
set_theme(theme_bw())

#read data
readRDS("C:/Users/nico/Nextcloud/project_locusmental_wp1/code/demographic_questionnaires_code.R")
names(data)

#core demographics
table(data$sex)
psych::describe(data$age)
psych::describe(data$IQ_nonverbal_z)

ggplot(data,aes(age))+geom_histogram(bins=20,color='lightgrey')+
  labs(title='Alter in Jahren')
ggplot(data,aes(IQ_verbal_z))+geom_histogram(bins=20,color='lightgrey')+
  labs(title='verbaler IQ')
ggplot(data,aes(IQ_nonverbal_z))+geom_histogram(bins=20,color='lightgrey')+
  labs(title='nonverbaler IQ')



#psychopathology
n_int <- round(sum(data$CBCL_T_INT > 65, na.rm = TRUE)/sum(!is.na(data$CBCL_T_INT)),2)*100
n_ext <- round(sum(data$CBCL_T_EXT > 65, na.rm = TRUE)/sum(!is.na(data$CBCL_T_EXT)),2)*100
n_ges <- round(sum(data$CBCL_T_GES > 65, na.rm = TRUE)/sum(!is.na(data$CBCL_T_GES)),2)*100

g2<-ggplot(data,aes(CBCL_T_INT))+geom_histogram(bins=20,color='lightgrey')+xlim(c(30,80))+
  labs(title='Internalizing Psychopathology')+geom_vline(xintercept=65,color='red',linetype=2)+
  annotate("text", x = 70, y = Inf, label = paste("above:" , n_int, '%'),
           vjust = 2, hjust = 0, color = "red")
g3<-ggplot(data,aes(CBCL_T_EXT))+geom_histogram(bins=20,color='lightgrey')+xlim(c(30,80))+
  labs(title='Externalizing Psychopathology')+geom_vline(xintercept=65,color='red',linetype=2)+
  annotate("text", x = 70, y = Inf, label = paste("above:" , n_ext, '%'),
           vjust = 2, hjust = 0, color = "red")
g1<-ggplot(data,aes(CBCL_T_GES))+geom_histogram(bins=20,color='lightgrey')+xlim(c(30,80))+
  labs(title='Total Psychopathology')+geom_vline(xintercept=65,color='red',linetype=2)+
  annotate("text", x = 70, y = Inf, label = paste("above:" , n_ges, '%'),
           vjust = 2, hjust = 0, color = "red")

grid.arrange(g1,g2,g3,ncol=3)


table(data$CBCL_T_GES>65)
table(data$CBCL_T_EXT>65)
table(data$CBCL_T_INT>65)





hist(data$CBCL_T_GES,20)
hist(data$CBCL_T_EXT,20)
hist(data$CBCL_T_INT,20)
