# InSight generated 4,588 watt-hours on its first sol.
# Phoenix lander generated around 1,800 watt-hours in a day.

library(mars)
library(here)
library(whisker)
library(wesanderson)

palette = wes_palette("Darjeeling1", 3)

# Define a class to encapsulate rover power consumption details.
RoverPower = setClass(
  "RoverPower",
  slots=list(name="character",
             propulsion="numeric",
             base="numeric",
             hibernate="numeric"))

# create a method to get the total power.
setGeneric(name="total",
           def=function(object)
           {
             standardGeneric("total")
           }
)

setMethod(f="total",
          signature="RoverPower",
          definition=function(object)
          {
            total = object@propulsion + object@base
            return(total)
          }
)

# Instanciate class for MER and Sherpa rovers.
mer = new("RoverPower", name="MER", propulsion=100, base=40, hibernate=40)
sherpa = new("RoverPower", name="SherpaTT", propulsion=216, base=160, hibernate=100)


Ls_list = list(
  "Vernal Equinox" = 0,
  "Aphelion" = 71,
  "Summer Solstice" = 90,
  "Dust Storm Season Begins" = 180,
  "Autumn Equinox" = 180,
  "Periphelion" = 248,
  "Winter Solstice" = 270,
  "Dust Storm Season Ends" = 330)

phi_list = list(
  'Victoria Crater' = -2.05,
  'Nanedi Vallis' = 5.2,
  'Naktong Vallis' = 5.3,
  'Melas Coprates' = -10.4,
  'Kasei Valles' = 24.6
)

Ls_global_dust_storm_season = Ls_list$'Dust Storm Season Begins':Ls_list$'Dust Storm Season Ends'
Ls_non_global_dust_storm_season = c(1:Ls_list$'Dust Storm Season Begins', Ls_list$'Dust Storm Season Ends':360)

e = 0.26  # Solar panel efficiency.

# Performance ratio / coefficient for losses is determined based on literature:
#
#   1. Thomas W. Kerslake et al.:
#       On a given day, cell efficiency varies 3% due to changing temperature and
#       red-  shift spectral losses through the day time-period.
#
#   2. Geoffrey A. Landis et al.: 
#       2.1 Dust deposition on the solar arrays was measured on the Pathfinder
#           mission to to degrade the performance at a rate of 0.28% per sol
#           during the initial 30 sols of the mission.
#       2.2 Longer measures on MER missions indicate that long-term degradation
#            is about 0.14% per sol.
#
#   3. Jeremiah McNatt et al.:
#       After deployment, a 5% permanent dust power loss is added to the assumption
#       with more accumulated dust removed periodically.
#
#   4. Paul M. Stella et al.
#       Dust performance degradation is about 30%.
#
PR = 1 - (0.03 + 0.05 + 0.30)

# FIXME: During storm, we get different values if nfft=1 or nfft=2
# Get the worst global irradiance on Mars horizontal surface [W/m2].
Gh_worst = function(Ls_range, phi, longitude, z, tau, verbose=FALSE){
  Gh_worst = 600
  Ls_worst = -1
  
  for(Ls in Ls_range){
    Gh = G_h(Ls=Ls, phi=phi, longitude=longitude, z=z, tau=tau) 
    if(Gh < Gh_worst){
      Gh_worst = Gh
      Ls_worst = Ls
    }
  }
  
  if(isTRUE(verbose)){
    text_template = "Worst high-noon irradiance with tau = {{tau}} occurs at Ls = {{Ls}}° with Gh = {{Gh}} W/m2."
    text_data = list(tau=tau, Ls=Ls_worst, Gh=round(Gh_worst))
    text = whisker.render(text_template, text_data)
    print(text)
  }
  
  return(list(
    "Ls"=Ls_worst,
    "Gh"=Gh_worst,
    "tau" = tau))
}

