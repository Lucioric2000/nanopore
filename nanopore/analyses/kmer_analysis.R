#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = T)

data <- read.table(args[1], row.names=1, header=T)


if (sum(data$refCount) > 1000 && sum(data$readCount) > 10000 ){
    outf <- args[2]
    outsig <- args[3]
    outplot <- args[4]
    library(stats)
    library(lattice)


    num_trials <- 1000
    trial_size <- 5000

    #builds a table of samples from a kmer count distribution
    #samples the probability distribution d t times
    trial_fn <- function(d, t) {
        matrix(table(factor(sample(1024, t, prob=d, replace=T), levels=1:1024)))[,1]
    }
    #do num_trials trials of sampling from the refFraction distribution
    ref <- replicate(num_trials, trial_fn(d=data$refFraction, t=trial_size))
    #do num_trials trials of sampling from the readFraction distribution
    read <- replicate(num_trials, trial_fn(d=data$readFraction, t=trial_size))
    #initialize a p_value vector
    p_values <- rep(0, 1024)
    #loop over each kmer and do a Kolmogorov-Smirnov test comparing the two distributions
    for (i in 1:1024) {
        p_values[i] <- ks.test(ref[i,], read[i,])$p.value
    }
    #Bonferroni correction for multiple hypotheses
    adjusted_p_value <- p.adjust(p_values, method="bonferroni")
    #combine original data frame with two new vectors
    finished <- cbind(data, p_values, adjusted_p_value)
    #write full dataset
    write.table(finished, outf)
    #find significant hits
    significant <- finished[finished$adjusted_p_value <= 0.05,]
    #plot volcano plot
    pdf(outplot)
    xyplot(finished$adjusted_p_value~finished$logFoldChange, xlab="Log Fold Change", ylab="Adjusted P Value", main=paste(args[5], "Volcano Plot", sep=" "))
    dev.off()
    #sort the significant hits by fold change
    ordered <- significant[order(significant$logFoldChange),]
    #report the top 20 and bottom 20 significant hits
    top <- head(ordered, n=20L)
    bot <- apply(tail(ordered, n=20L), 2, rev)

    write.table(rbind(top,bot), outsig)
}