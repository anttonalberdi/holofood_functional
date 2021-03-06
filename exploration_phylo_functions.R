library(data.table)
library(vegan)
library(dplyr)
library(tidyr)
library(stringr)
library(ggcorrplot)
library(factoextra)
library(ape)
library(logisticPCA)
library(vegan)
library(psych)

taxonomy <- read.delim("data/dram/genome_stats.tsv", sep = '\t')
taxonomyclean <- taxonomy %>% 
  mutate(taxonomy = str_replace_all(taxonomy, ".__", "")) %>%
  # Split the classification string into columns for each taxonnomic rank
  separate(col = taxonomy, sep = ";", into = c("Domain", "Phylum", "Class", "Order", "Family", "Genus", "Species"))
# Remove first column
taxonomyclean1 <- taxonomyclean[,-1]
# Set MAG name as row names of the dataframe
rownames(taxonomyclean1) <- taxonomyclean[,1]

# Get the necessary columns, convert to matrix
taxmatrix <- as.data.frame(taxonomyclean1[2:8])
taxmatrix=taxmatrix[!rownames(taxmatrix)=="fasta",]
# Pool Firmicutes A,B C into Firmicutes
taxmatrix$Phylum[grepl("Firmi",taxmatrix$Phylum)]="Firmicutes"

# Load phylogenetic tree
Phylo_bac=read.nexus("data/trees/gtdbtk.bac120.classify.nex")
Phylo_bac$tip.label=gsub("'","",Phylo_bac$tip.label)
Phylo_ar=read.nexus("data/trees/gtdbtk.ar122.classify.nex")
phylo.tree=drop.tip(Phylo_bac,Phylo_bac$tip.label[!Phylo_bac$tip.label%in%rownames(taxmatrix)])

length(phylo.tree$tip.label)


# Load DRAM data
DRAM_data=read.delim("data/dram/product.tsv",sep='\t')
dim(DRAM_data)

# Discard the "fasta" genome
DRAM_data=DRAM_data[DRAM_data$genome!="fasta",]
rownames(DRAM_data)=DRAM_data$genome
DRAM=DRAM_data[,-1]
# Convert True/False character to 1/0 binary, numeric data
for(i in 1:ncol(DRAM)){
  if(is.character(DRAM[,i])){
    DRAM[,i][DRAM[,i]=="True"]=1
    DRAM[,i][DRAM[,i]=="False"]=0
    DRAM[,i]=as.numeric(DRAM[,i])
  }
}
str(DRAM)

# List of completely absent functions
colnames(DRAM[,colSums(DRAM)==0])
# [1] "X3.Hydroxypropionate.bi.cycle"                                                  
# [2] "Complex.I..NAD.P.H.quinone.oxidoreductase..chloroplasts.and.cyanobacteria"      
# [3] "Complex.I..NADH.dehydrogenase..ubiquinone..1.alpha.subcomplex"                  
# [4] "Complex.II..Succinate.dehydrogenase..ubiquinone."                               
# [5] "Complex.IV.Low.affinity..Cytochrome.aa3.600.menaquinol.oxidase"                 
# [6] "Complex.V..V.type.ATPase..eukaryotes"                                           
# [7] "Methanogenesis.and.methanotrophy..methane....methanol..with.oxygen..mmo."       
# [8] "Methanogenesis.and.methanotrophy..methane....methanol..with.oxygen..pmo."       
# [9] "Nitrogen.metabolism..Bacterial..aerobic.specific..ammonia.oxidation"            
# [10] "Nitrogen.metabolism..Bacterial..anaerobic.specific..ammonia.oxidation"          
# [11] "Nitrogen.metabolism..Bacterial.Archaeal.ammonia.oxidation"                      
# [12] "Nitrogen.metabolism..Nitrogen.fixation.altennative"                             
# [13] "Nitrogen.metabolism..ammonia....nitrite"                                        
# [14] "Nitrogen.metabolism..nitric.oxide....nitrous.oxide"                             
# [15] "Other.Reductases..arsenate.reduction..pt.2"                                     
# [16] "Other.Reductases..mercury.reduction"                                            
# [17] "Other.Reductases..selenate.Chlorate.reduction"                                  
# [18] "Photosynthesis..Photosystem.I"                                                  
# [19] "Photosynthesis..Photosystem.II"                                                 
# [20] "Sulfur.metabolism..Thiosulfate.oxidation.by.SOX.complex..thiosulfate....sulfate"

