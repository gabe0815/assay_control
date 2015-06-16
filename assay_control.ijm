//*************************************************************
//assay_control
//robot assisted plate imaging device - RAPID
//By Jürgen Hench & Gabriel Schweighauser
//2015
//*************************************************************

//robot variables
var KARELchangeRegVal="/home/user/fanucrobot/KARELchangeRegVal.sh";

//register values
var P_TO_A=1;
var P_FROM_A=2;

var X_PLATE=2;
var Y_PLATE=3;
var Z_PLATE= ;

var VIB_5S=5;

var TODO=11;


//camera variables
var CAMSERIALS=newArray('B0A8859584994AFFB9EFAF7AB6382F77','B53A9EACCA6A4DAEAFE6E7CD227FC887','1955DD886CB34783993370E6B572FDBA','860869D768724772A766819D1BAD8411');
var CAMBUS=newArray(CAMSERIALS.length);
var PTPCAM="/home/user/applications/ptpcam/ptpcam";
var CMD; //used to execute non blocking shell scripts
var CAM;
var DOWNDIR = "/mnt/1TBraid01/imagesets01/20150508_vibassay_continous/dl"

macro "upload psmag01.lua [u] "{
	initCameras();
	for (i = 0; i < CAMBUS.length; i++){ 
		r = exec("/home/user/fanucrobot/upload_psmag01_arg.sh", CAMBUS[i]);
		print(r);
	}

}
macro "init cameras [i]"{
	initCameras();
	
}

macro "check cameras [c]"{
	checkCameras();
	
}
macro "reboot [r]"{
	initCameras();
	rebootCameras();
	
}
macro "start recording [s] "{
	initCameras();
	checkCameras(); //resets and re-initializes cameras in case of failure
	
	while(true){
	t = parseInt(exec("/home/user/fanucrobot/unixTime.sh"));
		for (y=1;y<=maxY;y++){
			for (x=1;x<=maxX;x++){
				while (File.exists("/home/user/pause.txt")==true){
					print("pause active");
					wait(1000);
				}
				processStack(t,x,y);
			}
		}
		
	}
}

	

macro "execute CMD" {
	r = exec("sh", CMD, CAM);
	//print(r);
}

//*************************************Camera functions******************************************************************

function initCameras() {
	//get bus of each camera to adress them separately
	CAMBUS=newArray(CAMSERIALS.length); //to reset the array, otherwise the error handling does not work as an invalid adress will still be present
	vendor="0x314F";
	
	r = exec(PTPCAM, "-l");
	lines=split(r, "\n");
	
	for (i=0; i < lines.length; i++){
		if (indexOf(lines[i], vendor) != -1) {
			field = indexOf(lines[i], "/");
			bus = substring(lines[i], field+1, field +4) ;
			device = "--dev=" + bus;
			camID = exec(PTPCAM, device, "-i");
			for (j=0; j < CAMSERIALS.length; j++){
				if (indexOf(camID, CAMSERIALS[j]) != -1){
					CAMBUS[j] = bus;
	
				}
				
			}
			
			
		}
	}
	
	for (i=0; i<CAMBUS.length; i++){
		print("CAM_"+i+" = " + CAMBUS[i]);
		if (CAMBUS[i] == 0){
			print("camera "+i+" could not connect...");
			break;

		} else {
			//print("sucess!");

		}
	}	

	
	
}

function checkCameras(){
	//check if all cameras are still present
	print("checking if all cameras present");
	vendor="0x314F";
	r = exec(PTPCAM, "-l");
	lines=split(r, "\n");
	numCameras = 0;
	for (i=0; i<lines.length; i++){
		if (indexOf(lines[i], vendor) != -1) {
			numCameras++;
		}
		
	}
	if (numCameras != CAMBUS.length){
		//reset cameras
		robotSetRegister(TODO,VIB_5S);
		
		//remove old lock files
		files = getFileList("/tmp/");
		for (i=0; i<files.length; i++){
			if (indexOf("/tmp/"+files[i], "busy_") != -1){
				File.delete("/tmp/"+files[i]);
				//print("/tmp/"+files[i]);
			}
		}
		//re-initialize cameras after resetting
		initCameras();
	}
	
}


function rebootCameras(){
	//only reboot if cameras ar "free", busy.lck is touched/removed in shell script. NOTE there is a seperate lock file for each camera.
	
	do {
	        lock = false;        
	        for (k=0; k<CAMBUS.length; k++){
	            if (File.exists("/tmp/busy_"+CAMBUS[k] + ".lck")){
	                lock = true;            
	            }        
	        }
			wait(5000);	
	} while (lock);
	
	print("rebooting cameras ...");
	for (i = 0; i < CAMBUS.length; i++){ 
				r = exec("/home/user/fanucrobot/rebootCam_arg01.sh", CAMBUS[i]);
		        print(r);
	}
}

function recordAssay(x,y,z,camera,timestamp){
    //psmag01_arg.sh does everything from recording to downloading and adding sampleID and timestamp
	CMD="/home/user/fanucrobot/psmag01_arg.sh"; //add args for targetdir, sampleID, x, y, z
	CAM = CAMBUS[j];
    targetDir = DOWNDIR+toString(t)+"_"+toString(x)+"_"+toString(y);
	sampleID=currentSampleID+"\n"+currentSampleZeroTime;	

    lock = "/tmp/busy_"+CAMBUS[j]+".lck";
	while (File.exists(lock)){
		wait(5000);
	}
	doCommand("execute CMD");

}

//********************************** robot functions *****************************************
function robotSetRegister(registerNumber,registerValue){
	a=exec(KARELchangeRegVal,registerNumber,registerValue);
	print(a);
}

function processStack(t,x,y){
	parseCsvTable(tableFileName,x,y);
	print("current plate: "+x+","+y+" = "+currentSampleID+" started at "+currentSampleZeroTime);
	if (currentSampleID!="undefined"){
		robotSetRegister(X_PLATE,x);
		robotSetRegister(Y_PLATE,y);
		//process the stack
		for (z=num_layers;z>0; z--){ //plates are picked from the top
			robotSetRegister(Z_PLATE,z);
			robotSetRegister(TODO,P_TO_A);
			waitForRobotWhileRunning(); 
            //start recording
            recordAssay(x,y,z,CAM,timestamp)
		
		
		}

		
	}else{
		print("waiting "+onePlateDuration+"s.");
		wait(onePlateDuration*1000);
		 	
	}
	print("done with "+currentSampleID);
	print("------------------");
}