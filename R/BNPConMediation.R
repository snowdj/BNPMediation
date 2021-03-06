#' Posterior Means and 95\% C.I.s of the conditional NIE, NDE and TE
#' 
#' Obtain posterior means and credible intervals of the effects.
#' @param obj1 The fitted model of the observed data under Z=1 from DPdensity
#' @param obj0 The fitted model of the observed data under Z=0 from Dpdensity
#' @param q A dimension of the observed data, i.e., number of covariates plus 2
#' @param NN Number of samples drawn for each iteration from the joint distribution of the mediator and the covariates. Default is 100.
#' @param n1 Number of observations under Z=1
#' @param n0 Number of observations under Z=0
#' @param extra.thin Giving the extra thinning interval
#' @param cond.values conditional values of the covariates
#' @param col.values columns orders of the conditional covariates among all covariates
#' @return ENIE Posterior mean of the NIE
#' @return ENDE Posterior mean of the NDE
#' @return ETE Posterior mean of the TE
#' @return IE.c.i 95\% C.I. of the NIE
#' @return DE.c.i 95\% C.I. of the NDE
#' @return TE.c.i 95\% C.I. of the TE
#' @return Y11 Posterior samples of Y11
#' @return Y00 Posterior samples of Y00
#' @return Y10 Posterior samples of Y10
#' @export