# Discard completely absent functions from further exploration
dram=DRAM[,colSums(DRAM)>0]

# MAGs in taxonomy table and dram table in same order.
dram=dram[order(rownames(taxmatrix)),]
mean(rownames(dram)==rownames(taxmatrix))

# Load bin quality data
bin_q=read.csv("data/counts/caecumStats.txt")
bin_q$genome=gsub(".fa","",bin_q$genome)
bin_q=bin_q[bin_q$genome%in%rownames(dram),]
bin_q=bin_q[match(rownames(dram),bin_q$genome),]

# Set Archaea Phylum to Archaea for visualizations
taxmatrix[taxmatrix$Domain!="Bacteria",]$Phylum="Archaea"


# Barchart of bin qualities per Phylum
data.frame(MAG=factor(rownames(dram),levels = rownames(dram)[order(taxmatrix$Phylum)]),
           Phylum=taxmatrix$Phylum,
           completeness=bin_q$completeness)%>%
  ggplot(aes(y=completeness,x=MAG,fill=Phylum,color=Phylum)) +
  geom_bar(stat = "identity")+
  scale_fill_manual(values=c('#a6cee3','#33a02c','#b2df8a','black','#fb9a99','#e31a1c','#fdbf6f','#ff7f00','#cab2d6','#6a3d9a','#ffff99','#b15928'))+
  scale_color_manual(values=c('#a6cee3','#33a02c','#b2df8a','black','#fb9a99','#e31a1c','#fdbf6f','#ff7f00','#cab2d6','#6a3d9a','#ffff99','#b15928'))+
  theme_bw()
ggsave("panels/completeness_phylum.png",width = 8,height = 6)

# group DRAM functions
module=names(dram)[1:12]
etc=names(dram)[13:26]
cazy=names(dram)[27:45]
metab=names(dram)[c(46:62,76:78)]
scfa=names(dram)[63:75]

### Exploration of module variables ###

# Histograms of variables
data.frame(dram[module])%>%
  pivot_longer(cols = everything()) %>% 
  ggplot(aes(value)) +
  geom_histogram() +
  coord_cartesian(xlim=c(0,1))+
  facet_wrap(~name, scale = "free") +
  theme_bw()
ggsave("panels/module_distributions.png",width = 12,height = 8)

# Barchart MAGs sorted by Phyla 
data.frame(dram[module],MAG=factor(rownames(dram),levels = rownames(dram)[order(taxmatrix$Phylum)]),Phylum=taxmatrix$Phylum)%>%
  pivot_longer(cols = 1:ncol(dram[module])) %>% 
  ggplot(aes(y=value,x=reorder(MAG,Phylum),fill=Phylum)) +
  geom_bar(stat = "identity")+
  facet_wrap(~name, scale = "free") +
  coord_cartesian(ylim = c(0,1))+
  scale_fill_manual(values=c('#a6cee3','#33a02c','#b2df8a','black','#fb9a99','#e31a1c','#fdbf6f','#ff7f00','#cab2d6','#6a3d9a','#ffff99','#b15928'))+
  theme_bw()
ggsave("panels/modules_phyla.png",width = 14,height = 8)

# Module coverage vs MAG completeness (by Phylum) 
data.frame(dram[module],
           MAG=factor(rownames(dram),levels = rownames(dram)[order(taxmatrix$Phylum)]),
           Phylum=taxmatrix$Phylum,
           completeness=bin_q$completeness)%>%
  pivot_longer(cols = 1:ncol(dram[module])) %>% 
  ggplot(aes(y=value,x=completeness,fill=Phylum,color=Phylum)) +
  geom_smooth(method = "lm",se=FALSE)+
  facet_wrap(~name, scale = "free") +
  scale_fill_manual(values=c('#a6cee3','#33a02c','#b2df8a','black','#fb9a99','#e31a1c','#fdbf6f','#ff7f00','#cab2d6','#6a3d9a','#ffff99','#b15928'))+
  theme_bw()
