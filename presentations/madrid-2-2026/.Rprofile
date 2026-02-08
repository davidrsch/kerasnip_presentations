# Skip renv activation in CI to avoid ..md5.. errors
# The workflow sets R_LIBS_USER to the restored renv library path
if (Sys.getenv("CI") != "true") {
    source("renv/activate.R")
}