bnpconmediation<-function(obj1, obj0, q, NN=10, n1, n0, extra.thin=0, cond.values=c(45,35), col.values=c(1,2)){
  
  library(mnormt)
  library(condMVNorm)
  
  obj1.dim <- dim(obj1$save.state$randsave)[2]-(q*(q+1)/2+2*q-1)
  obj0.dim <- dim(obj0$save.state$randsave)[2]-(q*(q+1)/2+2*q-1)
  Len.MCMC <- 1:dim(obj0$save.state$randsave)[1]
  if(extra.thin!=0){
    Len.MCMC <- Len.MCMC[seq(extra.thin, length(Len.MCMC), extra.thin)]
  }
  
  
  mat.given.ij <- function(x, y) ifelse(x <= y, (q-1)*(x-1)+y-x*(x-1)/2, (q-1)*(y-1)+x-y*(y-1)/2)
  mat <- function(q) outer( 1:q, 1:q, mat.given.ij )
  
  pb <- txtProgressBar(min = 0, max = length(Len.MCMC), style = 3)
  
  Y10<-NULL
  Y11<-NULL
  Y00<-NULL

  joint0 <- matrix(nrow=n0*NN,ncol=q-1)
  joint1 <- matrix(nrow=n1*NN,ncol=q-1)
  
  index<-0
  for(j in Len.MCMC){
    index <- index + 1   
    mu2 <- sapply(seq(2,obj0.dim, by=(q*(q+1)/2+q)), function(x)  obj0$save.state$randsave[j,x:(x+q-2)])
    sigma22 <- sapply(seq(q+q+1,obj0.dim, by=(q*(q+1)/2+q)), function(x)  obj0$save.state$randsave[j,x:(x+(q-1)*(q)/2-1)][mat(q-1)])
    if(q>2){
        joint0.temp <- do.call("rbind", replicate(NN, data.frame(sapply(1:n0, function(x) rcmvnorm(1, mu2[,x], matrix(sigma22[,x],q-1,q-1,byrow=T), c(1:(q-1))[-(col.values+1)], (col.values+1), cond.values, check.sigma=TRUE,method=c("svd"))))))
    }else{
        stop("No covariates in the joint models")
    }
    joint0[,(col.values+1)] <- matrix(cond.values, nrow=n0*NN, ncol=2, byrow=T) 
    joint0[,-(col.values+1)] <- joint0.temp 
    

    mu2 <- sapply(seq(2,obj1.dim, by=(q*(q+1)/2+q)), function(x)  obj1$save.state$randsave[j,x:(x+q-2)])
    sigma22 <- sapply(seq(q+q+1,obj1.dim, by=(q*(q+1)/2+q)), function(x)  obj1$save.state$randsave[j,x:(x+(q-1)*(q)/2-1)][mat(q-1)])
    joint1.temp <- do.call("rbind", replicate(NN, data.frame(sapply(1:n1, function(x) rcmvnorm(1, mu2[,x], matrix(sigma22[,x],q-1,q-1,byrow=T), c(1:(q-1))[-(col.values+1)], (col.values+1), cond.values, check.sigma=TRUE,method=c("svd"))))))
    joint1[,(col.values+1)] <- matrix(cond.values, nrow=n1*NN, ncol=2, byrow=T) 
    joint1[,-(col.values+1)] <- joint1.temp 
    
    


    unique.val <- unique(obj1$save.state$randsave[j,seq(1,obj1.dim,by=(q*(q+1)/2+q))])
    unique.ind <- NULL
    unique.prop <- NULL
    for(k in 1:length(unique.val)){
      unique.ind[k] <- which(obj1$save.state$randsave[j,seq(1,obj1.dim,by=(q*(q+1)/2+q))]==unique.val[k])[1]
      unique.prop[k] <- length(which(obj1$save.state$randsave[j,seq(1,obj1.dim,by=(q*(q+1)/2+q))]==unique.val[k]))/n1
    }
    b01 <- NULL
    b00 <- NULL
    Weight.num0 <- matrix(nrow=length(unique.val), ncol=n0*NN)
    B0 <- matrix(nrow=length(unique.val),ncol=n0*NN)
    Weight.num1<-matrix(nrow=length(unique.val),ncol=n1*NN)
    B1<-matrix(nrow=length(unique.val),ncol=n1*NN)

    t.ind<-0
    for(k in unique.ind){
      t.ind<-1+t.ind
      mu1<-obj1$save.state$randsave[j,(q*(q+1)/2+q)*k-(q*(q+1)/2+q)+1]
      mu2<-obj1$save.state$randsave[j,((q*(q+1)/2+q)*k-(q*(q+1)/2+q)+2):((q*(q+1)/2+q)*k-(q*(q+1)/2+q)+q)]
      sigma1<-obj1$save.state$randsave[j,(q*(q+1)/2+q)*k-(q*(q+1)/2+q)+q+1]
      sigma12<-obj1$save.state$randsave[j,(q*(q+1)/2+q)*k-(q*(q+1)/2+q)+((q+2):(2*q))]
      sigma22<-matrix(obj1$save.state$randsave[j,((q*(q+1)/2+q)*k-(q*(q+1)/2+q)+2*q+1):((q*(q+1)/2+q)*k)][mat(q-1)],q-1,q-1,byrow=TRUE)
      Weight.num0[t.ind,1:(n0*NN)]<-unique.prop[t.ind]*dmnorm(joint0,mu2,sigma22)
      Weight.num1[t.ind,1:(n1*NN)]<-unique.prop[t.ind]*dmnorm(joint1,mu2,sigma22)

      b01[t.ind]<-mu1-sigma12%*%solve(sigma22)%*%t(t(mu2))
      B0[t.ind,1:(n0*NN)]<-sigma12%*%solve(sigma22)%*%t(joint0)
      B1[t.ind,1:(n1*NN)]<-sigma12%*%solve(sigma22)%*%t(joint1)
    }
    
    
    
    Weight=apply(Weight.num0, 2, function(x) x/sum(x))
    test <- Weight*(b01+B0)
    Y10[index]<-mean(apply(test, 2, sum))
    Weight=apply(Weight.num1, 2, function(x) x/sum(x))
    test<-Weight*(b01+B1)
    Y11[index]<-mean(apply(test, 2, sum))


    unique.val <- unique(obj0$save.state$randsave[j,seq(1,obj0.dim,by=(q*(q+1)/2+q))])
    unique.ind <- NULL
    unique.prop <- NULL
    for(k in 1:length(unique.val)){
        unique.ind[k] <- which(obj0$save.state$randsave[j,seq(1,obj0.dim,by=(q*(q+1)/2+q))]==unique.val[k])[1]
        unique.prop[k] <- length(which(obj0$save.state$randsave[j,seq(1,obj0.dim,by=(q*(q+1)/2+q))]==unique.val[k]))/n0
    }
    Weight.num0 <- matrix(nrow=length(unique.val), ncol=n0*NN)
    B0 <- matrix(nrow=length(unique.val),ncol=n0*NN)
    
    t.ind<-0
    for(k in unique.ind){
        t.ind<-1+t.ind
        mu1<-obj0$save.state$randsave[j,(q*(q+1)/2+q)*k-(q*(q+1)/2+q)+1]
        mu2<-obj0$save.state$randsave[j,((q*(q+1)/2+q)*k-(q*(q+1)/2+q)+2):((q*(q+1)/2+q)*k-(q*(q+1)/2+q)+q)]
        sigma1<-obj0$save.state$randsave[j,(q*(q+1)/2+q)*k-(q*(q+1)/2+q)+q+1]
        sigma12<-obj0$save.state$randsave[j,(q*(q+1)/2+q)*k-(q*(q+1)/2+q)+((q+2):(2*q))]
        sigma22<-matrix(obj0$save.state$randsave[j,((q*(q+1)/2+q)*k-(q*(q+1)/2+q)+2*q+1):((q*(q+1)/2+q)*k)][mat(q-1)],q-1,q-1,byrow=TRUE)
        Weight.num0[t.ind,1:(n0*NN)]<-unique.prop[t.ind]*dmnorm(joint0,mu2,sigma22)
        
        b00[t.ind]<-mu1-sigma12%*%solve(sigma22)%*%t(t(mu2))
        B0[t.ind,1:(n0*NN)]<-sigma12%*%solve(sigma22)%*%t(joint0)
    }

    Weight=apply(Weight.num0, 2, function(x) x/sum(x))
    test<-Weight*(b00+B0)
    Y00[index]<-mean(apply(test, 2, sum))



    Sys.sleep(0.05)
    setTxtProgressBar(pb, index)
  }
  
  z <- list(Y11=Y11, 
            Y00=Y00, 
            Y10=Y10, 
            ENIE=mean(Y11-Y10), 
            ENDE=mean(Y10-Y00), 
            ETE=mean(Y11-Y00), 
            TE.c.i=c(sort(Y11-Y00)[length(Len.MCMC)*0.025],sort(Y11-Y00)[length(Len.MCMC)*0.975]),
            IE.c.i=c(sort(Y11-Y10)[length(Len.MCMC)*0.025],sort(Y11-Y10)[length(Len.MCMC)*0.975]),
            DE.c.i=c(sort(Y10-Y00)[length(Len.MCMC)*0.025],sort(Y10-Y00)[length(Len.MCMC)*0.975]))  
  z$call <- match.call()
  class(z) <- "bnpconmediation"
  return(z)
}