ggsave("panels/module_vs_completeness.png",width = 14,height = 8)

# Correlations between variables
p_mat=cor_pmat(dram[module],  method = "spearman", use = "complete.obs")
cor_mat=cor(dram[module],method = "spearman")
ggcorrplot(cor_mat,
           outline.color = "black",
           show.diag  = F,
           hc.order = TRUE,
           type = "upper",
           lab = T,
           p.mat = p_mat,
           digits = 1,
           insig = "blank",
           ggtheme = theme_bw())
ggsave("panels/module_correlations.png",width = 12,height = 12)

# PCA
module_pca=prcomp(dram[module],scale = TRUE)
# variance explained by dimensions
fviz_screeplot(module_pca)
fviz_pca_biplot(module_pca, 
                repel = TRUE,
                label = "var",
                # geom.ind = shapes_ind, 
                pointshape = 21,
                pointsize = 3,
                col.ind = "black",
                fill.ind = taxmatrix$Phylum,  # Individuals color
                palette=c('#a6cee3','#33a02c','#b2df8a','black','#fb9a99','#e31a1c','#fdbf6f','#ff7f00','#cab2d6','#6a3d9a','#ffff99','#b15928'),
                # col.var = "blue", # Variables color
                mean.point = FALSE,
                ggtheme = theme_bw()
)
ggsave("panels/modules_pca.png",width = 8,height = 6)

### Exploration of etc variables ###

# Histograms of variables
data.frame(dram[etc])%>%
  pivot_longer(cols = everything()) %>% 
  ggplot(aes(value)) +
  geom_histogram() +
  coord_cartesian(xlim=c(0,1))+
  facet_wrap(~name, scale = "free") +
  theme_bw()
ggsave("panels/etc_distributions.png",width = 12,height = 8)

# Barchart MAGs sorted by Phyla 
data.frame(dram[etc],MAG=factor(rownames(dram),levels = rownames(dram)[order(taxmatrix$Phylum)]),Phylum=taxmatrix$Phylum)%>%
  pivot_longer(cols = 1:ncol(dram[etc])) %>% 
  ggplot(aes(y=value,x=reorder(MAG,Phylum),fill=Phylum)) +
  geom_bar(stat = "identity")+
  facet_wrap(~name, scale = "free") +
  coord_cartesian(ylim = c(0,1))+
  scale_fill_manual(values=c('#a6cee3','#33a02c','#b2df8a','black','#fb9a99','#e31a1c','#fdbf6f','#ff7f00','#cab2d6','#6a3d9a','#ffff99','#b15928'))+
  theme_bw()
ggsave("panels/etc_phyla.png",width = 14,height = 8)

# etc coverage vs MAG completeness (by Phylum) 
data.frame(dram[etc],
           MAG=factor(rownames(dram),levels = rownames(dram)[order(taxmatrix$Phylum)]),
           Phylum=taxmatrix$Phylum,
           completeness=bin_q$completeness)%>%
  pivot_longer(cols = 1:ncol(dram[etc])) %>% 
  ggplot(aes(y=value,x=completeness,fill=Phylum,color=Phylum)) +
  geom_smooth(method = "lm",se=FALSE)+
  facet_wrap(~name, scale = "free") +
  scale_fill_manual(values=c('#a6cee3','#33a02c','#b2df8a','black','#fb9a99','#e31a1c','#fdbf6f','#ff7f00','#cab2d6','#6a3d9a','#ffff99','#b15928'))+
  theme_bw()
ggsave("panels/etc_vs_completeness.png",width = 14,height = 8)

# Correlations between variables
p_mat=cor_pmat(dram[etc],  method = "spearman", use = "complete.obs")
cor_mat=cor(dram[etc],method = "spearman")
ggcorrplot(cor_mat,
           outline.color = "black",
           show.diag  = F,
           hc.order = TRUE,
           type = "upper",
           lab = T,
           p.mat = p_mat,
           digits = 1,
           insig = "blank",
           ggtheme = theme_bw())
