rm(list=ls())
setwd("~/Documents/GitHub/gjamed")
########## Simulating the data
library(MASS)
library(repmis)
library(gjam)
library(rlist)
library(truncnorm)
#library(coda)
library(RcppArmadillo)
library(arm)
library(NLRoot)
library(Rcpp)
library(plyr)
library(ggplot2)
#library(ggsn)
library(parallel)
Rcpp::sourceCpp('src/cppFns.cpp')
source("R/gjamHfunctions_mod.R")
source("R/simple_gjam_0.R")
source("R/simple_gjam_1.R")
source("R/simple_gjam_2.R")
source("R/simple_gjam_3.R")
source("R/simple_gjam_4.R")


generate_data<-function(Sp=50,nsamples=500,qval=20,Ktrue=4){
  S<-Sp
  n<- nsamples
  q<- qval
  env<-runif(-50,50,n=n)
  X<-cbind(1,poly(env,2)) #nxK
  idx<-sample(S)
  B_0<-seq(0,100,length.out=S)[idx]
  B_1<-seq(0,100,length.out=S)[idx]
  B_2<-seq(0,100,length.out=S)[idx]
  B<-cbind(B_0,B_1,B_2) #SxK
  L<-X%*%t(B) #nxS
  K_t<- Ktrue
  cat("True number of clusters : ",K_t,"\n")
  A<-matrix(NA,nrow=ceiling(K_t),ncol=q)
  for(i in 1:ceiling(K_t)){
    A[i,]<-mvrnorm(n = 1,rep(0,q), Sigma=3*diag(q)) #Nxq short and skinny
  }
  idx<-sample((1:ceiling(K_t)),S,replace=T) 
  Lambda<-A[idx,] #Sxr tall and skinny
  Sigma<-Lambda%*%t(Lambda)+0.1*diag(S) #SxS
  Sigma_true<-Sigma
  Y<-mvrnorm(n = n, mu=rep(0,S), Sigma=Sigma)
  xdata<-as.data.frame(X[,-1])
  colnames(xdata)<-c("env1","env2")
  
  return(list(xdata=xdata, Y=Y,idx=idx,S_true=Sigma_true))
}




