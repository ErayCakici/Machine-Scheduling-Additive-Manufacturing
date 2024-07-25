/*********************************************
 * OPL 20.1.0.0 Model
 * Author: eraycakici
 * Creation Date: Jan 28, 2022 at 10:05:16 PM
 *********************************************/
using CP; 
 
tuple part {
  key string partID;
  int partHeight;
  int partVolume;
  int partArea;
}
{part} Parts = {};

tuple machine {
  key string machineID;
  int VT;
  int HT;
  int SET;
  int MA;
}
{machine} Machines = {};

tuple job {
  key int jobID;  
  float jobMaxHeight;
  float partVolume;
  int partArea;
}
{job} Jobs = {};

execute
{
    {
    var f=new IloOplInputFile("./I39_PartsData.csv");
    var str=f.readline(); // skip first line
    while (!f.eof)
    	{
    		var str=f.readline();
    		if(!(str=="")){
    			var ar=str.split(",");
    			Parts.add(ar[0],ar[1],ar[2],ar[3]);
  			}    
    	}
    f.close();
    }
    
    {
    var f=new IloOplInputFile("./I39_MachinesData.csv");
    var str=f.readline(); // skip first line
    while (!f.eof)
    	{
    		var str=f.readline();
    		if(!(str=="")){
    			var ar=str.split(",");
    			Machines.add(ar[0],ar[1],ar[2],ar[3],ar[4]);
  			}    
    	}
    f.close();
    }
    
    {
    var f=new IloOplInputFile("./I39_PartsData.csv");
    var str=f.readline(); // skip first line
    while (!f.eof)
    	{
    		var str=f.readline();
    		if(!(str=="")){
    			var ar=str.split(",");
    			Jobs.add(ar[0],ar[1],ar[2],ar[3]);
  			}    
    	}
    f.close();
    }
} 

//int VT =  sum(m in Machines) m.VT;  //  minute/cm 3  // Time spent to form per unit volume of material 
//int HT =  sum(m in Machines) m.HT;  //  minute/cm   // Time spent for powder-layering, which is repeated for each layer (based on the highest part produced in the job)
//int SET = sum(m in Machines) m.SET;  //  minute      // Set-up time needed for initialising and cleaning
//int MA = sum(m in Machines) m.MA;    //  cm 2    // The production area of the machine’s tray

int NbJobs = 0;
execute
{   
    for (var p in Parts ) {
      NbJobs = NbJobs +1 
    }
} 
//range Jobs = 1..NbJobs; 


//dvar boolean X[Machines][Jobs][Parts];         //1 if part is assigned to job, 0 o/w
dvar interval itvsX[Machines][Jobs][Parts] optional;          //1 if part is assigned to job, 0 o/w

// introduce decision variables
dvar interval itvs[m in Machines][j in Jobs] optional;

//dvar sequence singlemachine in all(j in Jobs) itvs[j];
dvar sequence mchs[m in Machines] in all(j in Jobs) itvs[m][j];

cumulFunction f[m in Machines] = sum(j in Jobs, p in Parts)pulse(itvsX[m][j][p],p.partArea);  //to be used in batching capacity

execute {
  //cp.param.timelimit = 120;
  //cp.setSearchPhases(cp.factory.searchPhase(X));
}


// minimize makespan
minimize max (m in Machines, j in Jobs)(endOf(itvs[m][j]));

subject to{
    // ensures that each part is assigned to exactly one job
    //forall(p in Parts)
    //  sum(m in Machines, j in Jobs) X[m][j][p] == 1;
      
    forall(p in Parts)
	    sum(m in Machines,j in Jobs) presenceOf(itvsX[m][j][p]) == 1;
	forall(m in Machines,j in Jobs)
        sum(p in Parts) presenceOf(itvsX[m][j][p]) <= 999*presenceOf(itvs[m][j]);   
    forall(j in Jobs)
        sum(m in Machines) presenceOf(itvs[m][j])<= 1;
        
    forall (m in Machines,j in Jobs, p in Parts) 
          synchronize(itvsX[m][j][p],all(m1 in Machines,j1 in Jobs:j1.jobID==j.jobID && m1.machineID==m.machineID)itvs[m][j]);  
    
    // calculate size of the job
    //forall(m in Machines,j in Jobs)
    //  sizeOf(itvs[m][j])== m.SET*presenceOf(itvs[m][j]) + m.VT*sum(p in Parts) p.partVolume*X[m][j][p] + m.HT*max(p in Parts)(p.partHeight*X[m][j][p]);
    forall(m in Machines,j in Jobs)
        sizeOf(itvs[m][j])== m.SET*presenceOf(itvs[m][j]) + m.VT*sum(p in Parts) p.partVolume*presenceOf(itvsX[m][j][p]) + m.HT*max(p in Parts)(p.partHeight*presenceOf(itvsX[m][j][p]));
            
    // area capacity cannot be exceeded and also define Z_j
    //forall(m in Machines,j in Jobs)
    //  sum(p in Parts) X[m][j][p] <= 999*presenceOf(itvs[m][j]); 
      
    // area capacity cannot be exceeded
    //forall(m in Machines,j in Jobs)
    //  sum(p in Parts) p.partArea*X[m][j][p] <= m.MA; 
      
    forall (m in Machines) 
      f[m]<=m.MA;
      
    // No overlap between jobs
    forall (m in Machines) 
      noOverlap(mchs[m]);  
 }

 