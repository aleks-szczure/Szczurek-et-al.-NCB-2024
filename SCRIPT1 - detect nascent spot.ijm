//Runs SpotDetector on all .tiff single-cell MS2x128 movies in an indicated directory 04/02/2020 
//          + corrected bug where 3D-OC results table is closed prior to .csv file being saved (01-2024)
//          + correct iteratori in line 88 from 1 to 0 to count all 120 frames and not 119! (1-2024)
//input: 1 directory with single cell (alelle) movies in .tif format
//         Caution: change the frame number to the right one (line 76)
//                  Threshold of 15 int. a.u. (line 79) and spot size 10-250 find spots well, 04.02.2020 - bug here fixed
//                  change time interval (x) to desired, e.g. 4min (line 86)
//output: sc directories containing single cell movies together with spot intensities in each timepoint (one .csv file
//        per timepoint (an input to R-LongMoviesAnalysis.Rmd)
//        Modification 06-Feb-2020 - immediately closes 3D-OC results so that no windows are left in the display! TESTED
//        Displaying too many windows significantly slows down Fiji and this problem is gone here!

// 1) HERE SINGLE MOVIES SHOULD BE DEPOSITED INTO SINGLE FOLDERS 
//   add here a chunk of code for all images to folders
////////////////////////////////////////////////////////////////
close("*");
inputFolder = getDirectory("D:/Aleksander/2018.07.19 RING1B-A488 uH2-A594 DAPI/"); // Diretory with .tif single cell movies 
listFiles = getFileList(inputFolder);

setBatchMode(true); 
for (n = 0; n < listFiles.length; n++){  // n corresponds to image number
	if(endsWith(listFiles[n],".tif")){  //Condition to process only the main iamge not resulting images, works well
		newDir = inputFolder + listFiles[n];
		folderName = substring(listFiles[n],0,lengthOf(listFiles[n])-4); //cuts 23 ".tifMax_TRITC_C0003.tif" //for DAPI 28 ".tif_Averaged_DAPI_C0001.tif"
		File.makeDirectory(inputFolder+folderName); //until here it makes a folder per .tiff file correctly
		outputPath = inputFolder+folderName;
		open(inputFolder + listFiles[n]); image=getTitle();
		imgName_Final=getTitle();
		print(imgName_Final);
		saveAs("Tiff",  outputPath +"\\" +listFiles[n]);
		close(image);
		wait(500);
	}
}
setBatchMode(false);



// 2) AND DELETED FROM ORIGINAL LOCATION (SHOULD WORK!)
//go to singlecellmasks and delete any .tif images to avoid problem with data calling by script #2
///////////////////////////////////////////////////////
wait(500);
setBatchMode(true); 
	for (n = 0; n < listFiles.length; n++){  
		if(endsWith(listFiles[n],".tif")){
			File.delete(inputFolder + listFiles[n]);   // here deletes .tif files from the original dir as they're already in folder
		}}
setBatchMode(false); 

// loop that closes all open windows to avoid confusion at the next steps:
listWin = getList("window.titles"); setBatchMode(true);
     for (j=0; j<listWin.length; j++){
     winame = listWin[j];
      selectWindow(winame);
     run("Close");
     } setBatchMode(false);




// 3) DEFINE FUNCTION SpotDetector
//////////////////////////////////
wait(500);
function SpotDetector(input){
//input = getDirectory("D:/Aleksander/2018.07.19 RING1B-A488 uH2-A594 DAPI/"); // Dir 
list = getFileList(input);
for (m=0; m<list.length; m++){ // loop to find .tif file in directory
if (endsWith(list[m], ".tif")){open(input+list[m]);}} 

stack=getTitle();
getDimensions(width, height, channels, slices, frames);
print(frames);
run("Subtract Background...", "rolling=5 stack"); selectWindow(stack);
//run("Median...", "radius=1 stack"); // median filter?


// 3D Objects counter - loop through 3D-timepoints
setBatchMode(true); ////////////////////////////////////////
for (i = 1; i < frames; i++) {   // (01-2024)-here change i to 0 instead of 1 to fix the bug of having 119 isntead of 120 .csv files
	//print(i); // if you experience .csv file drop out uncomment this - it will massively slow down processing but will fix the problem
	run("Make Substack...", "slices=1-20 frames="+i); // <<<<< INTRODUCE RIGHT FRAME NUMBER!
	deltaT=getTitle(); selectWindow(deltaT);
	run("Subtract...", "value=10 stack"); // Careful with lowly expressed 11-2023! Changed location of this line 04-Feb-2020, tested and work exactly the same but never crashes!
	
		
	fileCount=getFileList(input); // here count .csv files in the single-cell directory prior to running 3D-OC
	getStatistics(area, mean, min, max, std, histogram);
	if (max < 15) threshold = max; 
  	else threshold = 15;
  		//run("Subtract...", "value=10 stack"); //subtract background - additional 17/12 - BUT it is in wrong location!!!! 04-Feb-2020
		run("3D Objects Counter", "threshold=" + threshold +" slice=1 min.=10 max.=250 statistics"); //dont exclude objects on edges!	min 30 better!
		// Use low threshold but also measure center of gravity. Then make a program in R that'd stitch signals to respective lcoations	
		//alternatively use Foci Picker?
		x=i*4; //frame in minutes
		//saveAs("txt",input+i+"_frame_"+x+"min"); close("statistics");  // TXT
		saveAs("Results",input+i+"_frame_"+x+"min.csv"); wait(100); // waiting helps to give time to save! 11-2023 bug
		//close("statistics");  // CSV
       
              
            // (01-2024) - Initiate a lopp to test if a .csv file with results of 3D-OC was saved
			for (g=0; g<1000; g++){
		    fileCount2=getFileList(input); // count no. .csv files in the directory again after runnig 3-OC to test if .csv file was successfully saved
			if (fileCount2.length == fileCount.length) {wait(1000); saveAs("Results",input+i+"_frame_"+x+"min.csv"); print(g);}else{break}	// if saving failed, rerun it!		
			}
            
		    if (fileCount2.length>fileCount.length){ //if the .csv file was successfully saved close the 3D-OC results table!
        	listWin = getList("window.titles"); setBatchMode(true);
        	for (j=0; j<listWin.length; j++){
        	winame = listWin[j];
        	selectWindow(winame);
        	run("Close");
        	} setBatchMode(false);}

		
		close(deltaT);

		
		selectWindow(stack); 
	} setBatchMode(false);
close(stack);
}



// 4. Run a function SpotDetector on each subdirectory
////////////////////////////////////////////////////////
listFiles = getFileList(inputFolder); // updates the list

for (k = 0; k < listFiles.length; k++) { //loop over subdirs
	print(inputFolder+listFiles[k]);
	print(listFiles.length);

	SpotDetector(inputFolder+listFiles[k]);
// (1-2024) - if a lot of .csv drop out move the loop that clsoes the 3D-OC results section here and close all 120 tables one after another

} 

