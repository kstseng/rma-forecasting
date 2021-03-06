YMD <- ymd <- "2017/10"
#
componentName <- compNameAppear[8]
dataM <- dataArrC(dat_all = dat_all, dat_com = dat_com, dat_shipping = dat_shipping, dat_future_shipping = dat_future_shipping, componentName = componentName, YMD = ymd)
elected <- selectNiC(dataM = dataM, YMD = ymd, minNi = 5, rmaNonparametricC = rmaNonparametricC)
out <- cbind(compName = rep(componentName, nrow(elected)), elected)
#
preResult <- out
addMonth <- "2017/11"
minNi = 3
updateNB <- 0


if (!is.null(dataM)){
  datShipPro <- dataM[[3]]
  if (nrow(datShipPro) != 0){
    uniqueProduct <- as.character(unique(datShipPro$Product_Name))
    #
    minY <- dataM[[1]][1]; minM <- dataM[[1]][2]; minD <- dataM[[1]][3]
    dataComp_c <- dataM[[2]]
    datShipPro <- dataM[[3]]
    dat_censored1 <- dataM[[4]]
    n_break <- dataM[[5]]
    
    endMonth <- seq(as.Date(paste(c(addMonth, "01"), collapse = "/")), length = 2, by = "months")[2]
    x1 <- as.character(seq(as.Date(paste(c(minY, minM, minD), collapse = "/")), 
                           as.Date(endMonth), "months"))
    
    x <- as.character(sapply(x1, function(y){
      tmp <- strsplit(y, "-")[[1]]
      tmp[3] <- "01"
      tmp2 <- paste(tmp[1], tmp[2], tmp[3], sep="/")
      return(tmp2)
    }))
    
    # ----- split the x so that it can match the dat_shipping (because dat_shipping only record the amount by month)
    x_split <- 0
    for (i in 1:length(x)){
      tmp <- strsplit(x[i], "/")[[1]]
      x_split[i] <- paste0(tmp[1], tmp[2])
    }
    x_mid <- sapply(1:length(x), function(i){
      tmpd <- strsplit(x[i], "/")[[1]]
      tmpd[3] <- "15"
      paste(tmpd, collapse = "/")
    })
    nList <- lapply(1:length(uniqueProduct), function(i){
      datShipPro_i <- datShipPro[which(datShipPro$Product_Name == uniqueProduct[i]), ]
      n_ship <- sapply(1:(length(x_split)), function(j){
        return(max(sum(datShipPro_i[which(datShipPro_i$Shipping_DT == x_split[j]), "Qty"]), 0))
      })
      return(matrix(n_ship, nrow=1))
    })
    for (l in 1:length(nList)){
      colnames(nList[[l]]) <- x_mid[1:(length(x_mid))]
    }
    names(nList) <- uniqueProduct
    dataComp_c <- dataM[[2]]
    #########
    x <- as.character(sapply(x1, function(y){
      tmp <- strsplit(y, "-")[[1]]
      tmp[3] <- "01"
      tmp2 <- paste(tmp[1], tmp[2], sep="/")
      return(tmp2)
    }))
    if (minD != 1){
      x <- c(x, YMD)
    }
    xDate <- x[1:length(x) - 1]
    
    #----- selection mechanism
    tmpEst <- 0
    tmpEstAll <- 0
    tmpLower <- 0
    tmpUpper <- 0
    tmpTrendmv <- 0
    tmpTrendmvAll <- 0
    tmpEstM <- 0
    tmpEstMAll <- 0
    
    if (length(xDate) > 24){
      tmpStore <- apply(rmaNonparametricC(addMonth, dataM, minNi = minNi, uniqueProduct = uniqueProduct, nList = nList, x_mid = x_mid, x = x, endMonth = endMonth), 1, sum)
      tmpEst <- tmpStore[1]
      tmpLower <- tmpStore[2]
      tmpUpper <- tmpStore[3]
      tmpTrendmv <- tmpStore[1]
      tmpTrendmvAll <- tmpStore[1]
      tmpEstM <- tmpStore[4]
      tmpEstAll <- tmpStore[5]
      tmpEstMAll <- tmpStore[6]
      #
      mean1 <- mean(n_break[(i - 1):(i - 5)])
      mean2 <- mean(n_break[(i - 2):(i - 6)])
      mean3 <- mean(n_break[(i - 3):(i - 7)])
      mean4 <- mean(n_break[(i - 4):(i - 8)])
      mean5 <- mean(n_break[(i - 5):(i - 9)])
      
      ft1 <- mean2 - mean1
      ft2 <- mean3 - mean2
      ft3 <- mean4 - mean3
      ft4 <- mean5 - mean4
      ftMean <- mean(c(ft1, ft2, ft3, ft4))
      tmpTrendmv <- mean(c(mean1 + ftMean,  sum(tmpStore[[1]])))
      tmpTrendmvAll <- mean(c(mean1 + ftMean,  sum(tmpStore[[5]])))
    }
    
    EstStorage <- matrix(c(tmpEst, tmpEstAll, tmpTrendmv, tmpTrendmvAll, tmpEstM, tmpEstMAll), ncol = 6)
    
    # -----
    Est <- EstStorage[, 1]
    EstAll <- EstStorage[, 2]
    #       Lower <- EstStorage[, 2]
    #       Upper <- EstStorage[, 3]
    nb <- c(as.numeric(n_break))
    #----
    MVTrend <- EstStorage[, 3]
    MVTrendAll <- EstStorage[, 4]
    EstModified <- EstStorage[, 5]
    EstModifiedAll <- EstStorage[, 6]
    
    update.n_break <- c(n_break, updateNB)
    updateEmp <- mean(update.n_break[(length(update.n_break) - 2):length(update.n_break)])
    
    prediction <- c(xDate[length(xDate)], updateNB, updateEmp, Est, EstAll, MVTrend, MVTrendAll, EstModified, EstModifiedAll)
    ## use time series to let the estimation close to the truth.
    ## ind is set as 30, because the frequency in time series is set as 12, it need at least 2 period.
    ind <- 30
    est.ts <- 0
    est.ts.all <- 0
    numOfTraceback <- 2
    #####
    if (nrow(preResult) >= ind){
      tmpTab <- preResult
      endD <- as.character(tmpTab[nrow(tmpTab), 2])
      enddate <- as.numeric(strsplit(endD[length(endD)], "/")[[1]])
      breakTS <- ts(tmpTab[, "nb"], start=c(minY, minM), end=c(enddate[1], enddate[2]), frequency=12) 
      fitB <- stl(breakTS, s.window="period")
      estTS <- ts(tmpTab[, "EstModified"], start=c(minY, minM), end=c(enddate[1], enddate[2]), frequency=12) 
      fitE <- stl(estTS, s.window="period")  
      diffValue <- (fitE$time.series[, "trend"] - fitB$time.series[, "trend"])
      dValue <- mean(diffValue[(length(diffValue) - numOfTraceback):length(diffValue)])
      est.ts <- est.ts - dValue
      #
      estTSAll <- ts(tmpTab[, "EstModifiedAll"], start=c(minY, minM), end=c(enddate[1], enddate[2]), frequency=12) 
      fitEAll <- stl(estTSAll, s.window="period")  
      diffValueAll <- (fitEAll$time.series[, "trend"] - fitB$time.series[, "trend"])
      dValueAll <- mean(diffValueAll[(length(diffValueAll) - numOfTraceback):length(diffValueAll)])
      est.ts.all <- est.ts.all - dValueAll
    }else{
      tmpTab <- preResult
      est.ts <- EstModified
      est.ts.all <- EstModifiedAll
    }
    #####
    neg <- which(est.ts < 0)
    if (length(neg) > 0){est.ts[neg] <- 0}
    negAll <- which(est.ts.all < 0)
    if (length(negAll) > 0){est.ts.all[negAll] <- 0}
    addRow <- matrix(c(componentName, prediction, est.ts, est.ts.all), nrow = 1)
    colnames(addRow) <- colnames(preResult)
    updateResult <- rbind(preResult, addRow)
  }else{
    updateResult <- out
  }
}else{
  updateResult <- out
}
