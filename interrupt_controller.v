module interrupt_controller(
//processor=APB+some interrupt signals
pclk_i,prst_i,paddr_i,pwrite_i,pwdata_i,prdata_o,penable_i,pready_o,perror_o,intr_serviced_i,intr_valid_o,intr_to_service_o,
//peripheral controller interfaces
intr_active_i
);
parameter NUM_PERIPHS=16;  //no. of peripherals
parameter ADDR_WIDTH=$clog2(NUM_PERIPHS);
parameter DATA_WIDTH=$clog2(NUM_PERIPHS);
parameter PERIPH_INDEX=$clog2(NUM_PERIPHS);
parameter S_IDLE=3'b001;
parameter S_GOT_INTR_GIVEN_TO_PROC=3'b010;
parameter S_WAITING_FOR_INTR_TO_SERVICE=3'b100;

input pclk_i,prst_i,pwrite_i,penable_i;  //pwrite_i will tell what to do read or write
output reg pready_o,perror_o;
input [ADDR_WIDTH-1:0] paddr_i;  //if there are 16 reg then addr_width should be 4 to show them
input [DATA_WIDTH-1:0] pwdata_i;    
output reg [DATA_WIDTH-1:0] prdata_o;

input intr_serviced_i;
output reg intr_valid_o;
input [NUM_PERIPHS-1:0]intr_active_i;
integer i;
reg [2:0]state,next_state;
output reg [PERIPH_INDEX-1:0]intr_to_service_o; //as there are 16 peripherals so 4 bit should be there to tell the processor that this peripheral device is asking for service

//registers
reg [PERIPH_INDEX-1:0] priority_regA[NUM_PERIPHS-1:0];
reg first_match_f;
reg [PERIPH_INDEX-1:0] intr_with_highest_priority;
reg [PERIPH_INDEX-1:0] current_highest_priority;
 
//programming the registers by writing and reading interrupts in/from priority register 
always @(posedge pclk_i) begin
if (prst_i==1) begin
    pready_o=0;
	perror_o=0;
	prdata_o=0;
	intr_valid_o=0;
	first_match_f=1;
	intr_with_highest_priority=0;
	current_highest_priority=0;
	intr_to_service_o=0;
	state=S_IDLE;
	next_state=S_IDLE;
	for (i=0;i<NUM_PERIPHS;i=i+1)begin
	    priority_regA[i]=0;
	end
end
else begin
   //valid tx?
       //write or read?
	      
   if (penable_i==1)begin   //in this code penable is same as valid was there in the memory
      pready_o=1;
      if (pwrite_i==1)begin  //in this code pwrite is same as wr_rd was therer in the memory
	     for (i=0;i<NUM_PERIPHS;i=i+1) begin
		 priority_regA[paddr_i]=pwdata_i;
	     end
	  end
	  else begin
	     prdata_o=priority_regA[paddr_i];
	  end
   end
   else begin
      pready_o=0;
   end
end
end

//implement the logic for handling the interrupts in design
//state diagram
    //S_IDLE
	//S_GOT_INTR_GIVEN_TO_PROC
	//S_WAITING_FOR_INTR_TO_SERVICE
	always @(posedge pclk_i)begin
	   if (prst_i==0) begin
	   case(state)
	   
	      S_IDLE : begin
		    if (intr_active_i !=0 )begin
			  next_state=S_GOT_INTR_GIVEN_TO_PROC;
			  first_match_f=1;
			  //current_highest_priority=0  //this is the second method if we
			  //don't use first match flag(refer nb)
			end	
		  end
         S_GOT_INTR_GIVEN_TO_PROC : begin
		   //find the highest priority peripheral among all active interrupt(iss state ka yeh kaam h)
		    for (i=0;i<NUM_PERIPHS;i=i+1) begin
			    if (intr_active_i[i]==1) begin  //if the interrupt is active then only  consider it
				    if (first_match_f==1) begin
					   first_match_f=0;
					   current_highest_priority=priority_regA[i];   //priority of current peripheral device in register
					   intr_with_highest_priority=i;	//peripheral device interrupt or simple interrupt		
					end
					else begin
					   if (current_highest_priority<priority_regA[i]) begin
					   current_highest_priority=priority_regA[i]; 
					   intr_with_highest_priority=i;		
					   end
					end
				end
			end
			intr_to_service_o=intr_with_highest_priority;   //interrupt controller to processor
			intr_valid_o=1;                                //interrupt controller telling processor that this is valid
			next_state=S_WAITING_FOR_INTR_TO_SERVICE;
		 end
		 S_WAITING_FOR_INTR_TO_SERVICE : begin
		    if (intr_serviced_i==1) begin  //processor telling it have serviced the interrupt
				 current_highest_priority=0;
				 intr_to_service_o=0;
				 intr_valid_o=0;
			  if (intr_active_i!=0) begin
			     next_state=S_GOT_INTR_GIVEN_TO_PROC;
				 first_match_f=1;   //after reaching the last stage now we already got the highest priority ,so no need to compare it with others so reset the first match,current highest priority and valid and int_to_service
			  end
			  else begin
		       	 next_state=S_IDLE;
			   end
			  end
			  else next_state=S_WAITING_FOR_INTR_TO_SERVICE;
	      end
	   
	   endcase
	   end
	   end
always @(next_state) state=next_state;	
endmodule

