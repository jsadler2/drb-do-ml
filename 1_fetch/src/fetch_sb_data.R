fetch_harmonized_wqp_data <- function(save_path){
  #' 
  #' @description Function to download the DRB multisource surface-water-quality dataset from ScienceBase (https://doi.org/10.5066/P9PX8LZO). 
  #' More information on column names can be found from the data release README as well as within the Water Quality Portal (WQP) 
  #' user guide: https://www.waterqualitydata.us/portal_userguide/ 
  #'
  #' @param save_path Path to save downloaded data consisting of "Water-Quality Data.zip" and all unzipped files
  #'
  #' @value A data frame containing the DRB harmonized water quality dataset for discrete samples  
  #' @examples 
  #' fetch_harmonized_WQP_data(save_path = "my_dir/out")
  
  # Set up save file:
  wqp_zip_file <- file.path(save_path, "/Water-Quality Data.zip")
  
  # Get the data from ScienceBase:
  sbtools::item_file_download(sb_id = '5e010424e4b0b207aa033d8c', dest_dir = save_path, overwrite_file = TRUE)
  
  # Unpack zip file and read in data:
  unzip(zipfile=wqp_zip_file,exdir = save_path,overwrite=TRUE)
  wqp_data <- readRDS(paste(save_path,"/Water-Quality Data/DRB.WQdata.rds",sep=""))
  
  return(wqp_data)
  
}

fetch_prms_met_data <- function(out_dir, filename){
  #' 
  #' @description Download the DRB PRMS meteorological data from ScienceBase. 
  #'
  #' @param out_dir name of directory where the output will be downloaded to 
  #' @param filename name of file to be downloaded 
  #'
  #' @value the combined filename and out_dir
  
  out_path = file.path(out_dir, filename)
  # Get the data from ScienceBase:
  sbtools::item_file_download(sb_id = '5f6a289982ce38aaa2449135',
                              names = c(filename),
                              destinations = c(out_path),
                              overwrite_file = TRUE)
  
  return(out_path)
}


unzip_and_load_prms_met <- function(in_file){
  #' 
  #' @description Download the DRB PRMS meteorological data from ScienceBase. 
  #' More information on column names can be found from the data release README as well as within the Water Quality Portal (WQP) 
  #' @value A data frame of the DRB PRMS met data
  
  # Get the data from ScienceBase:
  unzip(zipfile=in_file,exdir = dirname(in_file),overwrite=TRUE)
  met_data <- read_csv(file.path(dirname(in_file), "sntemp_inputs_outputs_drb.csv"))
  return(met_data)
}