ggsave("panels/etc_correlations.png",width = 12,height = 12)

# PCA
module_pca=prcomp(dram[etc],scale = TRUE)
# variance explained by dimensions
fviz_screeplot(module_pca)
fviz_pca_biplot(module_pca, 
                repel = TRUE,
                label = "var",
                # geom.ind = shapes_ind, 
                pointshape = 21,
                pointsize = 3,
                col.ind = "black",
                fill.ind = taxmatrix$Phylum,  # Individuals color
                palette=c('#a6cee3','#33a02c','#b2df8a','black','#fb9a99','#e31a1c','#fdbf6f','#ff7f00','#cab2d6','#6a3d9a','#ffff99','#b15928'),
                # col.var = "blue", # Variables color
                mean.point = FALSE,
                ggtheme = theme_bw()
)
ggsave("panels/etc_pca.png",width = 8,height = 6)

### Exploration of cazy variables ###

# Frequency plots
dram[cazy] %>% 
  pivot_longer(cols = everything()) %>% 
  group_by(name, value) %>% 
  summarize(count = n()) %>% 
  ggplot(aes(x = value, y = count)) +
  geom_bar(stat = "identity") +
  facet_wrap(~name, scale = "free_x") +
  theme_bw()
ggsave("panels/cazy_distributions.png",width = 12,height = 8)

# Barchart of number of cazy-s in MAGs, sorted by Phyla 
data.frame(dram[cazy],MAG=factor(rownames(dram),levels = rownames(dram)[order(taxmatrix$Phylum)]),Phylum=taxmatrix$Phylum)%>%
  pivot_longer(cols = 1:ncol(dram[cazy])) %>% 
  ggplot(aes(y=value,x=reorder(MAG,Phylum),fill=Phylum)) +
  geom_bar(stat = "identity")+
  facet_wrap(~Phylum,scales = "free_x") +
  scale_fill_manual(values=c('#a6cee3','#33a02c','#b2df8a','black','#fb9a99','#e31a1c','#fdbf6f','#ff7f00','#cab2d6','#6a3d9a','#ffff99','#b15928'))+
  theme_bw()
ggsave("panels/cazy_sum_phyla.png",width = 14,height = 8)

# Number of CAZYs vs MAG completeness (by Phylum) 
data.frame(dram[cazy],
           MAG=factor(rownames(dram),levels = rownames(dram)[order(taxmatrix$Phylum)]),
           Phylum=taxmatrix$Phylum,
           completeness=bin_q$completeness)%>%
  pivot_longer(cols = 1:ncol(dram[cazy])) %>% 
  ggplot(aes(y=value,x=completeness,fill=Phylum,color=Phylum)) +
  geom_smooth(method = "lm",se=FALSE)+
  facet_wrap(~name, scale = "free") +
  scale_fill_manual(values=c('#a6cee3','#33a02c','#b2df8a','black','#fb9a99','#e31a1c','#fdbf6f','#ff7f00','#cab2d6','#6a3d9a','#ffff99','#b15928'))+
  theme_bw()
ggsave("panels/cazy_vs_completeness.png",width = 14,height = 8)

# Correlations between CAZYs (binary data)
# Pearson correlation and tetrachoric correlation, an alternative that might be
# more meaningful for binary data.
cor_mat=cor(dram[cazy],method = "pearson")
cor_tetra=tetrachoric(dram[cazy])$rho
ggcorrplot(cor_mat,
           outline.color = "black",
           show.diag  = F,
           hc.order = TRUE,
           type = "upper",
           lab = T,
           digits = 1,
           insig = "blank",
           ggtheme = theme_bw())
ggsave("panels/cazy_correlations.png",width = 12,height = 12)

ggcorrplot(cor_tetra,
           outline.color = "black",
           show.diag  = F,
           hc.order = TRUE,
           type = "upper",
           lab = T,
           digits = 1,
           insig = "blank",
           ggtheme = theme_bw())
ggsave("panels/cazy_tetrachoric_correlations.png",width = 12,height = 12)

