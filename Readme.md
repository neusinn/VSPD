# VSPD Vertical Speed

## Introduction
This is a Data Field for the Garmin devices as smartwatches and GPS Devices.

## Application  
### Description

Vertical Speed (VSPD) is a data field to show and record the vertical speed (VSPD) based on local barometric pressure.
Also known as: Variometer, rate of climb and descent indicator (RCDI), rate-of-climb indicator, vertical speed indicator (VSI) or vertical velocity indicator (VVI).

### Detailed description
Description as published in the appstore [english](description_en.txt) and [german](description_de.txt). 


###
Link to Garmin connect store: [VSPD]()

### Functions
1. VSPD is a data field that shows the vertical speed in [m/h]. 
2. VSPD records the vertical speed data to the FIT-file when used during an activity. 
3. The VSPD recorded data will be presented as a graph when displaying your Activity in the Garmin Connect Website.
4. Record Ø ascent speed in LAP statistic.
5. Record time in speed zones in summary statistic.
6. Add settings to configure what data should be recorded and shown. 

#### Detailed Algorithm *
vspd = delta h / delta t 

Unfortunately the pressure sensors of the devices are not very accurate and the data is quite noisy.  This is the algorithm to smoothen it. Its not perfect. The problem is that it is an balance between smoothness and reactiveness. 
a) As datasource the ambient (local) barometric pressure as measured by the pressure sensor will be used. This source data comes smoothed by a two-stage filter to reduce noise and instantaneous variation.
b) In addition the value are smoothes  by a Exponentially Weighted Moving Average (EWMA) filter with factor a = 0.15 of the newest measurement.
c) The vertical speed calculated over a 30 second time period.
d) VSPD is rounded on 10 m/h.
e) The measurement is done every second.
f) VSPD values less than |20| m/h are set to 0

#### Configuration of VSPD in App-Settings
* disable the additional statistic and graphs *
- Enable/Disable VSPD recording and graph
- Enable/Disable Ø ascent speed in LAP
- Enable/Disable ascend speed zones statistic
- Record ascend speed only (suppress descent speed, this can improve readability)
- LAP Ø : average ascend speed. Calculated during time you actually ascend. (Minimal ascend needs to be 50m).
See: https://forums.garmin.com/developer/connect-iq/w/wiki/14/changing-your-app-settings-in-garmin-express-gcm-ciq-mobile-store on how to change the app settings.


## Development

- Garmin [Developer Overview](https://developer.garmin.com/connect-iq/)
- [API documentation](https://developer.garmin.com/connect-iq/api-docs/)
- [Developer Dashboard](https://apps.garmin.com/de-DE/developer/dashboard)
- VSPD Application [VSPD Vertical Speed](https://apps.garmin.com/de-DE/apps/32e646e5-ae13-4df6-a95d-af9b0e90c6dd)
