% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/fit_main.R
\name{fit}
\alias{fit}
\alias{fit.ModelStack}
\title{Fit Discrete SuperLearner}
\usage{
fit(...)

\method{fit}{ModelStack}(models, method = c("none", "holdout", "cv",
  "origamiSL", "internalSL"), data, ID, t_name, x, y, nfolds = NULL,
  fold_column = NULL, hold_column = NULL, hold_random = FALSE,
  seed = NULL, refit = TRUE, fold_y_names = NULL,
  verbose = getOption("gridisl.verbose"), ...)
}
\arguments{
\item{...}{Additional arguments that will be passed on directly to \code{\link{fit_model}} function.}

\item{models}{Parameters specifying the model(s) to fit. This must be a result of calling \code{defModel(...) + defModel(...)} functions.
See \code{\link{defModel}} for additional information.}

\item{method}{The type of model selection and model stacking procedure when fitting more than one model.
Possible options are:
\code{"none"} -- no model selection;
\code{"holdout"} -- model selection based on a (possibly) random holdout validation sample;
\code{"cv"} -- discrete Super Learner, select a single best-performing model via internal V-fold cross-validation;
\code{"origamiSL"} -- convex (NNLS) Super Learner with external V-fold cross-validation (using \code{origami} R package);
\code{"internalSL"} -- convex (NNLS) Super Learner with internal V-fold cross-validation (same CV as in method="cv");}

\item{data}{Input dataset, can be a \code{data.frame} or a \code{data.table}.}

\item{ID}{A character string name of the column that contains the unique subject identifiers.}

\item{t_name}{A character string name of the column with integer-valued measurement time-points (in days, weeks, months, etc).}

\item{x}{A vector containing the names of predictor variables to use for modeling. If x is missing, then all columns except \code{ID}, \code{y} are used.}

\item{y}{A character string name of the column that represent the response variable in the model.}

\item{nfolds}{Number of folds to use in cross-validation.}

\item{fold_column}{The name of the column in the input data that contains the cross-validation fold indicators (must be an ordered factor).}

\item{hold_column}{The name of the column that contains the holdout observation indicators (TRUE/FALSE) in the input data.
This holdout column must be defined and added to the input data prior to calling this function.}

\item{hold_random}{Logical, specifying if the holdout observations should be selected at random.
If FALSE then the last observation for each subject is selected as a holdout.}

\item{seed}{Random number seed for selecting random holdouts or validation folds.}

\item{refit}{Set to \code{TRUE} (default) to refit the best estimator using the entire dataset.
When \code{FALSE}, it might be impossible to make predictions from this model fit.}

\item{fold_y_names}{(ADVANCED FEATURE) The names of columns in \code{data} containing the fold-specific outcomes.
Can be used for contructing split-specific (or by-fold) Super-Learner with \code{method}=\code{"origamiSL"}.}

\item{verbose}{Set to \code{TRUE} to print messages on status and information to the console. Turn this on by default using \code{options(gridisl.verbose=TRUE)}.}
}
\value{
An R6 object containing the model fit(s).
}
\description{
Define and fit discrete SuperLearner for longitudinal data.
Model selection (scoring) can be based on MSE evaluated for random holdout observations (method = "holdout")
or V-fold cross-validated MSE (method = "cv").
}
