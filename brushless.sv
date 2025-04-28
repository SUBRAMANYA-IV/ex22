module brushless(clk, rst_n, drv_mag, hallGrn, hallYlw, hallBlu, brake_n, PWM_synch, duty, selGrn, selYlw, selBlu); 

//define inputs and outputs to module
input clk, rst_n, hallBlu, hallGrn, hallYlw, brake_n, PWM_synch;
input [11:0] drv_mag; 
output [10:0] duty; 
output logic [1:0] selBlu;  //output selection signal to drive blue signal 
output logic [1:0] selYlw;  //output selection signal to drive yellow signal
output logic [1:0] selGrn;  //output selection signal to drive green signal

//intermidiate signals used for metastability of asynch hallBlu, hallGrn, and hallYlw
logic G1,G2;     //intermidiate flopped signals 
logic B1,B2;     //intermidiate flopped signals 
logic Y1,Y2;     //intermidiate flopped signals 
logic synchYlw,synchGrn,synchBlu;  //synchronized signals after going through double flops 

logic [2:0] rotation_state; //will hode encoded state 


//local params for setting coils 
localparam frwd_curr = 2'b10;   //drive coil foward
localparam HIGH_Z = 2'b00;      //set HIGHz on coil
localparam rev_curr = 2'b01;    //drive coil reverse
localparam breaking = 2'b11;    //currently breaking

//double flop incoming asynch signal to avoid metastability
always_ff @(posedge clk) begin 
	if(!rst_n) begin  //on reset clear to known state 
	  G1 <= 0; 
	  B1 <= 0; 
	  Y1 <= 0;
   end else begin 
      G1 <= hallGrn; //double flop incoming asynch signal 
	  B1 <= hallBlu; //double flop incoming asynch signal 
	  Y1 <= hallYlw; //double flop incoming asynch signal 
	  G2 <= G1;
	  B2 <= B1; 
	  Y2 <= Y1;
   end 
end

//update synchronized signals only when PWM_synch is received else maintain its value 
always_ff @(posedge clk) begin 
	if(!rst_n) begin
	 synchYlw <= 0;
	 synchGrn <= 0;
	 synchBlu <= 0;		
   end else if (PWM_synch)begin  //ON PWM_synch pulse update synch signals for blue green and yellow 
     synchYlw <= Y2;
	 synchGrn <= G2;
	 synchBlu <= B2;
   end
end

assign rotation_state = {synchGrn,synchYlw,synchBlu}; //assign rotation state based on synchronized signals 

always_comb begin 

   //brake takes priority (if breaking is low then set status to breaking)
  if(!brake_n) begin 
   selGrn = breaking; 
   selYlw = breaking; 
   selBlu = breaking;    
  end else begin 

   //else if break is not activated find current state and set signals appropiately 
   case(rotation_state) 


      3'b101: begin 
	  //signal set for case 101 
		selGrn = frwd_curr;
		selYlw = rev_curr;
	    selBlu = HIGH_Z; 
      end	 
	  
      3'b100: begin 
	  	  //signal set for case 100 
	   	selGrn = frwd_curr;
		selYlw = HIGH_Z;
	    selBlu = rev_curr; 
	  end
	  
	  3'b110: begin 
	  	  //signal set for case 110 
	  	selGrn = HIGH_Z;
		selYlw = frwd_curr;
	    selBlu = rev_curr;
	  end 
	  
	  3'b010: begin 
	  	  //signal set for case 010
	  	selGrn = rev_curr;
		selYlw = frwd_curr;
	    selBlu = HIGH_Z;	  
	  end 
	  
	  3'b011:  begin 
	  	  //signal set for case 011 
	  	selGrn = rev_curr;
		selYlw = HIGH_Z;
	    selBlu = frwd_curr;
	  end 
	  
	  3'b001: begin 
	  	  //signal set for case 001
	  	selGrn = HIGH_Z;
		selYlw = rev_curr;
	    selBlu = frwd_curr;
      end 
	  
	  //We should not enter this state, if we do all signals will be HIGH_Z
	  default: begin 
	  	selGrn = HIGH_Z;
		selYlw = HIGH_Z;
	    selBlu = HIGH_Z;
	  end 
	endcase  
  end 
end 

//set duty cycle depending if we are currenly breaking or not
assign duty = (brake_n) ? (drv_mag[11:2] + 11'h400) : 11'h600 ;


endmodule