# Get the worst global daily insolation on Mars horizontal surface [Wh/m2-day].
Hh_worst = function(Ls_range, phi, longitude, tau, verbose=FALSE){
  Hh_worst = 50000
  Ls_worst = -1
  
  for(Ls in Ls_range){
    Hh = H_h(Ls=Ls, phi=phi, longitude=longitude, tau=tau)
    
    if(Hh < Hh_worst){
      Hh_worst = Hh
      Ls_worst = Ls
    }
  }
  
  if(isTRUE(verbose)){
    text_template = "Worst daily insolation with tau = {{tau}} occurs at Ls = {{Ls}}° with Hh = {{Hh}} Wh/m2."
    text_data = list(tau=tau, Ls=Ls_worst, Hh=round(Hh_worst))
    text = whisker.render(text_template, text_data)
    print(text)
  }
  
  return(list(
    "Ls" = Ls_worst,
    "Hh" = Hh_worst,
    "tau" = tau))
}


# Get the solar time at which a given Energy is produced.
# The smaller the T_step, the more accurate the answer.
get_solar_times_for_energy = function(E_target, T_step=0.1, A, Ls, phi, tau){
  
  # Use a list to store the results.
  result = list(
    'MorningTime' = -1,
    'MorningEnergy'= -1,
    'AfternoonTime' = -1,
    'AfternoonEnergy' = -1
  )
  
  # Get the daylight solar time range for the Ls with the worst insolation.
  T_sr = sunrise(Ls=Ls, phi=phi, unit=3)
  T_ss = sunset(Ls=Ls, phi=phi, unit=3)
  
  E_best = 0
  Ts_best = 0
  E_diff_smallest = 10000
  
  # Scan from sunrise to noon.
  for(Ts in seq(round(T_sr), 12, T_step)){
    Gh_current = G_h(Ls=Ls, phi=phi, Ts=Ts, tau=tau)
    E_current = A * e * Gh_current * PR
    
    E_diff_current = abs(E_target - E_current)
    if(E_diff_current < E_diff_smallest){
      E_diff_smallest = E_diff_current
      E_best = E_current
      Ts_best = Ts
    }
  }
  
  
  # Set morning results.
  result$MorningTime = Ts_best
  result$MorningEnergy = E_best
  
  # Reset tracking variables to scan second part of the day (from noon to sunset).
  E_best = 0
  Ts_best = 0
  E_diff_smallest = 10000
  
  # Scan from noon to sunset.
  for(Ts in seq(12, round(T_ss), T_step)){
    Gh_current = G_h(Ls=Ls, phi=phi, Ts=Ts, tau=tau, al=al, nfft=nfft)
    E_current = A * e * Gh_current * PR
    
    E_diff_current = abs(E_target - E_current)
    if(E_diff_current < E_diff_smallest){
      E_diff_smallest = E_diff_current
      E_best = E_current
      Ts_best = Ts
    }
  }
  
  # Set afternoon results.
  result$AfternoonTime = Ts_best
  result$AfternoonEnergy = E_best
  
  return(result)
}

# Get the worst irradiance
get_worst_energy_profile = function(A, Ls_range=NULL, phi, longitude, tau, Hh_w=NULL, verbose=FALSE){
  # Get the worst insolation.
  if(is.null(Hh_w)){
    Hh_w = Hh_worst(Ls_range=Ls_range, phi=phi, longitude=longitude, tau=tau, verbose=verbose)
  }
  
  # Get the daylight solar time range for the Ls with the worst insolation.
  T_sr = sunrise(Ls=Hh_w$Ls, phi=phi, unit=3)
  T_ss = sunset(Ls=Hh_w$Ls, phi=phi, unit=3)
  Ts_range = seq(T_sr, T_ss, 1)
  
  if(isTRUE(verbose)){
    print(paste("Daylight is ", round(T_ss - T_sr, 2), " hours long from ", round(T_sr, 2), " h to ", round(T_ss, 2), " h", sep=""))
  }
  
  # Prep data matrix.
  data_matrix = matrix(NA, nrow=4, ncol=length(Ts_range))
  rownames(data_matrix) = c('Ts', 'Z', 'Gh', 'E')
  
  # Calculated generated solar panel energy.
  Ts_index = 1
  for(Ts in Ts_range){
    Gh = G_h(Ls=Hh_w$Ls, phi=phi, longitude=longitude, Ts=Ts, tau=tau)
    z = Z(Ls=Hh_w$Ls, phi=phi, Ts=Ts)
    
    # Energy generated from solar panels [Wh].
    E = A * e * Gh * PR
    
    #FIXME: First Gh is negative
    data_matrix[1, Ts_index] = Ts
    data_matrix[2, Ts_index] = z
    data_matrix[3, Ts_index] = Gh
    data_matrix[4, Ts_index] = E
    
    Ts_index = Ts_index + 1
  }
  
  return(data_matrix)
}