simulation_fun_oneDS<-function(data_set,Sp, Ntr, rval,nsamples=500, Ktrue,q=20, it=1000, burn=500,type="GJAM"){
  S<-Sp
  n<- nsamples
  r <- rval
  iterations<-it
  #env<-runif(-50,50,n=n)
  #X<-cbind(1,poly(env,2)) #nxK
  #idx<-sample(S)
  #B_0<-seq(0,100,length.out=S)[idx]
  #B_1<-seq(0,100,length.out=S)[idx]
  #B_2<-seq(0,100,length.out=S)[idx]
  #B<-cbind(B_0,B_1,B_2) #SxK
  #L<-X%*%t(B) #nxS
  
  K=sum(S/(S+(1:S)-1)) #104, his prior number of clusters when alpha=S
  if(type=="GJAM"){ cat("Prior expected number of clusters : ",K,"\n")}
  else{cat("Prior expected number of clusters : ",Ktrue,"\n")}
  K_t= Ktrue
  cat("True number of clusters : ",K_t,"\n")
  # A<-matrix(NA,nrow=ceiling(K_t),ncol=q)
  # # sig=matrix(runif(n=q*q),ncol=q)
  # for(i in 1:ceiling(K_t)){
  #   A[i,]<-mvrnorm(n = 1,rep(0,q), Sigma=3*diag(q)) #Nxq short and skinny
  # }
  # idx<-sample((1:ceiling(K_t)),S,replace=T) 
  # Lambda<-A[idx,] #Sxr tall and skinny
  # Sigma<-Lambda%*%t(Lambda)+0.1*diag(S) #SxS
  # Sigma_true<-Sigma
  # Y<-mvrnorm(n = n, mu=rep(0,S), Sigma=Sigma)
  # 
  # xdata<-as.data.frame(X[,-1])
  # colnames(xdata)<-c("env1","env2")
  xdata<-data_set$xdata
  Y<-data_set$Y
  idx<- data_set$idx
  
  Sigma_true<- data_set$S_true
  formula<-as.formula(~env1+env2)
  if(type=="GJAM"){
    rl <- list(r = r, N =Ntr-1)
    ml<-list(ng=it,burnin=burn,typeNames='CON',reductList=rl)
    fit<-gjam(formula,xdata,ydata=as.data.frame(Y),modelList = ml)
    alpha.chains<-NULL
    alpha.DP<-S
    pk_chains<-NULL
    pk<-NULL
    alpha.chains_short<-NULL
    pN_chain_short<-NULL
  }
  
  
  if(type=="0"){
    #func<-function(x) {sum(x/(x+(1:S)-1))-K_t}
    #alpha.DP<-.bisec(func,0.01,100)
    alpha.DP<-S
    rl <- list(r = r, N =Ntr-1,alpha.DP=alpha.DP)
    ml<-list(ng=it,burnin=burn,typeNames='CON',reductList=rl)
    fit<-.gjam0(formula,xdata,ydata=as.data.frame(Y),modelList = ml)
    alpha.chains<-NULL
    alpha.chains_short<-NULL
    pk_chains<- fit$chains$pk_g
  }
  if(type=="1"){
    func<-function(x) {sum(x/(x+(1:S)-1))-K_t}
    alpha.DP<-.bisec(func,0.01,100)
    shape=((alpha.DP)^2)/20
    rate=alpha.DP/20
    rl  <- list(r = r, N = Ntr-1, rate=rate,shape=shape)
    ml<-list(ng=it,burnin=burn,typeNames='CON',reductList=rl)
    fit<-.gjam_1(formula,xdata,ydata=as.data.frame(Y),modelList = ml)
    alpha.chains<-fit$chains$alpha.DP_g
    pk_chains<- fit$chains$pk_g
  }
  if(type=="2"){
    func<-function(x) {sum(x/(x+(1:S)-1))-K_t}
    alpha.DP<-.bisec(func,0.01,100)
    shape=((alpha.DP)^2)/20
    rate=alpha.DP/20
    rl  <- list(r = r, N = Ntr-1, rate=rate,shape=shape,V=1)
    ml<-list(ng=it,burnin=burn,typeNames='CON',reductList=rl)
    fit<-.gjam_2(formula,xdata,ydata=as.data.frame(Y),modelList = ml)
    alpha.chains<-fit$chains$alpha.DP_g
    pk_chains<- fit$chains$pk_g
  }
  if(type=="3"){
    eps=0.01
    # alp_sig<-as.data.frame(matrix(NA,nrow=20,ncol=3))
    # colnames(alp_sig)<-c("alpha","sigma","is_less_150")
    # alp_sig$sigma=seq(0.05,0.5,length.out = 20)
    # #loop to run bisection on a grid for sigma
    # for(i in 1:20){
    #   ####corrected formula : added -1
    #   func<-function(x) {(x/alp_sig[i,"sigma"])*(prod((x+alp_sig[i,"sigma"]+c(1:S) -1)/(x+c(1:S) -1))-1) - K_t}
    #   alp_sig[i,"alpha"]<-.bisec(func,0.0001,100)
    #   N_eps<-floor(.compute_tau_mean(alp_sig[i,"sigma"], alp_sig[i,"alpha"],eps) + 2*.compute_tau_var(alp_sig[i,"sigma"], alp_sig[i,"alpha"],eps))
    #   ifelse(N_eps<=150,alp_sig[i,"is_less_150"]<-T,alp_sig[i,"is_less_150"]<-F)
    #   N_eps
    # }
    # if(sum(alp_sig$is_less_150==T)==0) cat("!! no choice under N=150, need to recheck!!!")
    # k<-min(which(alp_sig$is_less_150==T)) #max sigma s.t. N<150
    # sigma_py<-alp_sig[k,"sigma"]
    # alpha.PY<-alp_sig[k,"alpha"]
    sigma_py<-0.25
    funcPY_root<-function(x) {(x/sigma_py)*(prod((x+sigma_py+c(1:S) -1)/(x+c(1:S) -1))-1) - K_t}
    alpha.PY<-.bisec(funcPY_root,0.0001,100)
    
    
    N_eps<-floor(.compute_tau_mean(sigma_py,alpha.PY,eps) + 2*.compute_tau_var(sigma_py,alpha.PY,eps))
    
    rl   <- list(r = r, N = N_eps, sigma_py=sigma_py, alpha=alpha.PY)
    ml<-list(ng=it,burnin=burn,typeNames='CON',reductList=rl)
    fit<-.gjam_3(formula,xdata,ydata=as.data.frame(Y),modelList = ml)
    alpha.chains<-NULL
    alpha.chains_short<-NULL
    pk_chains<- fit$chains$pk_g
    alpha.DP<-alpha.PY
    Ntr<-N_eps+1
  }
  if(type=="4"){
    eps=0.1
    alp_sig<-as.data.frame(matrix(NA,nrow=20,ncol=3))
    colnames(alp_sig)<-c("alpha","sigma","is_less_150")
    alp_sig$sigma=seq(0.05,0.4,length.out = 20)
    #loop to run bisecetion on a grid for sigma
    for(i in 1:20){
      ####corrected added  -1
      func<-function(x) {(x/alp_sig[i,"sigma"])*(prod((x+alp_sig[i,"sigma"]+c(1:S)-1)/(x+c(1:S) -1))-1) - K_t}
      alp_sig[i,"alpha"]<-.bisec(func,0.0001,100)
      N_eps<-floor(.compute_tau_mean(alp_sig[i,"sigma"], alp_sig[i,"alpha"],eps) + 2*.compute_tau_var(alp_sig[i,"sigma"], alp_sig[i,"alpha"],eps))
      ifelse(N_eps<=150,alp_sig[i,"is_less_150"]<-T,alp_sig[i,"is_less_150"]<-F)
      N_eps
    }
    
    if(sum(alp_sig$is_less_150==T)==0) cat("!! no choice under N=150, need to recheck!!!")
    
    k<-max(which(alp_sig$is_less_150==T)) #max sigma s.t. N<150
    sigma_py<-alp_sig[k,"sigma"]
    alpha.PY<-alp_sig[k,"alpha"]
    #fixing hyperparameters
    ro.disc=1-2* sigma_py
    shape=((alpha.PY)^2)/10
    rate=alpha.PY/10
    # 95% quantile of alpha
    alpha.max=qgamma(.95, shape=shape, rate=rate)
    alpha.max_val<-5
    sigma_py_max<-0.5
    N_eps<-floor(.compute_tau_mean(sigma_py_max,alpha.max_val,eps) + 2*.compute_tau_var(sigma_py_max,alpha.max_val,eps))
    
    
    rl   <- list(r = r, N = N_eps,rate=rate,shape=shape,V1=1,ro.disc=ro.disc) #here to modify N
    ml<-list(ng=it,burnin=burn,typeNames='CON',reductList=rl)
    fit<-.gjam_4(formula,xdata,ydata=as.data.frame(Y),modelList = ml)
    alpha.chains<-fit$chains$alpha.PY_g
    sigma.chains<-fit$chains$discount.PY_g
    pk_chains<- fit$chains$pk_g
    Ntr<-N_eps+1
    alpha.DP<-alpha.PY
    
  }
  trace<-apply(fit$chains$kgibbs,1,function(x) length(unique(x)))
  ind_trace<- seq(1,it,by=1)
  trace_short<- trace[ind_trace]
  df<-as.data.frame(trace)
  df$iter<-1:it
  #####Weights plot
  if(type%in%c("0","1","2","3","4")){
    pk<- apply(fit$chains$pk_g[-c(1:burn),],2,mean)
    last_pk<- round(pk[Ntr-1],3)
    df_weights <- data.frame(matrix(NA, nrow = Ntr-1, ncol =1))
    df_weights$pw<-pk 
    df_weights$tr<-1:(Ntr-1)
    pl_weigths<- ggplot(df_weights, aes(x=tr, y=pw)) +
      geom_segment( aes(x=tr,xend=tr,y=0,yend=pw)) +
      geom_point( size=0.5, color="red", fill=alpha("blue", 0.3), alpha=0.4, shape=21, stroke=2)+  labs(title=paste0("Weights for the case: S=",S," ,r=",r," true gr K=",K_t," ,type=",type, " ,N=",Ntr, " pN=",last_pk), caption=paste0("Number of iterations: ",it," burnin: ",burn," number of samples: ",nsamples))+
      theme_bw() + theme(axis.text.x = element_text(angle = 0, hjust = 1,size = 10), strip.text = element_text(size = 15),legend.position = "top", plot.title = element_text(hjust = 0.5))
    # pl_weigths
  }
  #####Alpha plot
  if(type%in%c("1","2","4")){ 
    df_alpha <- data.frame(matrix(NA, nrow =it-burn, ncol =1))
    df_alpha$alpha<- alpha.chains[-c(1:burn)]
    df_alpha$type<- "posterior"
    df_alpha_prior <- data.frame(matrix(NA, nrow =it-burn, ncol =1))
    #df_alpha_prior$alpha<- rgamma(it-burn, shape, rate)
    alpha_seq= seq(min(alpha.chains[-c(1:burn)]),max(alpha.chains[-c(1:burn)]),length=it-burn)
    df_alpha_prior$alpha <- dgamma(alpha_seq,rate,shape)
    
    df_alpha_prior$type<- "prior"
    df_alpha_all<- rbind(df_alpha[-1,],df_alpha_prior[-1,])
    ###Compute mean
    mu <- ddply(df_alpha_all, "type", summarise, grp.mean=mean(alpha))
    mu$grp.mean[which(mu$type=="prior")]=alpha.DP
    p_alpha_1<- ggplot(df_alpha_all, aes(x=alpha, color=type)) + geom_vline(data=mu, aes(xintercept=grp.mean, color=type),linetype="dashed")+
      geom_density()+labs(title=paste0("Distribution alpha: S=",S," ,r=",r," true gr K=",K_t," ,type=",type, " ,N=",Ntr), caption=paste0("Number of iterations: ",it," burnin: ",burn," number of samples: ",nsamples))+
      theme_bw() + theme(axis.text.x = element_text(angle = 0, hjust = 1,size = 10), strip.text = element_text(size = 15),legend.position = "top", plot.title = element_text(hjust = 0.5))
    # p_alpha_1
    
    p_alpha_2<- ggplot(df_alpha, aes(x=alpha)) + geom_vline(data=mu, aes(xintercept=grp.mean, color=type),linetype="dashed")+
      geom_density(color="red")+labs(title=paste0("Posterior distribution for alpha"), caption=paste0("Number of iterations: ",it," burnin: ",burn," number of samples: ",nsamples," S=",S," ,r=",r," true gr K=",K_t," ,type=",type, " ,N=",Ntr))+
      theme_bw() + theme(axis.text.x = element_text(angle = 0, hjust = 1,size = 10), strip.text = element_text(size = 15),legend.position = "top", plot.title = element_text(hjust = 0.5))+
      scale_color_manual(name = c("Legend"), values = c("prior"="#9999FF", "posterior"= "#FF6666"), labels=c("posterior mean","prior mean"))
    # p_alpha_2
  }  
  #######Sigma plot
  if(type%in%c("4")){ 
    df_sigma <- data.frame(matrix(NA, nrow =it-burn, ncol =1))
    df_sigma$sigma<- sigma.chains[-c(1:burn)]
    ###Compute mean
    mu <- ddply(df_sigma, type, summarise, grp.mean=mean(sigma))
    p_sigma<- ggplot(df_sigma, aes(x=sigma)) + geom_vline(data=mu, aes(xintercept=grp.mean),linetype="dashed")+
      geom_density()+labs(title=paste0("Distribution sigma: S=",S," ,r=",r," true gr K=",K_t," ,type=",type, " ,N=",Ntr), caption=paste0("Number of iterations: ",it," burnin: ",burn," number of samples: ",nsamples))+
      theme_bw() + theme(axis.text.x = element_text(angle = 0, hjust = 1,size = 10), strip.text = element_text(size = 15),legend.position = "top", plot.title = element_text(hjust = 0.5))
    # p_sigma
    
    dfs<-as.data.frame(sigma.chains)
    dfs$iter<-1:it
    #plot(apply(fit$chains$kgibbs,1,function(x) length(unique(x))))
    p_trace_sigma<-ggplot(dfs, aes(y=sigma.chains, x=iter)) + geom_point() + 
      labs(title=paste0("Trace plot for the sigma for S=",S," r=",r," true K=",K_t," type=",type), caption=paste0("Number of iterations: ",it," burnin: ",burn,"number of samples: ",nsamples))+
      theme_bw() + theme(axis.text.x = element_text(angle = 0, hjust = 1,size = 10), strip.text = element_text(size = 15),legend.position = "top", plot.title = element_text(hjust = 0.5))
    # p_trace_sigma
  } 
  
  
  N_dim<-(it-burn)
  sigma<-array(dim=c(Sp,Sp,N_dim))
  for(j in 1:N_dim){
    K<-fit$chains$kgibbs[j,]
    Z  <- matrix(fit$chains$sgibbs[j,],Ntr-1,r)
    sigma[,,j] <- .expandSigma(fit$chains$sigErrGibbs[j], Sp, Z = Z, fit$chains$kgibbs[j,], REDUCT = T) #sigma
    
  }
  sigma_mean<-apply(sigma,c(1,2),mean)
  err<-sum((sigma_mean-Sigma_true)^2)/(Sp*Sp)
  rmspe<-fit$fit$rmspeAll
  plot_list<-list()
  if(type%in%c("1","2","4")){ 
    #plot(p_alpha_1)
    #plot(p_alpha_2)
    plot_list<-list.append(plot_list,p_alpha_1)
    plot_list<-list.append(plot_list,p_alpha_2)
  }
  if(type%in%c("4")){ 
    # plot(p_sigma)
    #  plot(p_trace_sigma)
    plot_list<-list.append(plot_list,p_sigma)
    plot_list<-list.append(plot_list,p_trace_sigma)
  }
  if(type%in%c("0","1","2","3","4")){ 
    #plot(pl_weigths)
    plot_list<-list.append(plot_list,pl_weigths)
  }

  if(type%in%c("1","2","4")){ 
    ind_alpha<- seq(1,length(alpha.chains), by =10)
    alpha.chains_short<- alpha.chains[ind_alpha]
  }
  if(type%in%c("0","1","2","3","4")){ 
    pN_chain<- pk_chains[-c(1:burn),(Ntr-1)]
    ind_pn<- seq(1,length(pN_chain), by =10)
    pN_chain_short<- pN_chain[ind_pn]
  }
  # pl_list=plot_list
  return(list(trace=trace_short,
              idx=idx,K=fit$chains$kgibbs[it,],
              alpha=alpha.DP,alpha.chains=alpha.chains_short,pk_val=pk, pkN=pN_chain_short, 
              coeff_t=Sigma_true,coeff_f=sigma_mean,
              err=err,fit=rmspe))
}

