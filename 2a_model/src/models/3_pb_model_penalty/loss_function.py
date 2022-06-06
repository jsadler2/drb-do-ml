import tensorflow as tf
import metab_utils
from river_dl.loss_functions import multitask_rmse



def penalize_by_pb_model(meta_lambdas):
    """
    loss function to penalize the DO predictions based on deviations from
    process model estimates of DO in addition to DO observations. The loss has 
    three main components: 
        1. Loss contributed by deviations of the metabolism predictions from 
        the Appling et.al 2018 estimates
        2. Loss contributed by deviations of the DO predictions from the DO
        observations
        3. Loss contributed by deviations of the DO predictions from the DO
        estimates based on process based equations that take metabolism rates
        as input

    :param meta_lambdas: [iterable of numbers] weights for the three components
    of loss. Weights will be applied to the loss components in the order above
    """
    def pb_model_loss(y_true, y_pred):
        
        # Metab Loss
        ## leaving the lower-level lambdas as 1 for now
        metab_lambdas = [1, 1, 1, 1, 1]
        metab_rmse_fxn = multitask_rmse(metab_lambdas)
        metab_loss = metab_rmse_fxn(y_true[:, :, 3:7], y_pred[:, :, 3:7])

        # DO Loss from observations
        ## leaving the lower-level lambdas as 1 for now
        DO_lambdas_obs = [1, 1, 1]
        DO_rmse_fxn = multitask_rmse(DO_lambdas_obs)
        DO_loss_obs = DO_rmse_fxn(y_true[:, :, :2], y_pred[:, :, :2])

        # DO Loss from process-based estimates 
        ## get DO estimates from PB equations
        elev = y_true[:, :, 8]
        light_ratio = y_true[:, :, 9]

        GPP = y_pred[:, :, 3]
        ER = y_pred[:, :, 4]
        K600 = y_pred[:, :, 5]
        z = y_pred[:, :, 6]
        T = y_pred[:, :, 7]

        K2 = metab_utils.calc_K2(K600, T)
        k2 = K2 *z

        DO_sat = metab_utils.calc_DO_sat(T, elev)

        er_ratio = 1/48

        # use the metabolism estimates to calculate DO min, max
        DO_min_PB = DO_sat + (ER/k2) 
        DO_max_PB = DO_sat + ((GPP * light_ratio) + ER * er_ratio)/(k2 * er_ratio)
        
        DO_min_max_PB = tf.stack((DO_min_PB, DO_max_PB), axis=2)

        ## calculate loss based on PB estimates
        ## leaving the lower-level lambdas as 1 for now
        DO_lambdas_PB = [1, 1]
        DO_rmse_fxn_PB = multitask_rmse(DO_lambdas_PB)
        DO_loss_PB = DO_rmse_fxn_PB(DO_min_max_PB,
                                    tf.gather(y_pred, indices=(0, 2), axis=2))
    
        combined_loss = meta_lambdas[0] * metab_loss + meta_lambdas[1] * DO_loss_obs + meta_lambdas[2] * DO_loss_PB

        return combined_loss
    return pb_model_loss


