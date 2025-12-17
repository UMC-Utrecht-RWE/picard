# Private environment to hold the internal registry env
.feature_plotters <- new.env(parent = emptyenv())

#' Register a feature plotter
#' @param name Unique plotter name (e.g., "dist")
#' @param fun  Function with signature function(dt, opts) -> named list of
#'             ggplot objects (one per column)
#' @importFrom stats density
#' @return Invisibly returns TRUE
#' @export
register_feature_plotter <- function(name, fun) {
  stopifnot(is.character(name), length(name) == 1, is.function(fun))
  .feature_plotters[[name]] <- fun
  invisible(TRUE)
}

#' Get a registered feature plotter
#' @param name Plotter name
#' @return The registered function or NULL
#' @export
get_feature_plotter <- function(name) {
  .feature_plotters[[name]]
}

# sanitize output path and ensure directory exists
.path_pngs <- function(plot_path, file_name, suffix) {
  if (!base::dir.exists(plot_path)) {
    base::dir.create(plot_path, recursive = TRUE)
  }
  file.path(plot_path, paste0(file_name, "_features_", suffix, ".png"))
}

# infer column classes into buckets we care about
.col_buckets <- function(dt, cols = NULL) {
  if (!is.null(cols)) {
    dt <- dt[, cols, with = FALSE]
  }
  cls <- base::vapply(dt, function(x) class(x)[1], character(1))
  list(
    numeric = names(cls)[cls %in% c("numeric", "integer")],
    logical = names(cls)[cls %in% c("logical")],
    date    = names(cls)[cls %in% c("Date", "POSIXct", "POSIXt")],
    factor  = names(cls)[cls %in% c("factor")],
    char    = names(cls)[cls %in% c("character")]
  )
}

# limit factor/character levels to top-N + "Other"
.top_n_factor <- function(x, n) {
  x <- as.character(x)
  tab <- sort(table(x, useNA = "no"), decreasing = TRUE)
  keep <- names(tab)[seq_len(min(n, length(tab)))]
  y <- ifelse(x %in% keep, x, "Other")
  factor(y, levels = c(keep, "Other"))
}

# calculate summary statistics for annotation
.summary_stats <- function(x) {
  if (is.numeric(x)) {
    paste0(
      "n=", length(x),
      " | NA=", sum(is.na(x)),
      " | mean=", round(mean(x, na.rm = TRUE), 2),
      " | median=", round(stats::median(x, na.rm = TRUE), 2)
    )
  } else {
    paste0(
      "n=", length(x),
      " | NA=", sum(is.na(x)),
      " | unique=", length(unique(x[!is.na(x)]))
    )
  }
}

# default options
.default_opts <- function(...) {
  dots <- list(...)
  modify <- function(x, y) {
    for (nm in names(y)) x[[nm]] <- y[[nm]]
    x
  }
  modify(list(
    ncol = 3,
    nrow = 3,
    width = 12,
    height = 9,
    max_levels = 15,
    sample_n = 0,
    seed = NA_integer_,
    title_prefix = "Features",
    theme = ggplot2::theme_minimal(base_size = 11),
    show_stats = TRUE, # show summary statistics
    cols = NULL # column selection
  ), dots)
}

