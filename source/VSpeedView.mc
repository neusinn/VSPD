using Toybox.WatchUi;
using Toybox.Activity;
using Toybox.Math;
using Toybox.FitContributor;

/*
	Simple datafield for vertical speed (VSPD) based on local barometric pressure.
	
	Variometer also known as: rate of climb and descent indicator (RCDI), rate-of-climb indicator, 
	vertical speed indicator (VSI), vertical velocity indicator (VVI).
	
    As datasource the ambient (local) barometric pressure as measured by the pressure sensor will be used. 
    This source data is already smoothed by a two-stage filter to reduce noise and instantaneous variation.
    
    This algorithm will smoothe height by a Exponentially Weighted Moving Average (EWMA) filter with factor a = 0.2 of the newest measurement.
    The vertical speed calculated over a 20 second time period and is rounded on 10 m/h.
*/
class VSpeedView extends WatchUi.SimpleDataField {

	// interval in seconds to calculate speed
	const intervalInSec = 20;
	const queueSize = intervalInSec;
	const factorEWMA = 0.2;
	
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
		
		if (p == null) { return "--"; }

		var time = Time.now();
		var height = calcHeightFromPressure(p);	

		// Exponentially Weighted Moving Average (EWMA)
		var lastEntry = readLastEntryFromQueue();
		if (lastEntry != null) { 
			height = factorEWMA * height + (1 - factorEWMA) * readLastEntryFromQueue()[:height];
			}
        
        var dataPoint = fifoQueue({ :time=>time, :height=>height });
		if (dataPoint == null) { return 0; } // handle start condition.
		
		// vspd = (h - h0) / (t - t0)
        var vspd = (height - dataPoint[:height]) / (time.subtract(dataPoint[:time]).value()) * 3600;
        
        // DEBUG logData(info, vspd, height, height - dataPoint[:height], time.subtract(dataPoint[:time]).value());
        
        // round VSPD on the next 10m/h
        vspd = (Math.round(vspd / 10) * 10).toNumber();
        
        // write vvspdField to activity reccord
        vspdField.setData(vspd);
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
    
    
    function fifoQueue(in) { 
        idx += 1;
        if (idx == queueSize) { idx = 0; }  
        
        var out = queue[idx];
        queue[idx] = in;
        return out;
    }
    
    function readLastEntryFromQueue() {   
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