# Logistic PCA for binary data
logpca_cv = cv.lpca(dram[cazy], ks = 2, ms = 1:10)
plot(logpca_cv)
logpca_model = logisticPCA(dram[cazy], k = 2, m = which.min(logpca_cv))
plot(logpca_model,"scores")+geom_point(aes(colour = taxmatrix$Phylum),size=4)+
  scale_color_manual(values=c('#a6cee3','#33a02c','#b2df8a','black','#fb9a99','#e31a1c','#fdbf6f','#ff7f00','#cab2d6','#6a3d9a','#ffff99','#b15928'))+
  theme_bw()
ggsave("panels/cazy_pca.png",width = 8,height = 6)

### Exploration of metab variables ###

# Frequency plots
dram[metab] %>% 
  pivot_longer(cols = everything()) %>% 
  group_by(name, value) %>% 
  summarize(count = n()) %>% 
  ggplot(aes(x = value, y = count)) +
  geom_bar(stat = "identity") +
  facet_wrap(~name, scale = "free_x") +
  theme_bw()
ggsave("panels/metab_distributions.png",width = 12,height = 8)

# Barchart of number of metab pathways in MAGs, sorted by Phyla
data.frame(dram[metab],MAG=factor(rownames(dram),levels = rownames(dram)[order(taxmatrix$Phylum)]),Phylum=taxmatrix$Phylum)%>%
  pivot_longer(cols = 1:ncol(dram[metab])) %>% 
  ggplot(aes(y=value,x=reorder(MAG,Phylum),fill=Phylum)) +
  geom_bar(stat = "identity")+
  facet_wrap(~Phylum, scale = "free_x") +
  scale_fill_manual(values=c('#a6cee3','#33a02c','#b2df8a','black','#fb9a99','#e31a1c','#fdbf6f','#ff7f00','#cab2d6','#6a3d9a','#ffff99','#b15928'))+
  theme_bw()
ggsave("panels/metab_phyla.png",width = 14,height = 8)

# Number of metab genes vs MAG completeness (by Phylum) 
data.frame(dram[metab],
           MAG=factor(rownames(dram),levels = rownames(dram)[order(taxmatrix$Phylum)]),
           Phylum=taxmatrix$Phylum,
           completeness=bin_q$completeness)%>%
  pivot_longer(cols = 1:ncol(dram[metab])) %>% 
  ggplot(aes(y=value,x=completeness,fill=Phylum,color=Phylum)) +
  geom_smooth(method = "lm",se=FALSE)+
  facet_wrap(~name, scale = "free") +
  scale_fill_manual(values=c('#a6cee3','#33a02c','#b2df8a','black','#fb9a99','#e31a1c','#fdbf6f','#ff7f00','#cab2d6','#6a3d9a','#ffff99','#b15928'))+
  theme_bw()
ggsave("panels/metab_vs_completeness.png",width = 14,height = 8)

# Correlations between metab (binary data)
# Pearson correlation and tetrachoric correlation, an alternative that might be
# more meaningful for binary data.
cor_mat=cor(dram[metab],method = "pearson")
cor_tetra=tetrachoric(dram[metab])$rho
ggcorrplot(cor_mat,
           outline.color = "black",
           show.diag  = F,
           hc.order = TRUE,
           type = "upper",
           lab = T,
           digits = 1,
           insig = "blank",
           ggtheme = theme_bw())
ggsave("panels/metab_correlations.png",width = 12,height = 12)

ggcorrplot(cor_tetra,
           outline.color = "black",
           show.diag  = F,
           hc.order = TRUE,
           type = "upper",
           lab = T,
           digits = 1,
           insig = "blank",
           ggtheme = theme_bw())
ggsave("panels/metab_tetrachoric_correlations.png",width = 12,height = 12)

# Logistic PCA for binary data
logpca_cv = cv.lpca(dram[metab], ks = 2, ms = 1:10)
plot(logpca_cv)
logpca_model = logisticPCA(dram[metab], k = 2, m = which.min(logpca_cv))
plot(logpca_model,"scores")+geom_point(aes(colour = taxmatrix$Phylum),size=4)+
  scale_color_manual(values=c('#a6cee3','#33a02c','#b2df8a','black','#fb9a99','#e31a1c','#fdbf6f','#ff7f00','#cab2d6','#6a3d9a','#ffff99','#b15928'))+
  theme_bw()
