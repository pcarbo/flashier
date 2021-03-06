context("fitting tensors")

set.seed(666)

m <- 10
n <- 10
p <- 30

LF1 <- rep(1, m) %o% rep(1, n) %o% rep(1, p)
LF2 <- 5 * (rnorm(m) %o% rnorm(n) %o% rnorm(p))
LF <- LF1 + LF2
M <- LF + 0.1 * rnorm(m * n * p)

f <- flash(M, greedy.Kmax = 2, verbose.lvl = 0)

test_that("tensor factor initialization is correct", {
  expect_equal(f$n.factors, 2)
  expect_equal(lowrank.expand(get.EF(f$flash.fit)), LF1 + LF2, tol = 0.25, scale = 1)
})

f.b <- flash.backfit(f, method = "sequential", maxiter = 1, verbose.lvl = 0)

test_that ("the backfit objective improves after one iteration", {
  expect_true(f.b$elbo > f$elbo)
})

f.b2 <- flash.backfit(f, method = "sequential", verbose.lvl = 0)

test_that ("the final backfit objective improves again", {
  expect_true(f.b2$elbo > f.b$elbo)
})

missing <- sample(1:length(M), floor(0.1 * length(M)))
M.missing <- M
M.missing[missing] <- NA

f <- flash(M.missing, greedy.Kmax = 2, verbose.lvl = 0)

test_that("tensor factor initialization is correct (with missing)", {
  expect_equal(f$n.factors, 2)
  expect_equal(lowrank.expand(get.EF(f$flash.fit)), LF1 + LF2, tol = 0.25, scale = 1)
})

f.b <- flash.backfit(f, maxiter = 1, verbose.lvl = 0)

test_that ("the backfit objective improves after one iteration (using Y, with missing)", {
  expect_true(f.b$elbo > f$elbo)
})

f.b2 <- flash.backfit(f, verbose.lvl = 0)

test_that ("the final backfit objective improves again (with missing)", {
  expect_true(f.b2$elbo > f.b$elbo)
})
