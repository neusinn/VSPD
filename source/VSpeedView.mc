using Toybox.WatchUi;
using Toybox.Activity;
using Toybox.Math;
using Toybox.FitContributor;

/*
	Simple datafield for vertical speed (VSPD) based on local barometric pressure.
	
	Variometer also known as: rate of climb and descent indicator (RCDI), rate-of-climb indicator, 
	vertical speed indicator (VSI), vertical velocity indicator (VVI).
	
    As datasource the ambient (local) barometric pressure as measured by the pressure sensor will be used. 
    The barometer sensor has al lot of noice. Here the ambientPressure is used. This source data is already smoothed 
    by a two-stage filter to reduce noise and instantaneous variation.
    
    In addition this algorithm will smoothe height with a Exponentially Weighted Moving Average (EWMA) filter with factor a = 0.1 of the newest measurement.
    The vertical speed is calculated over a 30 second time period and is rounded on 10 m/h.
    Vertical speed value below +/- 20 m/h will be set to 0.
*/
class VSpeedView extends WatchUi.SimpleDataField {

	
	const timePeriodInSec = 30;				// measure time period in seconds to calculate speed
	const queueSize = timePeriodInSec;
	const factorEWMA = 0.15;					// factor for Exponentially Weighted Moving Average (EWMA)
	const AVG_VSPD_MIN_FOR_MOVEMENT = 50; 	// Minimal ascend speed for recording 
	const MIN_VSPD = 20;

	
	private var lastComputeTime = 0;
	// data array for measurements series.
	private var queue = new [queueSize];
	private var idx = 0;
	
	// datafield in FIT file
	private var vspdField;	
	
	private var avgVspdUpField;
	private var avgVspdUp = 0;
	private var timeVspdUp = 0;
	
	private var propEnableGraph;
	private var propEnableLAPStatistic;
	private var propEnableSummaryStatistic;
	
	private var propAscentSpeedOnly;
	private var propInMotion;
	
	private var propZone1;
	private var propZone2;
	private var propZone3;
	private var propZone4;
	private var propZone5;
	
	private var zone1Field;
	private var zone2Field;
	private var zone3Field;
	private var zone4Field;
	private var zone5Field;

	private var zone1 = 0;
	private var zone2 = 0;
	private var zone3 = 0;
	private var zone4 = 0;
	private var zone5 = 0;
	
	var mSession;
    
