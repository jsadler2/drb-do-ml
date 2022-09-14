from do_it_functions import get_max_it_df
import pandas as pd


input_file = "../../2a_model/out/med_obs_io.zarr"
models = ["0_baseline_LSTM", "2_multitask_dense"]
n_reps = 5
base_file_path = "4_func_perf/in/results_tmmx_tmmn/models"
sinks = ['do_min', 'do_max', 'do_range', 'do_mean']

df_list = []
for rep_id in range(n_reps):
    print('rep_id: ', rep_id)
    df = get_max_it_df(input_file, models, base_file_path, rep_id, sinks)
    df['rep_id'] = rep_id
    df_list.append(df)

df_comb = pd.concat(df_list)

