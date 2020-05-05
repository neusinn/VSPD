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

	// measure time period in seconds to calculate speed
	const timePeriodInSec = 30;
	const queueSize = timePeriodInSec;
	const factorEWMA = 0.1;
	//const intervalRecordToFit = 5; // Interval to record data point to fit file
	//var   intervalCounter = 0;
	
	// data array for measurements series.
	private var queue = new [queueSize];
	private var idx = 0;
	
	// datafield in FIT file
	const VSPD_FIELD_ID = 47;
	var vspdField = null;	
	
	//var TEST_PRESSURE = 94000;
	//var TEST_COUNTER = 0;
	
	var mSession;
    
    function initialize() {
    	
        SimpleDataField.initialize();
        label =  WatchUi.loadResource(Rez.Strings.vspd_label) + " " +  WatchUi.loadResource(Rez.Strings.vspd_unit); // The displayed label of the data field.
        
        // Create the custom FIT data field to record vertical speed.
        vspdField = createField(
            "vspd",
            VSPD_FIELD_ID,
            FitContributor.DATA_TYPE_SINT32,
            {:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>"m/h"}
        );
        
        vspdField.setData(0.0);
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
		
		// TODO remove after test
		//p = TEST_PRESSURE;
		//TEST_PRESSURE -= 10;
		
		if (p == null) { return "n/a"; }

		var time = Time.now();
		var height = calcHeightFromPressure(p);	

		// Exponentially Weighted Moving Average (EWMA)
		var newestDataPoint = readNewestEntryFromQueue();
		if (newestDataPoint != null) { 
			height = factorEWMA * height + (1 - factorEWMA) * newestDataPoint[:height];
		}
        
        var dataPoint = fifoQueue({ :time=>time, :height=>height });
		if (dataPoint == null) { return 0; } // handle start condition.
		
		// vspd = (h - h0) / (t - t0)
        var vspd = (height - dataPoint[:height]) / (time.subtract(dataPoint[:time]).value()) * 3600;
        
        // DEBUG logData(info, vspd, height, height - dataPoint[:height], time.subtract(dataPoint[:time]).value());
        
        // Supress VSPD values < |20|  
        if (vspd < 20 and vspd > -20) {
        	vspd = 0;
        }
        
        /* reduce entries
        // write vspdField to activity reccord
        if (intervalCounter >= intervalRecordToFit) {
        	vspdField.setData(vspd);
        	intervalCounter = 0;
        } else {
        	intervalCounter =+ 1;
        }
        */
        vspdField.setData(vspd);
        
        // round VSPD on the next 10m/h
        vspd = (Math.round(vspd / 10) * 10).toNumber();
        
       	return vspd;
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
