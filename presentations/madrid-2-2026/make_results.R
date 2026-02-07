# presentations/madrid-2-2026/make_results.R
#
# Purpose:
# - Run tuning once
# - Save cached results to presentations/madrid-2-2026/results/*.rds
# - Produce deterministic artifacts shared by EN/ES renders
#
# Usage:
# - From kerasnip_presentations/:        Rscript presentations/madrid-2-2026/make_results.R
# - From presentations/madrid-2-2026/:   Rscript make_results.R

script_path <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- sub("^--file=", "", script_path)

script_dir <- if (length(script_path) == 1) {
    dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))
} else {
    normalizePath(getwd(), winslash = "/", mustWork = FALSE)
}

results_dir <- file.path(script_dir, "results")
dir.create(results_dir, showWarnings = FALSE, recursive = TRUE)

message(
    "Writing results to: ",
    normalizePath(results_dir, winslash = "/", mustWork = FALSE)
)

safe_run <- function(label, fn) {
    message("\n--- ", label, " ---")
    tryCatch(
        fn(),
        error = function(e) {
            message("[WARN] ", label, " failed: ", conditionMessage(e))
            invisible(NULL)
        }
    )
}

safe_run("Diamonds regression (sequential)", function() {
    suppressPackageStartupMessages({
        library(tidymodels)
        library(kerasnip)
        library(keras3)
    })

    set.seed(20260203)
    data(diamonds, package = "ggplot2")

    diamonds_res_path <- file.path(results_dir, "diamonds_res.rds")
    diamonds_final_path <- file.path(results_dir, "diamonds_final.rds")

    input_block <- function(model, input_shape) {
        keras_model_sequential(input_shape = input_shape)
    }

    dense_block <- function(model, units = 128, dropout = 0.0) {
        model |>
            layer_dense(units = units, activation = "relu") |>
            layer_dropout(rate = dropout)
    }

    output_block <- function(model) {
        model |> layer_dense(units = 1)
    }

    create_keras_sequential_spec(
        model_name = "diamond_mlp",
        layer_blocks = list(
            input = input_block,
            body = dense_block,
            output = output_block
        ),
        mode = "regression"
    )

    split <- initial_split(diamonds, strata = price)
    train <- training(split)

    rec <- recipe(price ~ ., data = train) |>
        step_dummy(all_nominal_predictors()) |>
        step_zv(all_predictors()) |>
        step_normalize(all_numeric_predictors())

    spec <- diamond_mlp(
        num_body = tune(),
        body_units = tune(),
        body_dropout = tune(),
        fit_epochs = 5
    ) |>
        set_engine("keras")

    wf <- workflow() |>
        add_recipe(rec) |>
        add_model(spec)

    params <- extract_parameter_set_dials(wf) |>
        update(
            num_body = dials::num_terms(c(1, 3)),
            body_units = dials::hidden_units(c(32, 128)),
            body_dropout = dials::dropout(c(0, 0.3))
        )

    grid <- grid_latin_hypercube(params, size = 8)
    folds <- vfold_cv(train, v = 3, strata = price)
    ctrl <- control_grid(save_pred = FALSE)

    if (file.exists(diamonds_res_path)) {
        res <- readRDS(diamonds_res_path)
        message("Reusing: diamonds_res.rds")
    } else {
        res <- tune_grid(wf, resamples = folds, grid = grid, control = ctrl)
        saveRDS(res, diamonds_res_path)
        message("Saved: diamonds_res.rds")
    }

    if (file.exists(diamonds_final_path)) {
        message("Reusing: diamonds_final.rds")
    } else {
        best <- select_best(res, metric = "rmse")
        final_wf <- finalize_workflow(wf, best)
        lf <- last_fit(
            final_wf,
            split = split,
            metrics = metric_set(rmse, mae, rsq)
        )

        diamonds_final <- list(
            best = best,
            metrics = collect_metrics(lf),
            preds = collect_predictions(lf)
        )
        saveRDS(diamonds_final, diamonds_final_path)
        message("Saved: diamonds_final.rds")
    }
})