#print('During a year with no global storms:')
#Hh_w1 = Hh_worst(Ls_range=1:360, phi, tau)
#Gh_w1 = Gh_worst(Ls_range=1:360, Z=0, tau=tau)

#print("")

# Get worst moment during global storm season.
#tau = 5 # Jeremiah McNatt et al.

#print('During global storms season:')
#Hh_w2 = Hh_worst(Ls_range=Ls_global_dust_storm_season, phi, tau)
#Gh_w2 = Gh_worst(Ls_range=Ls_global_dust_storm_season, Z=0, tau=tau)

#Hh_w = if(Hh_w1$Hh < Hh_w2$Hh) Hh_w1$Hh else Hh_w2$Hh
#Ls_w = if(Hh_w1$Hh < Hh_w2$Hh) Hh_w1$Ls else Hh_w2$Ls
#tau_w = if(Hh_w1$Hh < Hh_w2$Hh) Hh_w1$tau else Hh_w2$tau


plot_energy_profile = function(A, Ls_range, phi, longitude, tau,
                               E_threshold, E_threshold_timestep=0.1,
                               prop_duration,
                               title='',
                               verbose=TRUE){
  
  # Get data for worst insolation conditions.
  Hh_w = Hh_worst(Ls_range=Ls_range, phi=phi, longitude=longitude, tau=tau, verbose=verbose)
  
  # Get data for energy profile.
  data_matrix = get_worst_energy_profile(A=A, Ls_range=NULL, phi=phi, longitude=longitude, tau=tau, Hh_w=Hh_w, verbose=verbose)
  
  # Ge data for propulsion energy threshold.
  #E_prop_threshold = get_solar_times_for_energy(E_target=E_threshold, T_step=E_threshold_timestep, A=A, Ls=Hh_w$Ls, phi=phi, tau=tau, al=al, nfft=nfft)
  
  # Plot insolation.
  dev.new()
  # plot(x=round(data_matrix['Ts',]),
  #      y=data_matrix['E',],
  #      xlab="Solar Time, T [h]",
  #      ylab="Energy, E [Wh]",
  #      ylim=c(0, 80),
  #      type="l",
  #      lwd=4,
  #      col='grey',
  #      main=title,
  #      font.sub=2,
  #      cex.sub=1.2)
  
  barplot(data_matrix['E',],
          names.arg=round(data_matrix['Ts',]),
          #axisnames=FALSE,
          xlab="Solar Time, T [h]",
          ylab="Energy, E [Wh]",
          ylim=c(0, 130),
          col='red',
          main=title)
  
  # mtext(text=round(data_matrix['Ts',]),
  #       side=1, at=0, line=1)
  # 
  # mtext(text=round(data_matrix['Ts',]),
  #       las=1,
  #       line=0.5,
  #       side=1,
  #       at=seq(1.4, 13.4, 1)
  # )
  
  
  # plot(x=NULL, y=NULL,
  #      xlab='Solar Time, T [h]',
  #      ylab='Energy, E [Wh]',
  #      xlim=c(6, 18),
  #      ylim=c(0, 80))
  # 
  # smooth_line = smooth.spline(round(data_matrix['Ts',]), data_matrix['E',], spar=0.4)
  # lines(smooth_line, col='grey')
  # print(smooth_line$y)
  
  #print(E_prop_threshold)
  
  # Propulsion energy threshold.
  # lines(x=c(E_prop_threshold$MorningTime-4.3, E_prop_threshold$AfternoonTime-3.9),
  #       y=c(E_threshold, E_threshold),
  #       lty=1,
  #       lwd=4,
  #       col=palette[1])
  # 
  # # Propulsion time window
  # prop_time_window = E_prop_threshold$AfternoonTime - E_prop_threshold$MorningTime
  # 
  # text_pos_time_window = E_prop_threshold$MorningTime + (prop_time_window / 2)
  # text(text_pos_time_window, E_threshold,
  #      labels=paste("d =", prop_time_window, "h"),
  #      cex=0.7,
  #      pos=1,
  #      col='blue')
  # 
  # # Latest propulsion start time if we want a 2 hour long traverse.
  # prop_start_time_latest = E_prop_threshold$MorningTime + abs(prop_time_window - prop_duration)
  # points(prop_start_time_latest-0.1, E_threshold,
  #        pch=18,
  #        col="red")
  # 
  # text(prop_start_time_latest, E_threshold,
  #      labels=paste(prop_start_time_latest, "h"),
  #      cex=0.7,
  #      pos=3,
  #      col='red')
  # 
  # prop_end_time_latest = E_prop_threshold$AfternoonTime
  # points(prop_end_time_latest-0.1, E_threshold,
  #        pch=18,
  #        col="red")
  # 
  # text(prop_end_time_latest, E_threshold,
  #      labels=paste(prop_end_time_latest, "h"),
  #      cex=0.7,
  #      pos=3,
  #      col='red')
  
  
  
  # legend("topright", legend=c('Locomotion threshold', 'Locomotion energy', 'Excess energy'),
  #        col=c(palette[1],  NA,  NA), lty=c(1, NA,  NA), density=c(0,NA,NA), fill=c(palette[1],palette[2],palette[3]),
  #        border=c(NA,palette[2],palette[3]), x.intersp=c(2,0.5,0.5),
  #        bty='n', cex=0.9)
  # 
  
  # legend("topright", legend=c('Generated energy', 'Locomotion threshold'),
  #        col=c('grey', 'blue'), lty=1, lwd=4)
  
}

