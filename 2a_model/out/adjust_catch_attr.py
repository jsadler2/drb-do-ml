import xarray as xr
import numpy as np

ds = xr.open_zarr("well_obs_io.zarr")

test_sites = ['01475530', '01475548']

trn_sites = ds.site_id[~np.isin(ds.site_id, test_sites)]

ds_trn = ds.sel(site_id = trn_sites)

vars_in_question = ["CAT_RDX", "TOT_IMPV11", "TOT_BASIN_SLOPE"]


# for v in vars_in_question:
    # ds_adj = ds.copy(deep=True)
    # mean = ds_trn[v].mean().values
    # for da in ds_adj.values():
        # if da.name == v:
            # da.loc[dict(site_id = test_sites)] = mean
    # for var in ds_adj.variables:
        # ds_adj[var].encoding.clear()
    # ds_adj.to_zarr(f"well_obs_io_ADJ_{v}.zarr")

for v in vars_in_question:
    mean = ds_trn[v].mean().values
    for da in ds.values():
        if da.name == v:
            da.loc[dict(site_id = test_sites)] = mean

for var in ds.variables:
    ds[var].encoding.clear()

ds.to_zarr(f"well_obs_io_ADJ_RDX_IMP_SLP.zarr")
