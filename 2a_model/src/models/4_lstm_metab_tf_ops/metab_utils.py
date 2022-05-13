# import numpy as np
import tensorflow as tf
from tensorflow.math import pow, multiply, divide


def calc_press_pa(elev):
    """
    Calculate the atmospheric pressure at a given elevation. 
    Notes:
    - using "normal temperature and pressure" (20 deg C)
    References:
    - https://en.wikipedia.org/wiki/Barometric_formula

    :param elev: (float) elevation in meters 
    :returns: (float) atmospheric pressure in units of atm
    """
    g0 = 9.80665 # (m/s^2) gravitational constant
    M = 0.0289644 # (kg/mol) molar mass of Earth's air
    R = 8.3144598 # (J/mol/K) universal gas constant
    Tb = 293.15 # reference temperature; 20 deg C
    Pb = 101325.0 # reference pressure; Pa at 20 deg C

    P = multiply(Pb, tf.math.exp(divide(multiply(multiply(-g0, M), elev), multiply(R, Tb))))

    return P


def calc_press_atm(elev):
    return divide(calc_press_pa(elev), 101325)


def calc_DO_sat(temp_C, elev, salinity=0):
    """
    calculate saturation DO
    :param temp_C: (float) temperature in degrees C
    :param elev: (float) elevation in meters

    """
    # DO just based on temperature
    A1 = -139.34411
    A2 = 1.575701e5
    A3 = 6.642308e7
    A4 = 1.243800e10
    A5 = 8.621949e11

    temp_K = temp_C + 273.15

    DO = tf.math.exp(A1 + divide(A2, temp_K) -
                     divide(A3, pow(temp_K, 2)) +
                     divide(A4, pow(temp_K, 3)) -
                     divide(A5, pow(temp_K, 4)))


    # salinity factor
    Fs = tf.math.exp(multiply(tf.cast(-salinity, tf.float32), (0.017674 - divide(10.754, temp_K) + divide(2140.7, pow(temp_K, 2)))))


    # pressure factor 
    P_atm = calc_press_atm(elev)
    theta = 0.000975 -\
         multiply(temp_C, 1.426e-5) +\
         multiply(pow(temp_C, 2), 6.436e-8)

    u = tf.math.exp(11.8571 - divide(3840.70, temp_K) - divide(216961, pow(temp_K, 2)))


    Fp = multiply(P_atm - u, divide(1-multiply(theta, P_atm), multiply(1-u, 1-theta)))


    return multiply(multiply(DO, Fp), Fs)


def calc_K2(K600, T):
    sA = 1568
    sB = -86.04
    sC = 2.142
    sD = -0.0216
    sE = -0.5
    return multiply(K600, pow(divide(sA + multiply(sB, T) + multiply(sC, pow(T, 2)) + multiply(sD, pow(T, 3)), 600), sE))




