/*********************************************
 * OPL 20.1.0.0 Model
 * Author: eraycakici
 * Creation Date: Jan 27, 2022 at 3:39:20 PM
 *********************************************/
using CP; 
 
tuple part {
  key string partID;
  float partHeight;
  float partVolume;
  float partArea;
}
{part} Parts = {};

tuple machine {
  key string machineID;
  int VT;
  int HT;
  int ST;
  int A;
}
{machine} Machines = {};



execute
{
    {
    var f=new IloOplInputFile("./I15_PartsData.csv");
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
    var f=new IloOplInputFile("./I15_MachinesData.csv");
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
} 

int VT =  sum(m in Machines) m.VT;  //  minute/cm 3  // Time spent to form per unit volume of material 
int HT =  sum(m in Machines) m.HT;  //  minute/cm   // Time spent for powder-layering, which is repeated for each layer (based on the highest part produced in the job)
int SET = sum(m in Machines) m.ST;  //  minute      // Set-up time needed for initialising and cleaning
int MA = sum(m in Machines) m.A;    //  cm 2    // The production area of the machine’s tray

int NbJobs = 0;
execute
{   
    for (var p in Parts ) {
      NbJobs = NbJobs +1 
    }
} 
range Jobs = 1..NbJobs; 


dvar boolean X[Jobs][Parts];         //1 if part is assigned to job, 0 o/w

// introduce decision variables
dvar interval itvs[j in Jobs] optional;

dvar sequence singlemachine in all(j in Jobs) itvs[j];

execute {
  cp.param.timelimit = 300;
  cp.setSearchPhases(cp.factory.searchPhase(X));
}


// minimize makespan
minimize max (j in Jobs)(endOf(itvs[j]));

subject to{
    // ensures that each part is assigned to exactly one job
    forall(p in Parts)
      sum(j in Jobs) X[j][p] == 1;
    
    // ensures that each part is assigned to exactly one job
    forall(j in Jobs)
      sizeOf(itvs[j])== SET*presenceOf(itvs[j]) + VT* sum(p in Parts) p.partVolume*X[j][p] + HT*max(p in Parts)(p.partHeight*X[j][p]);
      
    // area capacity cannot be exceeded and also define Z_j
    forall(j in Jobs)
      sum(p in Parts) X[j][p] <= 999*presenceOf(itvs[j]); 
      
    // area capacity cannot be exceeded
    forall(j in Jobs)
      sum(p in Parts) p.partArea*X[j][p] <= MA; 
      
    // No overlap between jobs
    noOverlap(singlemachine); 
 }