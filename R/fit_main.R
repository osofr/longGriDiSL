#' S3 methods for printing a collection of learners
#'
#' Prints the stack models
#' @param modelstack An object (list) of class ModelStack
#' @param ... Additional options passed on to \code{print.PredictionModel}.
#' @export
print.ModelStack <- function(modelstack, ...) {
  str(modelstack)
  return(invisible(NULL))
}

# ---------------------------------------------------------------------------------------
# Define modeling algorithm(s), package and parameters
# @param estimator A character string name of package and estimator (algorithm) name, separated by "__".
# @param ... Additional modeling parameters to be passed to modeling function.
#' @rdname defGrid
#' @export
defLearner <- function(estimator, x, ...) {
  pkg_est <- strsplit(estimator, "__", fixed = TRUE)[[1]]
  pkg <- pkg_est[1]
  if (length(pkg_est) > 1) est <- pkg_est[2] else est <- NULL
  learner <- defGrid(estimator, x, ...)

  if (!(pkg %in% c("h2o", "xgboost"))) {
    learner[[1]][["fit.algorithm"]] <- learner[[1]][["grid.algorithm"]]
    learner[[1]][["grid.algorithm"]] <- NULL
  }
  return(learner)
}

# ---------------------------------------------------------------------------------------
#' Interface for defining models
#'
#' Use \code{defLearner} to define a single model and \code{defGrid} to define a grid of multple models.
#' @param estimator A character string name of package and estimator (algorithm) name, separated by "__".
#' @param x A vector containing the subset of the names of the predictor variables to use in building this
#' particular learner or grid. This argument can be used to over-ride the values of \code{x} provided to \code{fit} function.
#' As such, the names supplied here must always be a subset of the names specified to \code{fit}.
#' When this argument is missing (default) the column names provided to \code{fit} are used as predictors in building this model / grid.
#' @param search_criteria Search criteria
#' @param param_grid Grid of modeling parameters
#' @param ... Additional modeling parameters to be passed on directly to the modeling function.
#' @export
defGrid <- function(estimator, x, search_criteria, param_grid, ...) {
  pkg_est <- strsplit(estimator, "__", fixed = TRUE)[[1]]
  pkg <- pkg_est[1]
  if (length(pkg_est) > 1) est <- pkg_est[2] else est <- NULL

  ## call outside fun that parses ... and checks all args are named
  sVar.exprs <- capture.exprs(...)

  GRIDparams = list(fit.package = pkg, fit.algorithm = "grid", grid.algorithm = est)
  if (!missing(x)) GRIDparams[["x"]] <- x
  if (!missing(search_criteria)) GRIDparams[["search_criteria"]] <- search_criteria
  if (!missing(param_grid)) GRIDparams[["params"]] <- param_grid

  # grid.algorithm = c("glm", "gbm")
  # glm = glm_hyper_params, gbm = gbm_hyper_params,
  # family = "gaussian",
  # learner = "h2o.glm.reg03",
  # stopping_rounds = 5, stopping_tolerance = 1e-4, stopping_metric = "MSE", score_tree_interval = 10)

  if (length(sVar.exprs) > 0) GRIDparams <- c(GRIDparams, sVar.exprs)
  GRIDparams <- list(GRIDparams)
  class(GRIDparams) <- c(class(GRIDparams), "ModelStack")
  return(GRIDparams)
}

# S3 method '+' for adding two ModelStack objects
# Summary measure lists in both get added as c(,) into the summary measures in sVar1 object
#' @rdname defGrid
#' @param learner1 An object returned by a call to \code{defLearner} or \code{defGrid} functions.
#' @param learner2 An object returned by a call to \code{defLearner} or \code{defGrid} functions.
#' @export
`+.ModelStack` <- function(learner1, learner2) {
  assert_that(is.ModelStack(learner1))
  assert_that(is.ModelStack(learner2))
  newStack <- append(learner1, learner2)
  class(newStack) <- c(class(newStack), "ModelStack")
  return(newStack)
}

#' @rdname fit.ModelStack
#' @export
fit <- function(...) { UseMethod("fit") }