    function initialize() {
    	
        SimpleDataField.initialize();
        label =  WatchUi.loadResource(Rez.Strings.vspd_label) + " " +  WatchUi.loadResource(Rez.Strings.vspd_unit); // The displayed label of the data field.
        
        lastComputeTime = 0;
        
        propEnableGraph = Application.Properties.getValue("propEnableGraph");
        propEnableLAPStatistic = Application.Properties.getValue("propEnableLAPStatistic");
        propEnableSummaryStatistic = Application.Properties.getValue("propEnableSummaryStatistic");
        
        propAscentSpeedOnly = Application.Properties.getValue("propAscentSpeedOnly");
        propInMotion = Application.Properties.getValue("propInMotion");
        
        propZone1 = Application.Properties.getValue("propZone1");
        propZone2 = Application.Properties.getValue("propZone2");
        propZone3 = Application.Properties.getValue("propZone3");
        propZone4 = Application.Properties.getValue("propZone4");
        
        propZone2 = (propZone1 < propZone2) ? propZone2 : propZone1 + 1;
        propZone3 = (propZone2 < propZone3) ? propZone3 : propZone2 + 1;
        propZone4 = (propZone3 < propZone4) ? propZone4 : propZone3 + 1;
 
        
        if (propEnableGraph) {
	        // Create the custom FIT data field to record vertical speed.
	        vspdField = createField(
	            "vspd",
	            47,
	            FitContributor.DATA_TYPE_SINT16,
	            {:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>"m/h"}
	        );
	        
	        vspdField.setData(0);
        }
        
        if (propEnableLAPStatistic) {        
	        avgVspdUpField = createField(
	            "avgVspdAscent",
	            48,
	            FitContributor.DATA_TYPE_SINT16,
	            {:mesgType=>FitContributor.MESG_TYPE_LAP, :units=>"m/h"}
	        );

	    	avgVspdUpField.setData(0);
	    }
        
        if (propEnableSummaryStatistic) {
	        zone1Field = createField(
	            "Z1",
	            51,
	            FitContributor.DATA_TYPE_STRING,
	            {:mesgType=>FitContributor.MESG_TYPE_SESSION, :count=>6}
	        );
	        zone2Field = createField(
	            "Z2",
	            52,
	            FitContributor.DATA_TYPE_STRING,
	            {:mesgType=>FitContributor.MESG_TYPE_SESSION, :count=>6}
	        );
	        zone3Field = createField(
	            "Z3",
	            53,
	            FitContributor.DATA_TYPE_STRING,
	            {:mesgType=>FitContributor.MESG_TYPE_SESSION, :count=>6}
	        );
	        zone4Field = createField(
	            "Z4",
	            54,
	            FitContributor.DATA_TYPE_STRING,
	            {:mesgType=>FitContributor.MESG_TYPE_SESSION, :count=>6}
	        );
	        zone5Field = createField(
	            "Z5",
	            55,
	            FitContributor.DATA_TYPE_STRING,
	            {:mesgType=>FitContributor.MESG_TYPE_SESSION, :count=>6}
	        );
	        
	        zone1Field.setData("0:00");
	        zone2Field.setData("0:00");
	        zone3Field.setData("0:00");
	        zone4Field.setData("0:00");
	        zone5Field.setData("0:00");
		}
                
    }


