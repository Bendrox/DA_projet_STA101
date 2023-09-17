library(Factoshiny)
library(FactoMineR)
library(dplyr)
library(tidyverse)
library(ellipse)
library(corrplot)
library(stats)
library(Hmisc)
library(BioStatR)
library(missMDA)
library(factoextra)
library(ggplot2)
library(ggcorrplot)
library(ape)
library(ggdendro)

# chargement dataframe
df <- as.data.frame(pure_df19)
is.na.data.frame(df)

#fixer les indivs 
rownames(df) <- df$Country
df$Country <- NULL 
head(df)

#Pearson corr pr variables quanti 
mat_pear <- cor(df[3:16])
corrplot(mat_pear, type = "upper", order = "hclust", tl.col = "black", tl.srt = 80)

## Sperman corr pr variables quanti 
mat_sper <- cor(df[3:16],method = "spearman")
corrplot(mat_sper, type = "upper", order = "hclust", tl.col = "black", tl.srt = 80)


## cor de deux variables quanti
cor.test(df$CO2.Emiss, df$Popul.polut.PM2.5, method="spearman")


#chi-deux 
chisq.test(df$Least.Dev, df$Continent)

tab <- table(df$Least.Dev, df$Continent)
barplot(tab, beside=TRUE, legend=TRUE) 
mosaicplot(tab, shade=TRUE) 

ggplot(df, aes(x = Least.Dev, fill = Continent)) + 
  geom_bar(position = "fill") + 
  scale_fill_discrete(name = "y")

####lien entre variables quanti et quali
#transfo des variables charact en factor 
df$Continent <- as.factor(df$Continent)
df$Least.Dev <- as.factor(df$Least.Dev)

quali <- which(sapply(df, is.factor))
quanti <- which(sapply(df, is.numeric))

# creation d'une matrice vide avec en ligne les variables quantitatives et en colonne les variables qualitatives
mateta2 <- matrix(NA,length(quali),length(quanti))
rownames(mateta2) <- names(quali)
colnames(mateta2) <- names(quanti)

# calcul des différents eta carré
for(ii in seq(nrow(mateta2))){
  for(jj in seq(ncol(mateta2))){
    mateta2[ii, jj]<-eta2(df[, colnames(mateta2)[jj]],
                          df[, rownames(mateta2)[ii]])
  }
}
# pot des résultats quali vs quanti
corrplot(mateta2, tl.col = "black", tl.srt = 40)
corrplot(mateta2, tl.col = "black", method = 'number')

## FAMD facto
#Factoshiny(df)

# code FAMD 
res.famd<-FAMD(df,sup.var=c(1,4),graph=FALSE) #co2 emiss illustrative + continent var illustrative 
plot.FAMD(res.famd,invisible=c('ind.sup'),title="Graphe des individus et des modalités")
plot.FAMD(res.famd,axes=c(1,2),choix='var',title="Graphe des variables") 
plot.FAMD(res.famd, choix='quanti',title="Cercle des corrélations")


###  Classification - Construction de la partition :
# construc FAMD
c <- FAMD(df, ncp = Inf,
                 graph = FALSE,
                 sup.var = c(1,4))  #variable illus!!!
## chop valeurs propres
round(res.famd$eig, 3)

## éboulis des valeurs propres 
barplot(res.famd$eig[,1], las = 2, cex.names = .5)

## éboulis des valeurs propres V2
fviz_eig(res.famd, choice= "variance", addlabels = TRUE)
fviz_eig(res.famd, choice= "eigenvalue", addlabels = TRUE)

## nbr pour cah / classif
ncp <- 3
D <- dist(res.famd$ind$coord[,1:ncp])#distance euclidienne entre observations
res.hclust  <-  hclust(D,method = "ward.D2")#CAH par méthode de Ward

## hauteurs de fusion en fonction des différentes étapes d’agrégation des classes
barplot(sort(res.hclust$height,decreasing = TRUE)[1:15],
        names.arg = 1:15,
        xlab = "index",
        ylab = "hauteur de fusion")

barplot(sort(res.hclust$height,decreasing = TRUE)[1:15],
        names.arg = 1:15,
        xlab = "index",
        ylab = "hauteur de fusion",
        col =rgb(0.2,0.4,0.6,0.85),
        border= "white",
        width=0.5)

##CAH
res.famd2<-FAMD(df,sup.var=c(1,4),graph=FALSE, ncp=3) #nouveau famd pour incl 3 axes
res.hcpc <- HCPC(res.famd2, nb.clust = 6)
plot(res.hcpc, choice = "3D.map")

#Factor map
fviz_cluster(res.hcpc,                #nbr de cluts intégré
             repel = TRUE,            # Avoid label overlapping
             show.clust.cent = TRUE, # Show cluster centers
             palette = "jco",         # Color palette see ?ggpubr::ggpar
             ggtheme = theme_minimal(),
             main = "Factor map"
)

# Dendrogram v1
fviz_dend(res.hcpc, show_labels = TRUE, repel= TRUE, ggtheme = theme_minimal())

