#' Initialize flash factors at specified values
#'
#' Initializes factors at values specified by \code{EF} and \code{EF2}. This
#'   has two primary uses: 1. One can initialize multiple factors at once using
#'   an SVD-like function and then optimize them via \code{flash.backfit}.
#'   Sometimes this results in a better fit than adding factors one at a time
#'   via \code{flash.add.greedy}. 2. One can initialize factors and then fix
#'   the loadings via \code{\link{flash.fix.loadings}} to incorporate "known"
#'   factors into a flash object. See below for examples of both use cases.
#'
#' @inheritParams flash
#'
#' @param flash A \code{flash} or \code{flash.fit} object to which factors are
#'   to be added.
#'
#' @param EF An SVD-like object or a list of matrices, one for each mode. Each
#'   matrix should have k columns, one for each factor. For example, if the
#'   data is a matrix of size n x p, then factors can be initialized by
#'   supplying a list of length two, with the first element a matrix of size
#'   n x k and the second element a matrix of size p x k. Missing entries are
#'   not allowed.
#'
#' @param EF2 If NULL, then EF2 will be initialized at the element-wise squared
#'   values of \code{EF}. Otherwise, a list of matrices (as described above)
#'   must be supplied.
#'
#' @examples
#' library(magrittr)
#' 
#' # Initialize several factors at once and backfit.
#' fl <- flash.init(gtex) %>%
#'   flash.init.factors(EF = svd(gtex, nu = 5, nv = 5)) %>%
#'   flash.backfit()
#'
#' # Add a fixed factor with row loadings identically equal to one. This can be
#' # interpreted as a "mean" factor that accounts for different row-wise means.
#' ones <- matrix(1, nrow = nrow(gtex), ncol = 1)
#' 
#' # Initialize the column loadings at the least squares solution.
#' ls.soln <- t(solve(crossprod(ones), crossprod(ones, gtex)))
#' fl <- flash.init(gtex) %>%
#'   flash.init.factors(EF = list(ones, ls.soln)) %>%
#'   flash.fix.loadings(kset = 1, mode = 1L) %>%
#'   flash.backfit() %>%
#'   flash.add.greedy(Kmax = 5L)
#'
#' @export
#'
flash.init.factors <- function(flash,
                               EF,
                               EF2 = NULL,
                               prior.family = prior.point.normal()) {
  flash <- get.fit(flash)

  if (is.udv(EF)) {
    if (!is.null(EF2)) {
      stop("If EF and EF2 are both supplied, then both must be lists of ",
           "matrices.")
    }
    EF <- udv.to.lowrank(EF)
  } else if (is.list(EF) && all(sapply(EF, is.matrix))) {
    class(EF) <- list("lowrank", "list")
  } else {
    stop("EF must be an SVD-like object or list of matrices.")
  }
  dims.must.match(EF, get.Y(flash))

  if (is.null(EF2)) {
    EF2 <- lowrank.square(EF)
  } else if (is.list(EF2) && all(sapply(EF2, is.matrix))) {
    class(EF2) <- list("lowrank", "list")
    dims.must.match(EF2, get.Y(flash))
  } else {
    stop("If supplied, EF2 must be a list of matrices.")
  }

  if (anyNA(c(unlist(EF), unlist(EF2)))) {
    stop("Neither EF nor EF2 may have missing data.")
  }

  priors <- handle.prior.family(prior.family, get.dim(flash))

  flash <- set.EF(flash, lowranks.combine(get.EF(flash), EF))
  flash <- set.EF2(flash, lowranks.combine(get.EF2(flash), EF2))

  if (uses.R(flash)) {
    R <- get.Y(flash) - lowrank.expand(get.EF(flash))
    flash <- set.R(flash, get.nonmissing(flash) * R)
  }

  flash <- init.tau(flash)
  flash <- set.obj(flash, calc.obj(flash))

  K <- ncol(EF[[1]])

  # Initialize KL at zero and g at NULL.
  for (n in 1:get.dim(flash)) {
    flash <- set.KL(flash, c(get.KL(flash, n), rep(0, K)), n)
  }
  EF.g <- rep(list(rep(list(NULL), get.dim(flash))), K)
  flash <- set.g(flash, c(get.g(flash), EF.g))

  ebnm.fn <- c(get.ebnm.fn(flash), rep(priors$ebnm.fn, length.out = K))
  flash <- set.ebnm.fn(flash, ebnm.fn)

  # Initialize is.valid and is.zero.
  flash <- set.is.valid(flash, c(is.valid(flash), rep(FALSE, K)))
  flash <- set.is.zero(flash, c(is.zero(flash), rep(FALSE, K)))

  flash <- wrapup.flash(flash, output.lvl = 3L)

  return(flash)
}
