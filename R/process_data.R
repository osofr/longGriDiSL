is.integerish <- function (x) {
  is.integer(x[!is.na(x)]) ||
  (is.numeric(x[!is.na(x)]) && all(x[!is.na(x)] == as.integer(x[!is.na(x)]))) ||
  (is.character(x[!is.na(x)]) && x[!is.na(x)] == as.integer(x[!is.na(x)]))
}

is.numericish <- function (x) {
  is.numeric(x[!is.na(x)]) ||
  (is.character(x[!is.na(x)]) && x[!is.na(x)] == as.numeric(x[!is.na(x)]))
}

convert_from_obscure <- function(data, check_type_f, want_type_f, make_type_f) {
  ## these columns are really integers/numerics, but were coded as either numeric or characters
  update_cols_idx <- unlist(lapply(data, check_type_f))
  update_cols <- update_cols_idx[(update_cols_idx & !(unlist(lapply(data, want_type_f)))) %in% TRUE]
  update_cols <- names(update_cols)
  if (length(update_cols) > 0) {
    cat("\nchanging the character type to something that is more acceptible for Machine Learning for following columns:", paste(update_cols, collapse=","),"\n")
    # data <- to_int(data, update_cols)
    data <- make_type_f(data, update_cols)
  }
}

# as.numeric <- function(data, vars, ...) { UseMethod("as.numeric") }
# as.integer <- function(data, vars, ...) { UseMethod("as.integer") }

#' Convert specific columns in \code{vars} to numeric
#'
#' @param data Input dataset, as \code{data.table}.
#' @param vars Column name(s) that should be converted to numeric type.
#' @export
# as.numeric.data.table <- function(data, vars) {
as.int <- function(data, vars) {
  for (var in vars)
    data[, (var) := as.numeric(get(var))]
  return(data)
}

#' Convert specific columns in \code{vars} to integers
#'
#' @param data Input dataset, as \code{data.table}.
#' @param vars Column name(s) that should be converted to numeric type.
#' @export
# as.integer.data.table <- function(data, vars) {
as.num <- function(data, vars) {
  for (var in vars)
    data[, (var) := as.integer(get(var))]
  return(data)
}

#' Wrapper for several data processing functions.
#'
#' Clean up the input data by dropping observations with missing outcomes \code{OUTCOME},
#' convert desired columns into numerics (\code{vars_to_numeric}),
#' convert all logical columns into binary integers
#' convert all character columns into factors
#' convert all factors into integers,
#' by defining additional dummy variables for every factor with > 2 levels.
#'
#' @param data Input dataset, can be a \code{data.frame} or a \code{data.table}.
#' @param OUTCOME Character name of the column of outcomes.
#' @param vars_to_numeric Column name(s) that should be converted to numeric type.
#' @param vars_to_int Column name(s) that should be converted to integer type.
#' @param skip_vars These columns will not be converted into other types
#' @export
prepare_data <- function(data, OUTCOME, vars_to_numeric, vars_to_int, skip_vars) {
  data <- data.table::data.table(data)
  data <- drop_NA_y(data, OUTCOME)

  if (!missing(vars_to_numeric)){
    browser()
    data <- as.num(data, vars_to_numeric)
  }
  if (!missing(vars_to_int)){
    data <- as.int(data, vars_to_int)
  }

  data <- convert_from_obscure(data, is.integerish, is.integer, as.int)
  data <- convert_from_obscure(data, is.numericish, is.numeric, as.num)
  data <- logical_to_int(data, skip_vars)
  data <- char_to_factor(data, skip_vars)
  data <- factor_to_dummy(data, skip_vars)

  cat("\ndefined the following new dummy columns:\n")
  print(unlist(attributes(data)$new.factor.names))

# browser()

  return(data)
}


#' Drop all observation rows with missing outcomes
#'
#' @param data Input dataset, as \code{data.table}.
#' @param OUTCOME Character name of the column of outcomes.
#' @export
drop_NA_y <- function(data, OUTCOME) data[!is.na(data[[OUTCOME]]),]



## generic function for converting from one column type to another
fromtype_totype <- function(data, fromtypefun, totypefun, skip_vars) {
  assert_that(data.table::is.data.table(data))
  # Convert all logical vars to binary integers
  vars <- unlist(lapply(data, fromtypefun))
  vars <- names(vars)[vars]
  if (!missing(skip_vars) && length(vars) > 0) {
    assert_that(is.character(skip_vars))
    vars <- vars[!(vars %in% skip_vars)]
  }
  for (varnm in vars) {
    data[,(varnm) := totypefun(get(varnm))]
  }
  return(data)
}

#' Convert logical covariates to integers
#' @param data Input dataset, as \code{data.table}.
#' @param skip_vars These columns will not be converted to integer
#' @export
logical_to_int <- function(data, skip_vars) fromtype_totype(data, is.logical, as.integer, skip_vars)

#' Convert all character columns to factors
#'
#' @param data Input dataset, as \code{data.table}.
#' @param skip_vars These columns will not be converted to factor
#' @export
char_to_factor <- function(data, skip_vars) fromtype_totype(data, is.character, as.factor, skip_vars)

#' Convert factors to binary indicators, for factors with > 2 levels drop the first factor level and define several dummy variables for the rest of the levels
#' @param data Input dataset, as \code{data.table}.
#' @param skip_vars These columns will not be converted
#' @export
factor_to_dummy <- function(data, skip_vars) {
  verbose <- gvars$verbose

  # Create dummies for each factor in the data
  factor.Ls <- as.character(CheckExistFactors(data))
  if (!missing(skip_vars) && length(factor.Ls) > 0) {
    assert_that(is.character(skip_vars))
    factor.Ls <- factor.Ls[!(factor.Ls %in% skip_vars)]
  }

  new.factor.names <- vector(mode="list", length=length(factor.Ls))
  names(new.factor.names) <- factor.Ls
  if (length(factor.Ls)>0 && verbose)
    message("...converting the following factor(s) to binary dummies (and droping the first factor levels): " %+% paste0(factor.Ls, collapse=","))
  for (factor.varnm in factor.Ls) {
    factor.levs <- levels(data[[factor.varnm]])

    ## only define new dummies for factors with > 2 levels
    if (length(factor.levs) > 2) {
      factor.levs <- factor.levs[-1] # remove the first level (reference class)
      factor.levs.code <- seq_along(factor.levs)
      # use levels to define cat indicators:
      data[,(factor.varnm %+% "_" %+% factor.levs.code) := lapply(factor.levs, function(x) as.integer(levels(get(factor.varnm))[get(factor.varnm)] %in% x))]
      # to remove the original factor var: # data[,(factor.varnm):=NULL]
      new.factor.names[[factor.varnm]] <- factor.varnm %+% "_" %+% factor.levs.code

    ## Convert existing factor variable to integer
    } else {
      data[, (factor.varnm) := as.integer(levels(get(factor.varnm))[get(factor.varnm)] %in% factor.levs[2])]
      # new.factor.names[[factor.varnm]] <- factor.varnm
      new.factor.names[[factor.varnm]] <- NULL
    }
  }
  data.table::setattr(data,"new.factor.names",new.factor.names)
  return(data)
}