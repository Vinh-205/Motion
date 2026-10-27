package com.example.cam_bien_te_nga

import android.hardware.Sensor
import android.hardware.SensorManager

/** Some phones expose only an uncalibrated gyro; some have no gyro at all. */
object SensorCapabilities {
    fun accelerometer(manager: SensorManager): Sensor? =
        manager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER, true)
            ?: manager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    fun gyroscope(manager: SensorManager): Sensor? =
        manager.getDefaultSensor(Sensor.TYPE_GYROSCOPE, true)
            ?: manager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
            ?: manager.getDefaultSensor(Sensor.TYPE_GYROSCOPE_UNCALIBRATED, true)
            ?: manager.getDefaultSensor(Sensor.TYPE_GYROSCOPE_UNCALIBRATED)
}