# Total solar panel area [m2].
A = 1.9
power_draw_propulsion = 120 # [W]
duration_propulsion = 1 # [hr]
phi = phi_list$'Victoria Crater'
longitude = 40

###############################
# Without global dust storms. #
###############################

tau = 0.5

title_template = 'Generated Energy with {{area}} m² Solar Array, at tau factor {{tau}}, and \nWindow of Time for {{duration}} h Locomotion with {{power}} W Power Draw'
title_data = list(area = A,
                  duration = duration_propulsion,
                  power = power_draw_propulsion,
                  tau = tau
)

title = whisker.render(title_template, title_data)

#Assuming a motor draw of 60 W, motor drive can run for 2 hours with 120 Wh Energy.
plot_energy_profile(A=A, Ls_range=Ls_non_global_dust_storm_season, phi=phi, longitude=longitude, tau=tau,
                    E_threshold=power_draw_propulsion, prop_duration=duration_propulsion,
                    title=title,
                    #title='Excess Energy Available',
                    verbose=TRUE)


############################
# With global dust storms. #
############################

# Assuming a motor draw of 60 W, motor drive can run for 1 hour with 60 Wh Energy.
# plot_energy_profile(A=A, Ls_range=Ls_global_dust_storm_season, phi=phi, tau=5, al=0.1, nfft=3,
#                     E_threshold=60, prop_duration=1,
#                     verbose=TRUE)

# tau = 5
# 
# title_template = 'Generated Energy with {{area}} m² Solar Array, at tau factor {{tau}}, and \nWindow of Time for Locomotion with {{power}} W Power Draw'
# title_data = list(area = A,
#                   duration = duration_propulsion,
#                   power = power_draw_propulsion,
#                   tau = tau
# )
# title = whisker.render(title_template, title_data)

#Assuming a motor draw of 60 W, motor drive can run for 2 hours with 120 Wh Energy.
# plot_energy_profile(A=A, Ls_range=Ls_global_dust_storm_season, phi=phi, tau=tau, al=0.1, nfft=3,
#                     E_threshold=power_draw_propulsion, prop_duration=duration_propulsion,
#                     title=title,
#                     #title='Excess Energy Available',
#                     verbose=TRUE)

#dm = get_worst_energy_profile(A=A, Ls_range=Ls_non_global_dust_storm_season, phi=phi, tau=0.5, nfft=3, Hh_w=NULL, verbose=FALSE)