# built-in "dist" plotter with FIXED histogram/density issue
.dist_plotter <- function(dt, opts) {
  buckets <- .col_buckets(dt, cols = opts$cols)
  plots <- list()

  # optional sampling
  dts <- dt
  if (is.numeric(opts$sample_n) && opts$sample_n > 0) {
    if (!is.na(opts$seed)) base::set.seed(opts$seed)
    idx <- base::sample.int(
      n = nrow(dts),
      size = min(opts$sample_n, nrow(dts))
    )
    dts <- dts[idx]
  }

  # numeric - FIXED: use density scale for histogram
  for (nm in buckets$numeric) {
    p <- ggplot2::ggplot(dts, ggplot2::aes(x = .data[[nm]])) + #nolint
      ggplot2::geom_histogram(
        ggplot2::aes(y = ggplot2::after_stat(density)),
        bins = 30,
        na.rm = TRUE,
        alpha = 0.6,
        fill = "steelblue"
      ) +
      ggplot2::geom_density(
        na.rm = TRUE,
        color = "darkblue",
        linewidth = 1
      ) +
      ggplot2::labs(
        title = paste0(nm, " (numeric)"),
        x = nm,
        y = "Density"
      ) +
      opts$theme

    if (opts$show_stats) {
      p <- p + ggplot2::labs(subtitle = .summary_stats(dts[[nm]]))
    }

    plots[[nm]] <- p
  }

  # logical
  for (nm in buckets$logical) {
    p <- ggplot2::ggplot(dts, ggplot2::aes(x = as.factor(.data[[nm]]))) + #nolint
      ggplot2::geom_bar(na.rm = TRUE, fill = "steelblue") +
      ggplot2::labs(
        title = paste0(nm, " (logical)"),
        x = nm,
        y = "Count"
      ) +
      opts$theme

    if (opts$show_stats) {
      p <- p + ggplot2::labs(subtitle = .summary_stats(dts[[nm]]))
    }

    plots[[nm]] <- p
  }

  # date
  for (nm in buckets$date) {
    p <- ggplot2::ggplot(dts, ggplot2::aes(x = as.Date(.data[[nm]]))) + #nolint
      ggplot2::geom_histogram(
        na.rm = TRUE,
        bins = 30,
        fill = "steelblue"
      ) +
      ggplot2::labs(
        title = paste0(nm, " (date)"),
        x = nm,
        y = "Count"
      ) +
      ggplot2::scale_x_date(date_labels = "%Y-%m-%d") +
      opts$theme

    if (opts$show_stats) {
      p <- p + ggplot2::labs(subtitle = .summary_stats(dts[[nm]]))
    }

    plots[[nm]] <- p
  }

  # factor
  for (nm in buckets$factor) {
    p <- ggplot2::ggplot(dts, ggplot2::aes(x = .data[[nm]])) + #nolint
      ggplot2::geom_bar(na.rm = TRUE, fill = "steelblue") +
      ggplot2::labs(
        title = paste0(nm, " (factor)"),
        x = nm,
        y = "Count"
      ) +
      opts$theme +
      ggplot2::theme(
        axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, vjust = 1)
      )

    if (opts$show_stats) {
      p <- p + ggplot2::labs(subtitle = .summary_stats(dts[[nm]]))
    }

    plots[[nm]] <- p
  }

  # character
  for (nm in buckets$char) {
    fac <- .top_n_factor(dts[[nm]], n = opts$max_levels)
    p <- ggplot2::ggplot(data.frame(x = fac), ggplot2::aes(x = x)) + #nolint
      ggplot2::geom_bar(na.rm = TRUE, fill = "steelblue") +
      ggplot2::labs(
        title = paste0(nm, " (char)"),
        x = nm,
        y = "Count"
      ) +
      opts$theme +
      ggplot2::theme(
        axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, vjust = 1)
      )

    if (opts$show_stats) {
      p <- p + ggplot2::labs(subtitle = .summary_stats(dts[[nm]]))
    }

    plots[[nm]] <- p
  }

  plots
}

# NEW: Missing data plotter
.missing_plotter <- function(dt, opts) {
  buckets <- .col_buckets(dt, cols = opts$cols)
  all_cols <- unlist(buckets, use.names = FALSE)

  if (length(all_cols) == 0) {
    return(list())
  }

  # Calculate missing percentages
  missing_pct <- sapply(dt[, all_cols, with = FALSE], function(x) {
    sum(is.na(x)) / length(x) * 100
  })

  # Create a data frame for plotting
  missing_df <- data.frame(
    column = factor(names(missing_pct), levels = names(missing_pct)),
    pct_missing = missing_pct
  )

  p <- ggplot2::ggplot(missing_df, ggplot2::aes(x = column, y = pct_missing)) + #nolint
    ggplot2::geom_col(
      fill = ifelse(
        missing_df$pct_missing > 50, "darkred",
        ifelse(missing_df$pct_missing > 10, "orange", "steelblue")
      )
    ) +
    ggplot2::geom_hline(
      yintercept = 10, linetype = "dashed", color = "orange"
    ) +
    ggplot2::geom_hline(
      yintercept = 50, linetype = "dashed", color = "darkred"
    ) +
    ggplot2::labs(
      title = "Missing Data Analysis",
      subtitle = "Red: >50% missing | Orange: >10% missing",
      x = "Column",
      y = "% Missing"
    ) +
    opts$theme +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, vjust = 1)
    )

  list(missing_data = p)
}