####### Just one possible test case
#sim<-simulation_fun(Sp=50, Ntr=150, rval=3,nsamples=500, Ktrue=4,it=1000,burn=200,type=2)
# plot(as.vector(sim$coeff_t),as.vector(sim$coeff_f))
# x11()
# heatmap(sim$coeff_f)
# x11()
# heatmap(sim$coeff_t)
# plot(sim$trace)
# plot(sim$idx,sim$K)
#possible parameters to add in the loop:
# - type (T) of gjam to be fitted
# - n, the number of simulated normals
# - N, the truncation level
# - S, the number of species
# - K_t, the true number of clusters

###########Simulation for Continous data case :small S K=4###################################################



#####################################Simulation 2 K=10#######################################

####Small S, N==S, n=500

list=list()
list2=list()
list3=list()
list4=list()
list5=list()
list0=list()
data_list=list()
lk<-list()
S_vec<-c(100)
r_vec<-5
n_vec<-c(10)
k<-1
it<-1000
burn<-500
Ktr<-4
q<-20

path<- "/Users/bystrova/Documents/GitHub/gjamed/smalln"
for(i in 1:length(S_vec)){
  data_list=list()
  k=1
  list=list()
  list2=list()
  list3=list()
  list4=list()
  list5=list()
  list0=list()
  for(j in 1:length(n_vec)){
    for(l in (1:5)){
      data_list<- list.append(data_list,generate_data(Sp=S_vec[i],nsamples=n_vec[j],qval=q,Ktrue=Ktr))
      names(data_list)[[l]]<-paste0("S_",S_vec[i],"_q_",q,"n_",n_vec[j],"_K_",Ktr,"_l",l)
    }
   #save(data_list, file = paste0("DS_S_",S_vec[i],"_q_",q,"_n_500_",Ktr,"ns",n_vec[j],".Rda"))
   Ntrunc<-min(S_vec[i],150)
    ########GJAM  model list########################    
    # l0<-list()
    # l0<- mclapply(data_list,simulation_fun_oneDS,Sp=S_vec[i], Ntr=Ntrunc, q=q,rval=r_vec,nsamples=n_vec[j], Ktrue=Ktr,it=it,burn=burn,type="GJAM")
    # list<-list.append(list,assign(paste0("S_",S_vec[i],"_r_",r_vec,"_N_",S_vec[i],"_n_",n_vec[j],"_K",Ktr),l0))
    # names(list)[[k]]<-paste0("S_",S_vec[i],"_r_5","_N_",S_vec[i],"_n_",n_vec[j],"_K",Ktr)
    # save(list, file =paste0("/mnt/workspace/Gjammod/smalln/ODSim_smallS",S_vec[i],"K4_gjam.Rda"))
    ########gjam 0  model list########################
    l00<-list()
    l00<- lapply(data_list,simulation_fun_oneDS,Sp=S_vec[i], Ntr=Ntrunc, q=q,rval=r_vec,nsamples=n_vec[j], Ktrue=Ktr,it=it,burn=burn,type="0")
    list0<-list.append(list0,assign(paste0("S_",S_vec[i],"_r_5_N_150_n_",n_vec[j],"_K",Ktr),l00))
    names(list0)[[k]]<-paste0("S_",S_vec[i],"_r_",r_vec,"_N_150_n_500_K_",Ktr)
   save(list0, file = paste0(path,"ODSim_smallS",S_vec[i],"K",Ktr,"_gjam0.Rda"))
    ########gjam 1  model list######################## 
    l2<-list()
    l2<- lapply(data_list,simulation_fun_oneDS,Sp=S_vec[i], Ntr=150, q=q,rval=r_vec,nsamples=n_vec[j], Ktrue=Ktr,it=it,burn=burn,type="1")
    list2<-list.append(list2,assign(paste0("S_",S_vec[i],"_r_5_N_150_n_",n_vec[j],"_K",Ktr),l2))
    names(list2)[[k]]<-paste0("S_",S_vec[i],"_r_",r_vec,"_N_150_n_500_K",Ktr)
    save(list2, file = paste0(path,"ODSim_smallS",S_vec[i],"K",Ktr,"_type1.Rda"))
    ########gjam 2  model list########################    
    l3<-list()
    l3<- lapply(data_list,simulation_fun_oneDS,Sp=S_vec[i], Ntr=Ntrunc, q=q,rval=r_vec,nsamples=n_vec[j], Ktrue=Ktr,it=it,burn=burn,type="2")
    list3<-list.append(list3,assign(paste0("S_",S_vec[i],"_r_5_N_150_n_",n_vec[j],"_K",Ktr),l3))
    names(list3)[[k]]<-paste0("S_",S_vec[i],"_r_5_N_150_n_500_K",Ktr)
    save(list3, file = paste0(path,"ODSim_smallS",S_vec[i],"K",Ktr,"_type2.Rda"))
    ########gjam 3  model list########################    
    l4<-list()
    l4<- lapply(data_list,simulation_fun_oneDS,Sp=S_vec[i], Ntr=150, q=q,rval=r_vec,nsamples=n_vec[j], Ktrue=Ktr,it=it,burn=burn,type="3")
    list4<-list.append(list4,assign(paste0("S_",S_vec[i],"_r_5_N_150_n_",n_vec[j],"_K",Ktr),l4))
    names(list4)[[k]]<-paste0("S_",S_vec[i],"_r_5_N_150_n_500_K",Ktr)
    save(list4, file = paste0(path,"ODSim_smallS",S_vec[i],"K",Ktr,"_type3.Rda"))
    ########gjam 4  model list########################    
    l5<-list()
    l5<- lapply(data_list,simulation_fun_oneDS,Sp=S_vec[i], Ntr=150, q=q,rval=r_vec,nsamples=n_vec[j], Ktrue=Ktr,it=it,burn=burn,type="4")
    list5<-list.append(list5,assign(paste0("S_",S_vec[i],"_r_5_N_150_n_500_K",Ktr),l5))
    names(list5)[[k]]<-paste0("S_",S_vec[i],"_r_5_N_150_n_",n_vec[j],"_K",Ktr)
    save(list5, file = paste0(path,"ODSim_smallS",S_vec[i],"K",Ktr,"_type4.Rda"))
    k=k+1
  }
 
}

