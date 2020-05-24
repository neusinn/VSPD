# VSPD Vertical Speed

## Introduction
This is a Data Field for the Garmin devices as smartwatches and GPS Devices.

## Description

Vertical Speed (VSPD) is a data field to show and record the vertical speed (VSPD) based on local barometric pressure.
Also known as: Variometer, rate of climb and descent indicator (RCDI), rate-of-climb indicator, vertical speed indicator (VSI) or vertical velocity indicator (VVI).

### Functions

1. VSPD is a data field that shows the vertical speed in [m/h]. 
2. VSPD records the vertical speed data to the FIT-file when used during an activity. 
3. The VSPD recorded data will be presented as a graph when displaying your Activity in the Garmin Connect Website.
4. Record Ø ascent speed in LAP statistic.
5. Record time in speed zones in summary statistic.
6. Add settings to configure what data should be recorded and shown. 

### Contact the Developer

Sometime things works not as expected. Please not this is a new data field and if you have issues with this data field please contact the developer. So we can improve.
If you like it we love to hear from you. So please write a review. 


## Detailed Algorithm

Just to get a better understanding what the value actually means.

vspd = delta h / delta t 

As the pressure sensor of the devices are quite noisy following steps where taken used to smooth it.
a) As datasource the ambient (local) barometric pressure as measured by the pressure sensor will be used. This source data comes smoothed by a two-stage filter to reduce noise and instantaneous variation.
b) In addition the value are smoothes  by a Exponentially Weighted Moving Average (EWMA) filter with factor a = 0.15 of the newest measurement.
c) The vertical speed calculated over a 30 second time period.
d) VSPD is rounded on 10 m/h.
e) The measurement is done every second.
f) VSPD values < |20| m/h are set to 0

## Datafield Settings

- Enable VSPD recording and graph
- Enable 0 ascent speed in LAP
- Enable ascend speed zones statistic
- Record ascend speed only (suppress descent speed, this can improve readability)
- LAP: Ø ascend speed calculate during ascend only 

See: https://forums.garmin.com/developer/connect-iq/w/wiki/14/changing-your-app-settings-in-garmin-express-gcm-ciq-mobile-store on how to change the app settings.


# Release Notes

v 0.5.0 Initial version
v 0.6.0 Correct units. Improved Algorithm. Changed graph color to Cobalt blue.
v 0.7.0 New Functionality: Configurable in settings. Add Ø ascent speed in LAP. Add time in speed zones in summary statistic.
v 0.7.1 Correct Ø ascent speed LAP statistic. Set EWMA factor to 0.15.