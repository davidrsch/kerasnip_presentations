#!/usr/bin/env Rscript

# Identify presentation directories
# We look for folders under 'presentations/' that contain 'renv.lock'
pres_root <- "presentations"
if (!dir.exists(pres_root)) {
    stop("Directory 'presentations' not found.")
}

dirs <- list.dirs(pres_root, recursive = FALSE)
pres_dirs <- dirs[file.exists(file.path(dirs, "renv.lock"))]

if (length(pres_dirs) == 0) {
    message("No presentations with renv.lock found.")
    quit(save = "no")
}

message("Found presentations: ", paste(pres_dirs, collapse = ", "))

# Function to run command in a directory
run_in_dir <- function(cmd, args, dir) {
    message(sprintf("--> Running in %s: %s %s", dir, cmd, paste(args, collapse = " ")))
    old_wd <- setwd(dir)
    on.exit(setwd(old_wd))
    code <- system2(cmd, args, stdout = "", stderr = "")
    if (code != 0) {
        stop(sprintf("Command failed with exit code %d in %s", code, dir))
    }
}

for (dir in pres_dirs) {
    message(sprintf("\n=== Processing Presentation: %s ===", dir))

    # 1. Restore renv
    # We use Rscript -e "renv::restore()" inside the dir.
    # This relies on .Rprofile or default lib paths.
    # Note: In CI, we want to force restore.
    message("Restoring renv environment...")
    # We assume renv is bootstrapped by .Rprofile or available.
    # Using --vanilla might skip .Rprofile, so we don't use it here if we depend on renv/activate.R.
    # However, if .Rprofile fails (like the ..md5.. issue), we might need care.
    # But we fixed ..md5.. by installing system deps.

    # Check if renv/activate.R exists
    if (file.exists(file.path(dir, "renv", "activate.R"))) {
        # Run restore. We use 'make' style logic: restore if needed.
        # But for CI, just restore.
        run_in_dir("Rscript", c("--vanilla", "-e", "'if (!requireNamespace(\"renv\", quietly=TRUE)) install.packages(\"renv\", repos=\"https://cloud.r-project.org\"); renv::restore(prompt = FALSE)'"), dir)
    } else {
        warning(sprintf("No renv/activate.R in %s, skipping explicit restore (assuming environment is okay or handled elsewhere).", dir))
    }

    # 2. Set R_LIBS_USER to the renv library path so quarto's spawned R finds packages
    message("Configuring R_LIBS_USER for quarto...")
    # Get the library path from renv (using --vanilla to avoid .Rprofile issues)
    # We pass the absolute project path to ensure renv knows where the project is
    abs_dir <- normalizePath(dir, winslash = "/")
    lib_path_cmd <- system2(
        "Rscript",
        c("--vanilla", "-e", sprintf("'cat(renv::paths$library(project = \"%s\"))'", abs_dir)),
        stdout = TRUE, stderr = FALSE
    )
    lib_path <- paste(lib_path_cmd, collapse = "")
    if (nzchar(lib_path)) {
        message(sprintf("Setting R_LIBS_USER=%s", lib_path))
        Sys.setenv(R_LIBS_USER = lib_path)
    } else {
        warning("Could not determine renv library path, quarto may fail to find packages.")
    }

    # 3. Render profiles
    # We render both english and spanish.
    # If the presentation doesn't support profiles, this might just render twice (overwriting).
    # That's acceptable for now, or we could check for _quarto-*.yml or index.qmd content.
    # Assuming all presentations follow the repo structure.

    profiles <- c("english", "spanish")
    for (prof in profiles) {
        message(sprintf("Rendering profile: %s", prof))
        run_in_dir("quarto", c("render", ".", "--profile", prof), dir)
    }
}

message("\nAll presentations processed.")
