# This runs ONCE after all tests are completed

plot_dir <- testthat::test_path("data", "intermediate_plots")

leftover_files <- fs::dir_ls(plot_dir, fail = FALSE, type = "file")
# file data/intermediate_plots/plot_examples_features_dist_page1.png
# is not deleted during the test phase, I cannot find the reason why.
# Forcing its deletion here, I'll remove following if I do.
if (length(leftover_files) > 0) {
  fs::file_delete(leftover_files)
}
