#' Subset detection by clustering
#' 
#' Apply clustering algorithms to detect cell subsets. \code{DensVM} and \code{ClusterX} 
#' clustering is based on the transformed ydata and uses xdata to train the model. 
#' \code{Rphenograph} directly works on high dimensional xdata. \code{FlowSOM} is 
#' integrated from FlowSOM pacakge (https://bioconductor.org/packages/release/bioc/html/FlowSOM.html).
#' 
#' @param ydata A matrix of the dimension reduced data.
#' @param xdata A matrix of the expression data.
#' @param method Cluster method including \code{DensVM}, \code{densityClustX}, \code{Rphenograph} and \code{FlowSOM}.
#' @param Rphenograph_k Integer number of nearest neighbours to pass to Rphenograph.
#' @param FlowSOM_k Number of clusters for meta clustering in FlowSOM.
#' @param flowSeed Integer to set a seed for FlowSOM for reproducible results.
#' 
#' @return a vector of the clusters assigned for each row of the ydata
#' @export
#' @examples
#' d<-system.file('extdata', package='cytofkit2')
#' fcsFile <- list.files(d, pattern='.fcs$', full=TRUE)
#' parameters <- list.files(d, pattern='.txt$', full=TRUE)
#' markers <- as.character(read.table(parameters, header = FALSE)[, 1])
#' xdata <- cytof_exprsMerge(fcsFile, mergeMethod = 'fixed', fixedNum = 100)
#' ydata <- cytof_dimReduction(xdata, markers = markers, method = "tsne")
#' clusters <- cytof_cluster(ydata, xdata, method = "ClusterX")
cytof_cluster <- function(ydata = NULL, 
                          xdata = NULL, 
                          method = c("Rphenograph", "ClusterX", "DensVM", "FlowSOM", "NULL"),
                          Rphenograph_k = 30,
                          FlowSOM_k = 40,
                          flowSeed = NULL){
    
    method = match.arg(method)
    if(method == "NULL"){
        return(NULL)
    }
    switch(method, 
           Rphenograph = {
               message("  Running PhenoGraph...")
               clusters <- as.numeric(membership(Rphenograph(xdata, k=Rphenograph_k)))
           },
           ClusterX = {
               message("  Running ClusterX...")
               clusters <- ClusterX(ydata, gaussian=TRUE, alpha = 0.001, detectHalos = FALSE)$cluster
           },
           DensVM = {
               message("  Running DensVM...")
               clusters <- DensVM(ydata, xdata)$cluster$cluster
           },
           FlowSOM = {
               message("  Running FlowSOM...")
               #set.seed(flowSeed)
               clusters <- FlowSOM_integrate2cytofkit(xdata, FlowSOM_k, flowSeed = flowSeed)
           })
    
    if( length(clusters) != ifelse(is.null(ydata), nrow(xdata), nrow(ydata)) ){
        message("Cluster is not complete, cluster failed, try other cluster method(s)!")
        return(NULL)
    }else{
        if(!is.null(xdata) && !is.null(row.names(xdata))){
            names(clusters) <- row.names(xdata)
        }else if(!is.null(ydata) && !is.null(row.names(ydata))){
            names(clusters) <- row.names(ydata)
        }
        message(" DONE!\n")
        return(clusters)
    }
}


#' FlowSOM algorithm
#' 
#' @param xdata Input data matrix.
#' @param k Number of clusters.
#' @param flowSeed Seed for reproducibility to pass to metaClustering_consensus.
#' @param ... Other parameters passed to SOM.
#' 
#' @noRd
#' @importFrom FlowSOM SOM metaClustering_consensus
FlowSOM_integrate2cytofkit <- function(xdata, k, flowSeed = NULL, ...){
    message("    Building SOM...\n")
    xdata <- as.matrix(xdata)
    
    ord <- tryCatch({
        map <- SOM(xdata, silent = TRUE, ...)
        message("    Meta clustering to", k, "clusters...\n")
        metaClusters <- suppressMessages(metaClustering_consensus(map$codes, k = k, seed = flowSeed))
        cluster <- metaClusters[map$mapping[,1]]
    }, error=function(cond) {
        message("Run FlowSOM failed \n")
        message("Here's the error message:\n")
        message(cond)
        return(NULL)
    }) 
    
    if(is.null(ord)){
        cluster <- NULL
    }else{
        if(length(ord) != nrow(xdata)){
            message("Run FlowSOM failed!")
            return(NULL)
        }
        cluster <- ord
    }
    
    return(cluster)
}