ggsave("panels/metab_pca.png",width = 8,height = 6)

### Exploration of scfa variables ###

# Frequency plots
dram[scfa] %>% 
  pivot_longer(cols = everything()) %>% 
  group_by(name, value) %>% 
  summarize(count = n()) %>% 
  ggplot(aes(x = value, y = count)) +
  geom_bar(stat = "identity") +
  facet_wrap(~name, scale = "free_x") +
  theme_bw()
ggsave("panels/scfa_distributions.png",width = 12,height = 8)

# Barchart of number of scfa-s in MAGs, sorted by Phyla 
data.frame(dram[scfa],MAG=factor(rownames(dram),levels = rownames(dram)[order(taxmatrix$Phylum)]),Phylum=taxmatrix$Phylum)%>%
  pivot_longer(cols = 1:ncol(dram[scfa])) %>% 
  ggplot(aes(y=value,x=reorder(MAG,Phylum),fill=Phylum)) +
  geom_bar(stat = "identity")+
  facet_wrap(~Phylum, scale = "free_x") +
  scale_fill_manual(values=c('#a6cee3','#33a02c','#b2df8a','black','#fb9a99','#e31a1c','#fdbf6f','#ff7f00','#cab2d6','#6a3d9a','#ffff99','#b15928'))+
  theme_bw()
ggsave("panels/scfa_phyla.png",width = 14,height = 8)

# Number of SCFAs vs MAG completeness (by Phylum) 
data.frame(dram[scfa],
           MAG=factor(rownames(dram),levels = rownames(dram)[order(taxmatrix$Phylum)]),
           Phylum=taxmatrix$Phylum,
           completeness=bin_q$completeness)%>%
  pivot_longer(cols = 1:ncol(dram[scfa])) %>% 
  ggplot(aes(y=value,x=completeness,fill=Phylum,color=Phylum)) +
  geom_smooth(method = "lm",se=FALSE)+
  facet_wrap(~name, scale = "free") +
  scale_fill_manual(values=c('#a6cee3','#33a02c','#b2df8a','black','#fb9a99','#e31a1c','#fdbf6f','#ff7f00','#cab2d6','#6a3d9a','#ffff99','#b15928'))+
  theme_bw()
ggsave("panels/scfa_vs_completeness.png",width = 14,height = 8)


# Correlations between SCFAs (binary data)
# Pearson correlation and tetrachoric correlation, an alternative that might be
# more meaningful for binary data.
cor_mat=cor(dram[scfa],method = "pearson")
cor_tetra=tetrachoric(dram[scfa])$rho
ggcorrplot(cor_mat,
           outline.color = "black",
           show.diag  = F,
           hc.order = TRUE,
           type = "upper",
           lab = T,
           digits = 1,
           insig = "blank",
           ggtheme = theme_bw())
ggsave("panels/scfa_correlations.png",width = 12,height = 12)
ggcorrplot(cor_tetra,
           outline.color = "black",
           show.diag  = F,
           hc.order = TRUE,
           type = "upper",
           lab = T,
           digits = 1,
           insig = "blank",
           ggtheme = theme_bw())
ggsave("panels/scfa_tetrachoric_correlations.png",width = 12,height = 12)

# Logistic PCA for binary data
logpca_cv = cv.lpca(dram[scfa], ks = 2, ms = 1:10)
plot(logpca_cv)
logpca_model = logisticPCA(dram[scfa], k = 2, m = which.min(logpca_cv))
plot(logpca_model,"scores")+geom_point(aes(colour = taxmatrix$Phylum),size=4)+
  scale_color_manual(values=c('#a6cee3','#33a02c','#b2df8a','black','#fb9a99','#e31a1c','#fdbf6f','#ff7f00','#cab2d6','#6a3d9a','#ffff99','#b15928'))+
  theme_bw()
ggsave("panels/metab_pca.png",width = 8,height = 6)
