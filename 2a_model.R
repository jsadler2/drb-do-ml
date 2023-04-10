source("2a_model/src/model_ready_data_utils.R")
source("2a_model/src/write_model_config_files.R")


p2a_targets_list <- list(

  ## 1) COMBINE AND FORMAT MODEL-READY INPUTS AND OUTPUTS ##
  # join met data with light input data
  tar_target(
    p2a_met_light_data,
    p2_met_data_at_obs_sites %>%
      mutate(date = as.Date(time, tz = 'UTC')) %>%
      left_join(y = p2_daily_max_light %>%
                  select(COMID, date_localtime, frac_light) %>%
                  # format column names
                  rename(light_ratio = frac_light,
                         date = date_localtime),
                by = c("COMID", "date")) %>%
      select(-time) %>%
      relocate(date, .after = COMID)
  ),
  
  # join met and light data with site_ids (resulting data frame will have
  # 16 unique COMID's which matches the number of well-observed reaches).
  tar_target(
    p2a_met_data_w_sites,
    match_site_ids_to_segs(p2a_met_light_data, p2_sites_w_segs)
  ),

  # join segment attributes with site_ids (resulting data frame will have one
  # row for each unique COMID x site_id in the lower DRB; n = 10,111).
  tar_target(
    p2a_seg_attr_w_sites,
    match_site_ids_to_segs(p2_seg_attr_data, p2_sites_w_segs)
  ),
  
  # join the metabolism data with the DO observations (use full_join to include
  # all rows in both the DO data and the metab data).
  tar_target(
    p2a_do_and_metab,
    p2_daily_with_seg_ids %>%
      full_join(p2_metab_filtered, by = c("site_id", "date"))
  ),

  
  ## 2) SPLIT SITES INTO (train) and (train and validation) ##
  # char vector of well-observed train sites
  tar_target(
    p2a_trn_sites,
    p2_well_observed_sites[!(p2_well_observed_sites %in% val_sites)]
  ),

  # char vector of well-observed val and training sites
  tar_target(
    p2a_trn_val_sites,
    p2_well_observed_sites[(p2_well_observed_sites %in% p2a_trn_sites) | (p2_well_observed_sites %in% val_sites)]
  ),

  # get sites that we use for training, but also have data in the val time period
  tar_target(
    p2a_trn_sites_w_val_data,
    p2_daily_with_seg_ids  %>%
      filter(site_id %in% p2a_trn_val_sites,
             !site_id %in% val_sites,
             date >= val_start_date,
             date < val_end_date) %>%
      group_by(site_id) %>%
      summarise(val_count = sum(!is.na(do_mean))) %>%
      filter(val_count > 0) %>%
      pull(site_id)
  ),
  
  # Summarize site splits/groups based on the above 3 targets
  tar_target(
    p2a_site_splits,
    p2_sites_w_segs %>%
      filter(site_id %in% c(p2a_trn_sites, val_sites)) %>%
      mutate(site_type = case_when(
        site_id %in% p2a_trn_sites & 
          !site_id %in% p2a_trn_sites_w_val_data ~ "train",
        site_id %in% p2a_trn_sites_w_val_data ~ "train/val",
        site_id %in% val_sites ~ "validation",
        TRUE ~ NA_character_),
        # assign epsg codes based on "datum" column and convert
        # data frame to sf object
        epsg = case_when(datum == "NAD83" ~ 4269,
                         datum == "WGS84" ~ 4326,
                         datum == "NAD27" ~ 4267,
                         datum == "UNKWN" ~ 4326,
                         datum == "OTHER" ~ 4326)) %>%
      sf::st_as_sf(., coords = c("lon","lat"), crs = unique(.$epsg))
  ),
  
  
  ## 3) WRITE OUT PARTITION INPUT AND OUTPUT DATA ##
  # Subset trn/val input and output data to well-observed sites and format
  # for export. [Jeff]: note - I have to subset inputs to only include the
  # train/val sites before passing to subset_and_write_zarr or else I get a
  # memory error on the join. 
  tar_target(
    p2a_well_obs_data,
    {
      # use inner_join to keep sites that are within the set of trn/val sites
      # and are represented in both the met data and the seg attr data.
      inputs <- p2a_met_data_w_sites %>%
        filter(site_id %in% p2a_trn_val_sites) %>%
        inner_join(p2a_seg_attr_w_sites, by = c("site_id", "COMID"))

      inputs_and_outputs <- inputs %>%
          left_join(p2a_do_and_metab, by = c("site_id", "COMID", "date"))
      
      inputs_and_outputs
    }
  ),
  
  # Write trn and val input and output data to zarr. Note that if the name of 
  # well_obs_io.zarr is changed below, this change must also be made in 
  # 2a_model/src/Snakefile_base.smk (lines 32, 103, and 177) and in 
  # 2a_model/src/visualize_models.smk (line 6). 
  tar_target(
    p2a_well_obs_data_zarr,
    write_df_to_zarr(p2a_well_obs_data, c("site_id", "date"), "2a_model/out/well_obs_io.zarr"),
    format = "file"
  ),
  
  
  ## 4) GATHER MODEL IDS  ##
  # gather model ids - add to this list when you want to reproduce
  # outputs from a new model 
  tar_target(
    p2a_model_ids,
    # paths are relative to 2a_model/src/models
      list(
        list(model_id = "0_baseline_LSTM",
             snakefile_dir = "0_baseline_LSTM",
             config_options = config_options_0,
             config_path = "0_baseline_LSTM/config.yml"),
         #the 1_ models use the same model and therefore the same Snakefile
         #as the 0_baseline_LSTM run
        list(model_id = "1_metab_multitask",
             snakefile_dir = "0_baseline_LSTM",
             config_options = config_options_1,
             config_path = "1_metab_multitask/config.yml"),
        list(model_id = "1a_multitask_do_gpp_er",
             snakefile_dir = "0_baseline_LSTM",
             config_options = config_options_a,
             config_path = "1_metab_multitask/1a_multitask_do_gpp_er.yml"),
        list(model_id = "1b",
             snakefile_dir = "0_baseline_LSTM",
             config_options = config_options_b,
             config_path = "1_metab_multitask/1b_multitask_do_gpp.yml"),
        list(model_id = "1c",
             snakefile_dir = "0_baseline_LSTM",
             config_options = config_options_c,
             config_path = "1_metab_multitask/config_1c.yml"),
        list(model_id = "1d",
             snakefile_dir = "0_baseline_LSTM",
             config_options = config_options_d,
             config_path = "1_metab_multitask/config_1d.yml"),
        list(model_id = "1e",
             snakefile_dir = "0_baseline_LSTM",
             config_options = config_options_e,
             config_path = "1_metab_multitask/config_1e.yml"),
        list(model_id = "1f",
             snakefile_dir = "0_baseline_LSTM",
             config_options = config_options_f,
             config_path = "1_metab_multitask/config_1f.yml"),
        list(model_id = "2_multitask_dense",
             snakefile_dir = "2_multitask_dense",
             config_options = config_options_1,
             config_path = "2_multitask_dense/config.yml"),
        list(model_id = "2c",
             snakefile_dir = "2_multitask_dense",
             config_options = config_options_c,
             config_path = "2_multitask_dense/config_2c.yml"),
        list(model_id = "2d",
             snakefile_dir = "2_multitask_dense",
             config_options = config_options_d,
             config_path = "2_multitask_dense/config_2d.yml"),
        list(model_id = "2e",
             snakefile_dir = "2_multitask_dense",
             config_options = config_options_e,
             config_path = "2_multitask_dense/config_2e.yml"),
        list(model_id = "2f",
             snakefile_dir = "2_multitask_dense",
             config_options = config_options_f,
             config_path = "2_multitask_dense/config_2f.yml")
        ),
    iteration = "list"
  ),
  
  ## 5) WRITE MODEL CONFIGURATION FILES ##
  # Write base config file using inputs and parameters defined in _targets.R
  tar_target(
    p2a_config_base_yml,
    write_config_file(cfg_options = base_config_options,
                      fileout = "2a_model/src/models/config_base.yml"),
    format = "file"
  ),
  
  # Write model config file for individual models
  tar_target(
    p2a_model_configs,
    write_config_file(cfg_options = p2a_model_ids$config_options,
                      fileout = file.path("2a_model/src/models", p2a_model_ids$config_path),
                      exp_name = p2a_model_ids$model_id),
    format = "file",
    pattern = map(p2a_model_ids)
  ),
  
  ## 6) KICK OFF SNAKEMAKE WORKFLOW TO MAKE MODEL PREDICTIONS ##
  # produce the final metrics files (and all intermediate files including predictions)
  # of each "model_id" with snakemake
  tar_target(
    p2a_metrics_files,
    {
    # we need these to make the prepped data file, so force a dependency of this 
    # target on p2a_well_obs_data.
    p2a_well_obs_data
    p2a_well_obs_data_zarr
    p2a_model_configs

    base_dir <- "2a_model/src/models"
    snakefile_path <- file.path(base_dir, p2a_model_ids$snakefile_dir, "Snakefile")
    config_path <- file.path(base_dir, p2a_model_ids$config_path)
    # this path is relative to the Snakefile
    prepped_data_file <- file.path("../../../out/models",p2a_model_ids$model_id, "prepped.npz")

    # make sure the directory is unlocked (this has been a hangup for me) 
    system(stringr::str_glue("snakemake  -s {snakefile_path} --configfile {config_path} --unlock"))
    # First create the prepped data files if they are not already.
    # These are needed to make the predictions.
    system(stringr::str_glue("snakemake {prepped_data_file} -s {snakefile_path} --configfile {config_path} -j"))

    # Then touch all of the existing files. This makes the weights "up-to-date"
    # so snakemake doesn't train the models again
    system(stringr::str_glue("snakemake -s {snakefile_path} --configfile {config_path} -j --touch --rerun-incomplete"))

    # then run the snakemake pipeline to produce the predictions and metric files
    system(stringr::str_glue("snakemake -s {snakefile_path} --configfile {config_path} -j --rerun-incomplete --rerun-trigger mtime"))
    
    # print out the metrics file name for the target
   c(
     file.path("2a_model/out/models", p2a_model_ids$model_id, "exp_overall_metrics.csv"),
     file.path("2a_model/out/models", p2a_model_ids$model_id, "exp_reach_metrics.csv"),
     file.path("2a_model/out/models", p2a_model_ids$model_id, "exp_month_reach_metrics.csv"),
     file.path("2a_model/out/models", p2a_model_ids$model_id, "exp_month_metrics.csv"),
     file.path("2a_model/out/models", p2a_model_ids$model_id, paste0(p2a_model_ids$model_id, "_func_perf.csv"))
    )
    },
    format="file",
    pattern = map(p2a_model_ids)
  ),


  # metric types so we can map over them
  tar_target(
    p2a_metric_types,
    {
     c("overall", "reach", "month_reach", "month")
    },
  ),

  # combining the individual predictive performance (PP) metrics files from four different model experiments into one data frame for each metric type (i.e., overall metrics, overall reach metrics, reach metrics by month, overall metrics by month).
  tar_target(
    p2a_PP_metrics_files,
    {
      metric_files = grep(paste0("exp_", p2a_metric_types, "_metrics"), p2a_metrics_files, value=TRUE)
      out_file_name = paste0("2a_model/out/models/combined_", p2a_metric_types, "_metrics.csv")
      lapply(metric_files, function(x){
        dat <- readr::read_csv(x, show_col_types = FALSE) %>%
          mutate(model_id = str_replace_all(x, paste0('2a_model/out/models/|/exp_', p2a_metric_types, '_metrics.csv'), ''))
        }) %>%
        bind_rows() %>%
        write_csv(out_file_name)
      out_file_name
    },
    format="file",
    pattern = map(p2a_metric_types)
  ),
                         

  # combining the functional performance files into one
  tar_target(
    p2a_FP_metrics_file,
    {
      overall_metric_files = grep("func_perf", p2a_metrics_files, value=TRUE)
      overall_metric_files <- append(overall_metric_files,
                                     "2a_model/out/models/2_multitask_dense/observed_func_perf.csv")
      out_file_name = "2a_model/out/models/combined_FP_metrics.csv"
      lapply(overall_metric_files, function(x){
        dat <- readr::read_csv(x,
                               show_col_types = FALSE,
                               col_types = cols(model = col_character()))}) %>%
        bind_rows() %>%
        write_csv(out_file_name)
      out_file_name
    },
    format="file",
  )
  
)

