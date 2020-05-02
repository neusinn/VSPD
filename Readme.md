# VSPD Vertical Speed

## Introduction
VSPD is a datafield for vertical speed (VSPD) based on local barometric pressure.

## Algorithm

Variometer also known as: rate of climb and descent indicator (RCDI), rate-of-climb indicator, vertical speed indicator (VSI), vertical velocity indicator (VVI).
	
As datasource the ambient (local) barometric pressure as measured by the pressure sensor will be used. 
This source data is already smoothed by a two-stage filter to reduce noise and instantaneous variation.
    
This algorithm will smoothes height by a Exponentially Weighted Moving Average (EWMA) filter with factor a = 0.2 of the newest measurement.
The vertical speed calculated over a 20 second time period and is rounded on 10 m/h.