# NEW: Box plot for outlier detection
.boxplot_plotter <- function(dt, opts) {
  buckets <- .col_buckets(dt, cols = opts$cols)
  plots <- list()

  # Only numeric columns
  for (nm in buckets$numeric) {
    p <- ggplot2::ggplot(dt, ggplot2::aes(y = .data[[nm]])) + #nolint
      ggplot2::geom_boxplot(
        fill = "steelblue",
        outlier.color = "red",
        na.rm = TRUE
      ) +
      ggplot2::labs(
        title = paste0(nm, " - Outlier Detection"),
        y = nm
      ) +
      opts$theme

    if (opts$show_stats) {
      p <- p + ggplot2::labs(subtitle = .summary_stats(dt[[nm]]))
    }

    plots[[nm]] <- p
  }

  plots
}

# Initialize plotter registry
.init_plotter_registry <- function() {
  rm(list = ls(envir = .feature_plotters), envir = .feature_plotters)

  register_feature_plotter("dist", .dist_plotter)
  register_feature_plotter("missing", .missing_plotter)
  register_feature_plotter("boxplot", .boxplot_plotter)
}

#' Create feature analysis plots for data inspection
#'
#' @param data A data.table to visualize
#' @param file_name Name of the data file (used for plot titles)
#' @param plot_path Optional path to save the plots.
#' Default "data/D6_report"
#' @param exclude_columns_from_plots Optional character vector of column
#' names to exclude from plots.
#' Default: c("person_id", "pregnancy_id", "unique_id")
#' Default will try to exclude this columns if present to avoid privacy issues.
#' If NULL, no columns will be excluded.
#' @param chart_types Vector of chart types: "dist", "missing", "boxplot"
#' @param cols Optional vector of column names to plot (NULL = all columns)
#' @param show_stats Show summary statistics on plots (default: TRUE)
#' @param ... Additional arguments passed to plotters
#' @return Invisibly returns vector of saved file paths
#' @export
plot_data_features <- function(
    data,
    file_name = NULL,
    plot_path = "data/intermediate_plots",
    exclude_columns_from_plots = c(
      "person_id", "pregnancy_id", "unique_id"
    ),
    chart_types = c("dist"),
    cols = NULL,
    show_stats = TRUE,
    ...) {
  if (is.null(file_name)) {
    file_name <- "plot_examples"
  }
  stopifnot(is.character(file_name), length(file_name) == 1)

  plot_path <- fs::path_norm(plot_path)
  if (!base::dir.exists(plot_path)) {
    base::dir.create(plot_path, recursive = TRUE, showWarnings = FALSE)
    logger::log_info(base::paste("Created directory:", plot_path))
  }

  opts <- .default_opts(cols = cols, show_stats = show_stats, ...)
  saved <- character(0)
  if (!is.null(exclude_columns_from_plots)) {
    # remove one column at a time if exists
    existing_cols <- intersect(
      exclude_columns_from_plots, colnames(data)
    )
    if (length(existing_cols) == 0) {
      logger::log_warn(
        "No columns found to be excluded from plots."
      )
    }
    data[, (existing_cols) := NULL]

    logger::log_info(
      paste0(
        "Excluding columns from plots: ",
        paste(existing_cols, collapse = ", ")
      )
    )
  }

  for (ctype in chart_types) {
    plotter <- get_feature_plotter(ctype)
    if (is.null(plotter)) {
      logger::log_warn(paste0("Unknown chart type: ", ctype))
      next
    }

    logger::log_info(paste0("Building plots for type '", ctype, "'"))
    plt_list <- plotter(data, opts)

    if (length(plt_list) == 0) {
      logger::log_warn(paste0("No plots produced for '", ctype, "'"))
      next
    }

    per_page <- opts$ncol * opts$nrow
    pages <- split(
      seq_along(plt_list), ceiling(seq_along(plt_list) / per_page)
    )

    pg_idx <- 1
    for (idx in pages) {
      page_plots <- plt_list[idx]
      bullet <- "\u2022"
      title <- paste0(
        opts$title_prefix, " ", bullet, " ", ctype,
        " ", bullet, " page ", pg_idx, "/", length(pages)
      )
      wrap <- patchwork::wrap_plots(page_plots, ncol = opts$ncol) +
        patchwork::plot_annotation(title = title)

      out <- .path_pngs(plot_path, file_name, paste0(ctype, "_page", pg_idx))
      ggplot2::ggsave(
        filename = out,
        plot = wrap,
        width = opts$width,
        height = opts$height,
        units = "in",
        dpi = 150
      )
      logger::log_info(paste0("Saved: ", out))
      saved <- c(saved, out)
      pg_idx <- pg_idx + 1
    }
  }
  rm(data)
  invisible(saved)
}
