# Activate renv only if not in CI with pre-set library path
# In CI, R_LIBS_USER is set by the build script to point directly to the restored library
if (Sys.getenv("CI") != "true" || !nzchar(Sys.getenv("R_LIBS_USER"))) {
    source("renv/activate.R")
}
