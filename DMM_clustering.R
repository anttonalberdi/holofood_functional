library(microbiome)
library(DirichletMultinomial)
library(reshape2)
library(magrittr)
library(dplyr)

MAG_counts=read.csv("data/counts/bwa_counts-total.csv")

metadata=read.csv("data/counts/metadata.csv")

id_map=read.csv("data/counts/chicken_id_mapping.csv")
id_map$holofood_id=substring(id_map$holofood_id,1,7)
colnames(MAG_counts)%in%id_map$ena_id
metadata=metadata[metadata$Animal.code%in%id_map$holofood_id,]
dim(metadata)
dim(MAG_counts)
