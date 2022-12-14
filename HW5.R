library(ggplot2)
library(tidyverse)
library(tidymodels)
library(corrplot)
library(ggthemes)
library(ISLR)
library(ISLR2) 
library(discrim)
library(poissonreg)
library(corrr)
library(klaR) 
tidymodels_prefer()
library(glmnet)
library(janitor)
library(dplyr)

mydb<-dbConnect(RSQLite::SQLite(),"my-db.sqlite") 
pokemon<-read.csv("/Users/yukinli/Downloads/Pokemon.csv") 
view(pokemon..1)
#1
pokemon_1<-clean_names(pokemon)
view(pokemon_1)
# all upper case letters become lower case, and fill in _ with space.I think clean_name is useful because it will fill in _, so there will not have gaps.

#2
pokemon_1 %>%
  ggplot(aes(x=type_1)) +
  geom_bar()
# 18 classes and flying has very few Pokemon.
filter(pokemon_1)
pokemon_2<-filter(pokemon_1,type_1=='Bug'| type_1=='Fire'| type_1=='Grass' |type_1=='Normal'|type_1=='Water'|type_1=='Psychic')
view(pokemon_2)
pokemon_2<-mutate_at(pokemon_2,vars(type_1,legendary), as.factor)
view(pokemon_2)
#3
set.seed(3435)

pokemon_split <- initial_split(pokemon_2, prop = 0.80,
                                strata = type_1)
pokemon_train <- training(pokemon_split)
pokemon_test <- testing(pokemon_split)
pokemon_fold <- vfold_cv(pokemon_train, v = 5, strata = type_1)

#4
pokemon_recipe <- recipe(type_1 ~ legendary+ generation+ sp_atk+ attack+speed+ defense+hp+ + sp_def ,data= pokemon_train) %>% 
  step_novel(all_nominal_predictors()) %>% 
  step_dummy(all_nominal_predictors()) %>% 
  step_zv(all_predictors()) %>% 
  step_normalize(all_predictors())

 

#5
lasso_spec <- multinom_reg(mixture = 1, penalty = tune() ) %>%
set_engine("glmnet")
lasso_wf <- workflow() %>%
  add_model(lasso_spec) %>%
  add_recipe(pokemon_recipe)
lasso_fit<-fit(lasso_wf, data = pokemon_2 )
lasso_fit
penalty_grid <- grid_regular(penalty(range = c(-5, 5)), levels = 10)
# I will be fitting 8 models.
#6
tune_res <- tune_grid(
  lasso_wf,
  resamples = pokemon_fold, 
  grid = penalty_grid
)
tune_res

autoplot(tune_res)
# I think larger values of penalty and mixture produce better accuracy and ROC AUC.

#7
collect_metrics(tune_res)
best_penalty <- select_best(tune_res, metric = "roc_auc")
best_penalty
lasso_final <- finalize_workflow(lasso_wf, best_penalty)
lasso_final_fit <- fit(lasso_final, data = pokemon_train)
  augment(lasso_final_fit, new_data = pokemon_test) %>%
  rsq(truth = type_1, estimate = .pred)

#8
augment(lasso_final_fit, new_data=pokemon_test) %>%
  roc_auc(type_1,.pred_Bug:.pred_Water)
# This is what I got.
## A tibble: 1 ?? 3
##.metric .estimator .estimate
##<chr>   <chr>          <dbl>
## 1 roc_auc hand_till      0.742