    // The given info object contains all the current workout information. 
    // Calculate a value and return it in this method.
    // Note that compute() and onUpdate() are asynchronous, and there is no
    // guarantee that compute() will be called before onUpdate().
    // Normlly this function will be called once every second.
    function compute(info) {
		// Read the ambient (local) barometric pressure as measured by the pressure sensor. 
		// This data is already smoothed by a two-stage filter to reduce noise and instantaneous variation.

		var p = info.ambientPressure;
		
		if (p == null) { return "n/a"; }

		var time = Time.now();
		var height = calcHeightFromPressure(p);	
		
		var computeInterval = 1;
		if ( lastComputeTime != 0) {
			computeInterval = time.subtract(lastComputeTime).value();
		}
		lastComputeTime = time;

		// Exponentially Weighted Moving Average (EWMA)
		var newestDataPoint = readNewestEntryFromQueue();
		if (newestDataPoint != null) { 
			height = factorEWMA * height + (1 - factorEWMA) * newestDataPoint[:height];
		}
        
        var dataPoint = fifoQueue({ :time=>time, :height=>height });
		if (dataPoint == null) { return 0; } // handle start condition.
		
		// vspd = (h - h0) / (t - t0)
		var deltaTime = time.subtract(dataPoint[:time]).value();
        var vspd = (height - dataPoint[:height]) / deltaTime * 3600;
        
        // DEBUG logData(info, vspd, height, height - dataPoint[:height], deltaTime);
        
        // Supress VSPD values < |MIN_VSPD| 
        // This reduce noise  
        if (vspd < MIN_VSPD and vspd > - MIN_VSPD) {
        	vspd = 0;
        }


        if (propEnableGraph) {
        	// record data for VSPD graph
	        if (vspd >= 0 or ! propAscentSpeedOnly) {
	        	vspdField.setData(vspd);
	        }
        }
        
        if (propEnableLAPStatistic) {
	        // record LAP data for average ascend speed
	        if (vspd > AVG_VSPD_MIN_FOR_MOVEMENT) {
	        	avgVspdUp = (avgVspdUp * timeVspdUp + vspd * computeInterval) / (timeVspdUp + computeInterval);
	        	timeVspdUp = timeVspdUp + computeInterval;
	        	avgVspdUpField.setData(avgVspdUp);
	        
	        } else if (! propInMotion) {
	        	vspd = (vspd < 0) ? 0 : vspd; // Ignore descent vor
	        	avgVspdUp = (avgVspdUp * timeVspdUp + vspd * computeInterval) / (timeVspdUp + computeInterval);
	 	        timeVspdUp = timeVspdUp + computeInterval;
	        	avgVspdUpField.setData(avgVspdUp);
	        }
        }
        
        if (propEnableSummaryStatistic) {
	        // record Zone summary
	        if (vspd < propZone1) {
	        	zone1 += computeInterval;
	        	zone1Field.setData(secondsToTimeString(zone1));
	        } else if (vspd < propZone2) {
	        	zone2 += computeInterval;
	        	zone2Field.setData(secondsToTimeString(zone2));
	        } else if (vspd < propZone3) {
	        	zone3 += computeInterval;
	        	zone3Field.setData(secondsToTimeString(zone3));
	        } else if (vspd < propZone4) {
	        	zone4 += computeInterval;
	        	zone4Field.setData(secondsToTimeString(zone4));
	        } else {
	        	zone5 += computeInterval;
	        	zone5Field.setData(secondsToTimeString(zone5));
	        }
        }
        
        
        // round VSPD on the next 10m/h
        vspd = (Math.round(vspd / 10) * 10).toNumber();
        
       	return vspd;
    }

    
    function secondsToTimeString(timeInSeconds) {
    	var hours = timeInSeconds / 3600;
		var minutes = (timeInSeconds / 60) % 60;
		var timeString = format("$1$:$2$", [hours.format("%2d"), minutes.format("%02d")]);
	return timeString;
    } 
 
 
    function calcHeightFromPressure(p) {
        /*
        	P current barometric pressure (Pa)
        	return uncalibrated altitute from pressure
        	
        	Constants:      
        	Po = 101325.0;		//Average sea level pressure (Pa)   
        	g = 9.80665;        //Gravitational acceleration (m/s2)
        	M = 0.0289697;      //Molar mass of air (kg/mol)
        	T = 288.15;			//Standard temperature (K)
        	R = 8.31446;		//Universal gas constant (N·m)/(mol·K)
        
        	h = -(R * T) / (M * g) * Math.ln(P / Po);  // uncalibrated altitude
        */
        if (p == null) { return 0; }
        
		var Po = 101325.0;   // Constant Average sea level pressure (Pa)    
        var c = 8433.114;    // precalculated: c = (R * T) / (M * g)
        var h = -c * Math.ln(p / Po);
        
        return h;
    }
    
    // put new element & get oldest element
    function fifoQueue(in) { 
        idx += 1;
        if (idx == queueSize) { idx = 0; }  
        
        var out = queue[idx];
        queue[idx] = in;
        return out;
    }
    
    function readNewestEntryFromQueue() {   
        return queue[idx];
    }
    


	(:debug) function logTitles() {
	    System.println("time" + 
        ", vspd: " + 
        ", height calc: " + 
        ", height diff: " + 
        ", time delta: " +
        ", altitude: " + 
        ", ambientPressure: " +
        ", rawAmbientPressure: ");
	}
	
	
	(:debug) function logData(info, vspd, height, deltaHeight, deltaTime) {	
		var time = System.getClockTime(); // ClockTime object     	
        System.println(time.hour.format("%02d") + ":" + time.min.format("%02d") + ":" + time.sec.format("%02d") + ", " +
        vspd + ", " +
        height.format("%4.2i") + ", " +
        deltaHeight.format("%3.2i") + ", " +
        deltaTime + ", " +
        info.altitude.format("%4d") + ", " +
        info.ambientPressure + ", " +
        info.rawAmbientPressure);
	}
}
