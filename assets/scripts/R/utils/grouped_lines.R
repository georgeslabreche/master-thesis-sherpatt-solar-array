#' This function segments a vector of incrementing numericals into subgroups. Each subgroup is plotted as its own line.
#' The vector of numericals are expected to be cyclical, meaning that they increment from a min value to a max value
#' and then restart from the min value after the max has been reached.
#'
#' e.g. Given x = [1, 2, 3, 4, 2, 3, 3, 4, 1, 1, 3, 1, 1, 2, 2]
#' The subgroups that will be plotted are the following:
#'     x_1 = [1, 2, 3, 4]
#'     x_2 = [2, 3, 3, 4]
#'     x_3 = [1, 1, 3]
#'     x_4 = [1, 1, 2, 2]
#'
#' Vectors x and y are meant for x-axis and y-axis respectively.
#' Values in the i vector are related to the x vector and used to apply lower and upper bounds to the processed data. 
#'
#' x_floor and x_ceil can be defined to enforce x value min and max boundaries that should be respected.
#' x values that are out of the defined boundary can either be ignored or modifed to fit in the boundary.
#' Modofication to fit the boundary was was originally designed to handle angle values in degrees.
#'
#' e.g. if x values represent degree angles between 0 and 360 then this can be enforced with x_floor=0 and x_ceil=360.
#'   if x = -12 then x = x + c_ceil so that x = 348
#'   if x = 388 then x = x - c_ceil so that x = 28
#'
#' @param x Vector of x-axis data. Incremental cylcle of numericals.
#' @param y Vector of y-axis data.
#' @param x_floor Lower bound to be enforced on x values.
#' @param x_ceil Upper bound to be enforced on y values.
#' @param force_x_inside_bounds TRUE: Converting x values that fit within the x_floor and x_ceil boundary. FALSE: Drop x values that are not withing the x_floor and x_ceil boundary.
#' @param i A vector with values that relate to those in the x vector. Used as a second source of data to define x value subrange that should be processed.
#' @param ilim From which i value should the x vector start and stop being read.
#' @param include_iterations Selecively plot the resulting x subgroups by indicating their indices.
#' @param cols Line colors.
#' @param lwd Line width.
#' @param lty Line type.
#'
#' @return Grouped line plot.
grouped_lines = function(
  x, y,
  x_floor=min(x),
  x_ceil=max(x),
  force_x_inside_bounds=TRUE,
  i=NULL,
  ilim=NULL,
  include_iterations=NULL,
  cols=NULL,
  lwd=1, lty=1){
  
  # Set i_start.
  i_start = NULL
  if(length(ilim) == 2 && is.numeric(ilim[1])){
    i_start = ilim[1]
  }else if(!is.null(i)){
    i_start = min(i)
  }
  
  # Set i_end.
  i_end = NULL
  if(length(ilim) == 2 && is.numeric(ilim[2])){
    i_end = ilim[2]
  }else if(!is.null(i)){
    i_end = max(i)
  }
  
  # Init group data tracker.
  x_group = c()
  i_group = c()
  y_group = c()
  
  x_previous = NULL
  group_count = 1
  index = 1
  
  for(i_current in i){
    
    
    
    if(i_current >= i_start && i_current <= i_end){
      
      # Get current x value.
      x_current = c(x[index])
      
      # Check if x boundaries need to be enforced.
      # If they do, change x value so that it fits.
      if(isTRUE(force_x_inside_bounds)){
        
        # Handle x values that are less than x_floor.
        if(x_current < x_floor){
          x_current = x_current + x_ceil
          
          # Handle x values that are greater than x_ceil
        }else if(x_current > x_ceil){
          x_current = x_current - x_ceil
        }
      }
      
      if(isTRUE(force_x_inside_bounds) || 
         (force_x_inside_bounds == FALSE && (x_current >= x_floor || x_current <= x_ceil))){
   
        # New group, gone from x=x_ceil-ish to x=x_floor.-ish.
        if(is.null(x_previous) || x_current < x_previous){
          
          if(!is.null(x_group)){
            if(is.null(include_iterations) || group_count %in% include_iterations){
              
              lines(x_group, y_group, type = "l",
                    col= if(is.null(cols)) "black" else cols[group_count-1],
                    lwd=lwd, lty=ifelse(is.null(lty), group_count-1, lty))
              
            }
          }
          
          # Start new plot data sequences
          x_group = c(x_current)
          i_group = c(i[index])
          y_group = c(y[index])
          
          group_count = group_count + 1
          
        }else{
          # Still in the same group.
          x_group = c(x_group, x_current)
          i_group = c(i_group, i[index])
          y_group = c(y_group, y[index])
        }
        
        x_previous = x_current
        index = index + 1

      }
    }
  }
  
  # Plot the remaining data.
  if(!is.null(x_group)){
    if(is.null(include_iterations) || group_count %in% include_iterations){
      
      lines(x_group, y_group, type = "l",
            col= if(is.null(cols)) "black" else cols[group_count-1],
            lwd=lwd, lty=ifelse(is.null(lty), group_count-1, lty))
    }
  }
}

