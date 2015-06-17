//*************************************************************
//assay_control
//robot assisted plate imaging device - RAPID
//By Jürgen Hench & Gabriel Schweighauser
//2015
//*************************************************************

//robot variables
var KARELchangeRegVal="/home/user/applications/RAPID/robot/KARELchangeRegVal.sh";

//register values
var P_TO_A=1;
var P_FROM_A=2;

var X_PLATE=2;
var Y_PLATE=3;
var Z_PLATE=5; 

var VIB_5S=5; //make sure to add this in mainmenu of robots

var TODO=11;


//camera variables
var CAMSERIALS=newArray('B0A8859584994AFFB9EFAF7AB6382F77','B53A9EACCA6A4DAEAFE6E7CD227FC887','1955DD886CB34783993370E6B572FDBA','860869D768724772A766819D1BAD8411');
var CAMBUS=newArray(CAMSERIALS.length);
var PTPCAM="/home/user/applications/RAPID/ptpcam/ptpcam";
var CMD; //used to execute non blocking shell scripts
var CAM;
var DOWNDIR = "/mnt/1TBraid01/imagesets01/20150508_vibassay_continous/dl";
var TARGETDIR;
var SAMPLEID;
var TIMESTAMP;

//assay variables
var TABLEFILENAME="/mnt/1TBraid01/imagesets01/sampleTable.csv";
var CURRENTSAMPLEID;
var CURRENTSAMPLEZEROTIME;
var MAXY=7;
var MAXX=10;
var MAXZ=4; 
var STACKREVERSED = false;
var STACKDURATION = 180;

macro "upload psmag01.lua [u] "{
	initCameras();
	for (i = 0; i < CAMBUS.length; i++){ 
		r = exec("/home/user/applications/RAPID/upload_psmag01_arg.sh", CAMBUS[i]);
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
		for (y=1;y<=maxY;y++){
            if ((y % 2) != 1){
                STACKREVERSED = true; //assay starts with correctly ordered stack            
            } else {
                STACKREVERSED = false;
            }
			for (x=1;x<=maxX;x++){
				while (File.exists("/home/user/pause.txt")==true){
					print("pause active");
					wait(1000);
				}
		        checkCameras(); 
		        processStack(x,y);
			}
		}
		
	}
}

	

macro "execute CMD" {
	r = exec("sh", CMD, CAM, TARGETDIR, SAMPLEID, TIMESTAMP);
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
				r = exec("/home/user/applications/RAPID/ptpcam/rebootCam_arg01.sh", CAMBUS[i]);
		        print(r);
	}
}

function recordAssay(x,y,z){
    //psmag01_arg.sh does everything from recording to downloading and adding sampleID and timestamp
	CMD="/home/user/applications/RAPID/psmag01_arg.sh"; //usage: ./psmag01_arg.sh [cameraBus] [targetDir] [sampleID] [timestamp]
	CAM = CAMBUS[z];
    TARGETDIR = DOWNDIR+toString(TIMESTAMP)+"_"+toString(x)+"_"+toString(y);
	SAMPLEID=CURRENTSAMPLEID+"\n"+CURRENTSAMPLEZEROTIME;

	doCommand("execute CMD"); // ./psmag01_arg.sh CAM TARGETDIR SAMPLEID TIMESTAMP

}

//********************************** robot functions *****************************************
function robotSetRegister(registerNumber,registerValue){
	a=exec(KARELchangeRegVal,registerNumber,registerValue);
	print(a);
}

function processStack(x,y){
	currentStack = parseCsvTable(TABLEFILENAME,x,y); //returns array with plates of stack x,y in the order specified in the table


    
	print("current stack: "+x+","+y);
	if (currentStack[0]!=0){ //0 indicates an empty stack
		robotSetRegister(X_PLATE,x);
		robotSetRegister(Y_PLATE,y);
		//process the stack
		for (z=MAXZ;z>0; z--){ //plates are picked from the top
			robotSetRegister(Z_PLATE,z);
			robotSetRegister(TODO,P_TO_A);
			waitForRobotWhileRunning(); 
		            //start recording
		            TIMESTAMP = parseInt(exec("/home/user/applications/RAPID/robot/unixTime.sh"));	
		            //get current plate ID, check if order is reversed
		             if (STACKREVERSED){
		                z_plate = MAXZ - z_plate; //invert z index if stack is reversed
		              	z_plate += 1;
		             } else {
		                z_plate = z;                
		             }
		           
		            
		            sampleField=split(currentStack[z_plate],"/"); //delimiter between ID and UNIX time
			    if (lengthOf(sampleField)==2){
				CURRENTSAMPLEID=sampleField[0];
				CURRENTSAMPLEZEROTIME=sampleField[1];
			    }
		            	
		            while ("/tmp/busy_"+CAMBUS[z])){
				        wait(5000);
			    }            
		            recordAssay(x,y,z);
				
		
		}

        for (z=MAXZ; z>0;z--){
            //make sure camera has finished before removing the plate
            while (File.exists("/tmp/busy_"+CAMBUS[z])){
                wait(5000);
            }

        	robotSetRegister(Z_PLATE,z);
		robotSetRegister(TODO,P_FROM_A);
		waitForRobotWhileRunning();
            
        }

		
	} else {
		print("waiting "+STACKDURATION+"s.");
		wait(STACKDURATION*1000);
		 	
	}
	print("done with "+CURRENTSAMPLEID);
	print("------------------");
}


function parseCsvTable(tableFileName,x,y){

    linesTable=split(File.openAsString(tableFile),"\n");

    //slice through xy to get arrays of z
    currentStack = newArray(MAXZ);
    for (i=1; i< linesTable.length; i++){ //first line contains header
	    colRaw=split(linesTable[i],"\t");
	    index = ((y-1)*MAXX) + x; 
	    currentStack[i-1] = colRaw[index];	
    }

    for (i=0; i<currentStack.length; i++){
	    print(currentStack[i]);
	
    }
	
    return currentStack; 
    		
}
