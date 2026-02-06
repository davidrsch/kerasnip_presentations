args <- commandArgs(trailingOnly = TRUE)
root <- if (length(args) >= 1) args[[1]] else "."

if (!requireNamespace("pak", quietly = TRUE)) {
  install.packages("pak", repos = "https://cloud.r-project.org")
}

pak_files <- list.files(
  root,
  pattern = "^pak\\.txt$",
  recursive = TRUE,
  full.names = TRUE
)

if (length(pak_files) == 0) {
  message("No pak.txt files found; skipping dependency install.")
  quit(status = 0)
}

specs <- unlist(lapply(pak_files, function(path) {
  lines <- readLines(path, warn = FALSE)
  lines <- trimws(lines)
  lines <- lines[lines != "" & !startsWith(lines, "#")]
  if (length(lines) > 0) {
    message("Found ", length(lines), " deps in ", path)
  }
  lines
}), use.names = FALSE)

specs <- unique(specs)

if (length(specs) == 0) {
  message("pak.txt files found, but no dependencies listed.")
  quit(status = 0)
}

message("Installing ", length(specs), " unique dependencies via pak...")
pak::pkg_install(specs)