safe_run("Attrition classification (functional)", function() {
    suppressPackageStartupMessages({
        library(tidymodels)
        library(modeldata)
        library(kerasnip)
        library(keras3)
    })

    set.seed(20260203)
    data(attrition)

    attrition_res_path <- file.path(results_dir, "attrition_res.rds")
    attrition_final_path <- file.path(results_dir, "attrition_final.rds")

    input_block <- function(input_shape) {
        layer_input(shape = input_shape, name = "features")
    }

    dense_block <- function(tensor, units = 64, dropout = 0.0) {
        tensor |>
            layer_dense(units = units, activation = "relu") |>
            layer_dropout(rate = dropout)
    }

    concat_block <- function(input_a, input_b) {
        layer_concatenate(list(input_a, input_b))
    }

    output_block <- function(tensor, num_classes) {
        tensor |> layer_dense(units = num_classes, activation = "softmax")
    }

    create_keras_functional_spec(
        model_name = "attrition_towers",
        layer_blocks = list(
            main_input = input_block,
            tower_a = inp_spec(dense_block, "main_input"),
            tower_b = inp_spec(dense_block, "main_input"),
            joined = inp_spec(
                concat_block,
                c(input_a = "tower_a", input_b = "tower_b")
            ),
            output = inp_spec(output_block, "joined")
        ),
        mode = "classification"
    )

    split <- initial_split(attrition, strata = Attrition)
    train <- training(split)

    rec <- recipe(Attrition ~ ., data = train) |>
        step_zv(all_predictors()) |>
        step_dummy(all_nominal_predictors()) |>
        step_normalize(all_numeric_predictors())

    spec <- attrition_towers(
        tower_a_units = tune(),
        tower_b_units = tune(),
        fit_epochs = 5
    ) |>
        set_engine("keras")

    wf <- workflow() |>
        add_recipe(rec) |>
        add_model(spec)

    params <- extract_parameter_set_dials(wf) |>
        update(
            tower_a_units = dials::hidden_units(c(16, 128)),
            tower_b_units = dials::hidden_units(c(16, 128))
        )

    grid <- grid_latin_hypercube(params, size = 8)
    folds <- vfold_cv(train, v = 3, strata = Attrition)
    ctrl <- control_grid(save_pred = FALSE)

    if (file.exists(attrition_res_path)) {
        res <- readRDS(attrition_res_path)
        message("Reusing: attrition_res.rds")
    } else {
        res <- tune_grid(
            wf,
            resamples = folds,
            grid = grid,
            metrics = metric_set(roc_auc, accuracy),
            control = ctrl
        )
        saveRDS(res, attrition_res_path)
        message("Saved: attrition_res.rds")
    }

    if (file.exists(attrition_final_path)) {
        message("Reusing: attrition_final.rds")
    } else {
        best <- select_best(res, metric = "roc_auc")
        final_wf <- finalize_workflow(wf, best)
        lf <- last_fit(
            final_wf,
            split = split,
            metrics = metric_set(roc_auc, accuracy)
        )

        preds <- collect_predictions(lf)
        event_level <- levels(preds$Attrition)[1]
        preferred <- paste0(".pred_", event_level)
        pos_col <- if (preferred %in% names(preds)) {
            preferred
        } else {
            pcols <- grep("^\\.pred_", names(preds), value = TRUE)
            pcols <- setdiff(pcols, ".pred_class")
            pcols[1]
        }

        attrition_final <- list(
            best = best,
            metrics = collect_metrics(lf),
            preds = preds,
            roc = yardstick::roc_curve(
                preds,
                truth = Attrition,
                !!rlang::sym(pos_col)
            )
        )
        saveRDS(attrition_final, attrition_final_path)
        message("Saved: attrition_final.rds")
    }
})