# ---------------------------------------------------------------------------------------
#' Discrete SuperLearner with one-out holdout validation
#'
#' Define and fit discrete SuperLearner for growth curve modeling.
#' Model selection (scoring) is based on MSE for a single random (or last) holdout data-point for each subject.
#' This is in contrast to the model selection with V-fold cross-validated MSE in \code{\link{fit_cvSL}},
#' which leaves the entire subjects (entire growth curves) outside of the training sample.
#' @param models ...
#' @param method The type of model selection procedure when fitting several models at once. Possible options are "none", "cv", and "holdout".
#' @param data Input dataset, can be a \code{data.frame} or a \code{data.table}.
#' @param ID A character string name of the column that contains the unique subject identifiers.
#' @param t_name A character string name of the column with integer-valued measurement time-points (in days, weeks, months, etc).
#' @param x A vector containing the names of predictor variables to use for modeling. If x is missing, then all columns except \code{ID}, \code{y} are used.
#' @param y A character string name of the column that represent the response variable in the model.
#' @param params Parameters specifying the type of modeling procedure to be used.
#' @param nfolds Number of folds to use in cross-validation.
#' @param fold_column The name of the column in the input data that contains the cross-validation fold indicators (must be an ordered factor).
#' @param hold_column The name of the column that contains the holdout observation indicators (TRUE/FALSE) in the input data.
#' This holdout column must be defined and added to the input data prior to calling this function.
#' @param hold_random Logical, specifying if the holdout observations should be selected at random.
#' If FALSE then the last observation for each subject is selected as a holdout.
#' @param seed Random number seed for selecting a random holdout.
#' @param refit Set to \code{TRUE} (default) to refit the best estimator using the entire dataset.
#' When \code{FALSE}, it might be impossible to make predictions from this model fit.
#' @param verbose Set to \code{TRUE} to print messages on status and information to the console. Turn this on by default using \code{options(GriDiSL.verbose=TRUE)}.
#' @param ... Additional arguments that will be passed on to \code{fit_model} function.
#' @return ...
# @seealso \code{\link{GriDiSL-package}} for the general overview of the package,
# @example tests/examples/1_GriDiSL_example.R
#' @export
fit.ModelStack <- function(models, method = c("none", "cv", "holdout"), data, ID, t_name, x, y,
                           nfolds = NULL, fold_column = NULL,
                           hold_column = NULL, hold_random = FALSE, seed = NULL, refit = TRUE,
                           verbose = getOption("GriDiSL.verbose"), ...) {
  method <- method[1L]

  gvars$verbose <- verbose
  if (!is.ModelStack(models)) stop("argument models must be of class 'ModelStack'")
  if (!(method %in% c("none", "cv", "holdout"))) stop("argument method must be one of: 'none', 'cv', 'holdout'")
  if (!data.table::is.data.table(data) && !is.DataStorageClass(data))
    stop("argument data must be of class 'data.table, please convert the existing data.frame to data.table by calling 'data.table::as.data.table(...)'")
  if (missing(ID)) ID <- names(data)[1]
  if (missing(t_name)) t_name <- names(data)[2]
  if (missing(y)) y <- names(data)[3]
  if (missing(x)) x <- names(data)[4:ncol(data)]
  nodes <- list(Lnodes = x, Ynode = y, IDnode = ID, tnode = t_name)
  orig_colnames <- colnames(data)

  if (method %in% "none") {
    ## Fit models based on all available data
    modelfit <- fit_model(ID, t_name, x, y, data, models = models, verbose = verbose, ...)
  } else if (method %in% "cv") {
    modelfit <- fit_cvSL(ID, t_name, x, y, data, models = models, nfolds = nfolds, fold_column = fold_column, refit = refit, seed = seed, verbose = verbose, ...)
  } else if (method %in% "holdout") {
    modelfit <- fit_holdoutSL(ID, t_name, x, y, data, models = models, hold_column = hold_column, hold_random = hold_random, refit = refit, seed = seed, verbose = verbose, ...)
  }

  return(modelfit)
}