# Dendrogram v2 +  kmeans
colors = c("red", "blue", "green", "black", "brown", "purple")
clus4 = cutree(res.hclust, k = nbclasse)
plot(as.phylo(res.hclust), type = "fan", tip.color = colors[clus4],
     label.offset = 1, cex = 0.7)


nbclasse <- 6
partition <-  cutree(res.hclust, k = nbclasse) #élagage de l'arbre

#Conso
centres.gravite <- by(res.famd$ind$coord[,1:ncp],
                      INDICES = partition,
                      FUN = colMeans) 

#donne un objet de type "matrix", nécessaire pour pouvoir utiliser ces centres comme des valeurs initiales pour la fonction kmeans
centres.gravite <- do.call(rbind, centres.gravite)

#kmeans
res.kmeans <- kmeans(res.famd$ind$coord[,1:ncp],
                     centers = centres.gravite)

part.finale <- as.factor(res.kmeans$cluster)

table(part.finale)
plot(part.finale)

## description des classes a partir des variables 
df_part <- cbind.data.frame(df, classe = part.finale)#on concatène le jeu de données avec la nouvelle variable classe
catdes(df_part, num = ncol(df_part))


#intégrer class en illustratif
res.famd <- FAMD(df_part,
                 ncp = Inf,
                 graph = FALSE,
                 sup.var =  c(ncol(df_part),1,4)) #variable illus!!
##plot le tt
p <- fviz_famd_ind(res.famd, habillage=df_part$classe,
                   addEllipses=TRUE, ellipse.level=0.95)


#SAVE 
write.infile(res.famd, file="resultats_afdm.csv")

#eboulis 
barplot(res.famd$eig[,1], las = 2, cex.names = .5)

round(res.famd$eig, 3)
# Nombre d’axes par validation croisée 
res.ncp <- estim_ncpFAMD(df_part[,-c(1,4,ncol(df_part))],
          # on retire les variables illustratves qui ne sont pas gérées par la fonction 
                         ncp.max = 10,
                         method.cv = "Kfold",
                         nbsim = 100 #augmenter ce nombre améliore la précision des résultats, mais aussi le temps de calcul
                         
)
## plot tt ca
plot(x = as.numeric(names(res.ncp$crit)),
     y = res.ncp$crit,
     xlab = "S",
     ylab = "Erreur",
     main = "Erreur de validation croisée\n en fonction du nombre d'axes",
     type = "b")

## Interprétation à l’aide des classes
fviz_mfa_ind(res.famd, 
             habillage = "classe", # couleurs selon les modalités de la variable classe 
             palette = c("#FF0000", "#FFBF00", "#80FF00", "#FF00BF", "#00FFFF", "#0040FF", "#8000FF"),# définition des couleurs
             repel = TRUE
) 

# tracer les barycentres des XX classes sur le plan factoriel, très utile pour l’interprétation des axes.
plot(res.famd,
     choix = "quali",
     invisible = c("quali","ind")
)

#Interprétation à l’aide des individus top 11-20-17
###### méthode 1
plot(res.famd, choix = "ind", invisible = "quali", select = "contrib 2")
res.famd$ind$contrib

fviz_contrib(res.famd, choice = "ind", axes = c(1,2), top= 10)
fviz_contrib(res.famd, choice = "ind", axes = c(1,2),  sort.val= "asc")

###### méthode 2
fviz_famd_ind(res.famd, col.ind="contrib", ) +
  scale_color_gradient2(low="white", mid="blue",
                        high="red", midpoint=4, space ="Lab")



###### méthode 3
fviz_famd_ind(res.famd, select.ind = list(contrib = 17))

fviz_famd_ind(res.famd, alpha.ind="contrib") +
  theme_minimal()


#Interprétation à l’aide des variables
##### métho 1
plot(res.famd,choix = "var", select = "contrib 30")

##### métho 2
# Couleur par valeurs cos2: qualité sur le plan des facteurs
fviz_famd_var(res.famd, "quanti.var", col.var = "cos2",
              gradient.cols = c("#00AFBB", "#E7B800", "#FC4E07"), 
              repel = TRUE)

# Graphique des variables
fviz_famd_var(res.famd, repel = TRUE, col.var="blue")

# Contribution à la première dimension
fviz_contrib(res.famd, "var", axes = 1)
# Contribution à la deuxième dimension
fviz_contrib(res.famd, "var", axes = 2)

#co2 des vars
fviz_cos2(res.famd, "quanti.var", axes= c(1,2))
res.famd$qua
#Pour les variables quantitatives uniquement 
plot(res.famd, choix = "quanti")

#Quant aux modalités des variables qualitatives 
plot(res.famd, choix = "quali")
fviz_cos2(res.famd, "quali.var", axes= c(1,2))

##########représenter qu’une partie des modalités privilégier FActoshiny

#Description automatique des axes
res.dimdesc <- dimdesc(res.famd)
lapply(res.dimdesc$Dim.1, round, 3)# pour arrondir à 3 décimales les résultas portant sur la première dimension

lapply(res.dimdesc$Dim.2, round, 3)# pour la seconde dimension 

lapply(res.dimdesc$Dim.3, round, 3)# pour la trois dimension 


plot(res.famd,choix = "ind", select = "cos2 0.5", autoLab = "yes", habillage = "classe")
#Factoshiny(df_part)
