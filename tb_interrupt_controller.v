`include "interrupt_controller.v"
module tb;
parameter NUM_PERIPHS=16;  //no. of peripherals
parameter ADDR_WIDTH=$clog2(NUM_PERIPHS);
parameter DATA_WIDTH=$clog2(NUM_PERIPHS);
parameter PERIPH_INDEX=$clog2(NUM_PERIPHS);

reg pclk_i,prst_i,pwrite_i,penable_i;  //pwrite_i will tell what to do o read or write
wire pready_o,perror_o;
reg [ADDR_WIDTH-1:0] paddr_i;  //if there are 16 reg then addr_width should be 4 to show them
reg [DATA_WIDTH-1:0] pwdata_i;
wire [DATA_WIDTH-1:0] prdata_o;

reg intr_serviced_i;
wire intr_valid_o;
reg [NUM_PERIPHS-1:0] intr_active_i;
wire [PERIPH_INDEX-1:0]intr_to_service_o;  //as there are 16 peripherals so 4 bit should be there to tell the processor that this peripheral device is asking for service
interrupt_controller #(.NUM_PERIPHS(NUM_PERIPHS)) dut(pclk_i,prst_i,paddr_i,pwrite_i,pwdata_i,prdata_o,penable_i,pready_o,perror_o,intr_serviced_i,intr_valid_o,intr_to_service_o,intr_active_i);

integer i;


reg [8*30:1] testname;  //this string can  hold up to 25 chars
integer seed;
initial begin
  pclk_i=0;
  forever #5 pclk_i=~pclk_i;
end
initial begin 
  $value$plusargs("testname=%s",testname);
  seed=183932;
  reset_dut();
  //below task fro writing to the priority_regA in the design
  write_priority_regA();
  //below task for reading the priority_regA in the design
  read_priority_regA();  //to confirm if the values are written properly,in this code read is not so imp...write is important
  intr_active_i=$random(seed);  //for randomly generate or raising interrupts or we can say,TB is behvaing like a peripheral controller and raising interrupt
  #500;
  intr_active_i = intr_active_i | $random(seed);   //sbse ques puchne ke baad,agr unke thode bhi ques bch gye h toh uske liye bitwise or kra h
  #500;
  $finish;
end
//this is in separate block bcoz it is forever happening activity
always @(posedge intr_valid_o) begin
   //service interrupt
   #30; //time takes to service the interruot
   intr_active_i[intr_to_service_o]=0;
   intr_serviced_i=1;
   @(posedge pclk_i);
   intr_serviced_i=0;
end

task reset_dut();
begin
  prst_i=1;
  //at reset ,TB will drive design inputs to 0 and DUT Will make design outputs to 0
  //above ensures that all design inputs and outputs are 0 there is no red line
  paddr_i=0;
  pwrite_i=0;
  pwdata_i=0;
  penable_i=0;  //here enable is instead of valid
  intr_active_i=0;
  intr_serviced_i=0;
  @(posedge pclk_i);
  prst_i=0;
end
endtask

//no. of locations is not required like we used in memory,as we will write we write to all registers 
task write_priority_regA();
integer intA[15:0];
integer j,k,num;
reg exists_f;
begin
   //populate intA  this is for random priority
   for (j=0;j<NUM_PERIPHS;) begin
     num=$urandom_range(0,NUM_PERIPHS-1);
	 exists_f=0;
	 for (k=0;k<j;k=k+1) begin
	   if(intA[k] == num) begin
	      exists_f=1;
		  k=j;
		end
	  end
	 if (exists_f==0) begin
	   intA[j] = num;
	   j=j+1;
	 end
   end
	    
   for(i=0;i<NUM_PERIPHS;i=i+1) begin
      @(posedge pclk_i);
	  paddr_i=i;
	  //testcase1=lowest index peripherals has lowestt priority
	         //above is same as highest peripheral has highest priority 0->0,1->1
	  //testcase2=lowest index peripheral has highest priorit 0->16(lowest index has highesht priority)  for this just assign pwrite_i=NUM_PERIPHS-i-1
	  //testcase3=random priority(priority are unique for each peripheral)
	  case (testname) 
	   "test_lowest_peri_low_prio" : pwdata_i=i;   //for testcase1 just use this one,and remove rest of pwdata below
	    "test_lowest_peri_high_prio" :  pwdata_i=NUM_PERIPHS-i-1; //for testcase 2
		"test_random_unique_prio"  : pwdata_i=intA[i];
	  endcase

	  pwrite_i=1;
	  penable_i=1;
	  wait (pready_o==1);
   end
      @(posedge pclk_i);
	  penable_i=0;
	  paddr_i=0;
	  pwdata_i=0;
	  pwrite_i=0;	  
end
endtask

task read_priority_regA();
begin
   for (i=0;i<NUM_PERIPHS;i=i+1) begin
      @(posedge pclk_i);
	  paddr_i=i;
	  pwrite_i=0;
	  penable_i=1;
	  wait (pready_o==1);
   end
     @(posedge pclk_i);
	 penable_i=0;
	 paddr_i=0;
end
endtask
endmodule
