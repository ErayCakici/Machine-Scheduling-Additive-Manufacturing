/*********************************************
 * OPL 20.1.0.0 Model
 * Author: eraycakici
 * Creation Date: Feb 1, 2022 at 1:14:54 PM
 *********************************************/

tuple part {
  key string partID;
  float partHeight;
  float partVolume;
  float partArea;
}
{part} Parts = {};

tuple machine {
  key string machineID;
  float VT;
  float HT;
  float SET;
  float MA;
}
{machine} Machines = {};


execute
{
    {
    var f=new IloOplInputFile("./I63_PartsData.csv");
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
    var f=new IloOplInputFile("./I63_MachinesData.csv");
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

//int VT[Machines] =  sum(m in [Jobs]) m.VT;  //  minute/cm 3  // Time spent to form per unit volume of material 
//int HT =  sum(m in Machines) m.HT;  //  minute/cm   // Time spent for powder-layering, which is repeated for each layer (based on the highest part produced in the job)
//int SET = sum(m in Machines) m.ST;  //  minute      // Set-up time needed for initialising and cleaning
//int MA = sum(m in Machines) m.A;    //  cm 2    // The production area of the machine’s tray

int MH = 40;    //  cm    // Max height

int NbJobs = 0;
execute
{   
    for (var p in Parts ) {
      NbJobs = NbJobs +1 
    }
    //NbJobs = 3;
} 
range Jobs = 1..NbJobs; 

dvar float+ processingTime[Machines][Jobs];    //processing time of jobs at machines
dvar float+ completionTime[Machines][Jobs];    //completion time of jobs at machines
dvar boolean X[Machines][Jobs][Parts];         //1 if part is assigned to job, 0 o/w
dvar boolean Z[Machines][Jobs];                //1 if any part is assigned to job, 0 o/w 

execute {
//  cplex.tilim = 120;
}

// minimize makespan
minimize max (m in Machines,j in Jobs)(completionTime[m][j]);

subject to{
    
    // ensures that each part is assigned to exactly one job at a machine
    forall(p in Parts)
      sum(m in Machines,j in Jobs) X[m][j][p] == 1; 
      
    // area capacity cannot be exceeded and also define Z_j
    forall(m in Machines,j in Jobs)
      sum(p in Parts) p.partArea*X[m][j][p] <= m.MA*Z[m][j]; 
      
    // jobs are utilised in an incremental order starting from job 1
    forall(m in Machines,j in Jobs:j<=NbJobs-1)
      sum(p in Parts) X[m][j+1][p] <= 999*sum(p in Parts) X[m][j][p];   
      
    // calculate completion times
    forall(m in Machines)
      processingTime[m][1]<=completionTime[m][1];
    
    forall(m in Machines,j in Jobs:j>=2)
      completionTime[m][j-1] + processingTime[m][j] <= completionTime[m][j] ; 
      
    // calculate processing times
    forall(m in Machines,j in Jobs)
      processingTime[m][j] == m.SET*Z[m][j] + m.VT* sum(p in Parts) p.partVolume*X[m][j][p] + m.HT*max(p in Parts)(p.partHeight*X[m][j][p]); 
      
    // max height cannot be exceeded
    forall(m in Machines,j in Jobs, p in Parts)
      p.partHeight*X[m][j][p] <= MH; 

 }

 