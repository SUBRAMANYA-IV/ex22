module cadence_filt(clk, rst_n ,cadence, cadence_filt, cadence_rise );

input clk;
input rst_n;
input cadence;
output logic cadence_filt;
output logic cadence_rise;

parameter FAST_SIM = 1;

logic q1;//output of first flop and input to second flop
logic q2;//output of second flop
logic q3;//output of third flop 

logic [15:0] stbl_count; //16 bit timer about ~1ms
logic full; //timer full signal


logic changed_n;//will detect low->high change or high->low change in signal


//double flop to stablize signal 
always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q1 <= 1'b0;
            q2 <= 1'b0;
      end else begin
            q1 <= cadence;
            q2 <= q1;
     end
end

//used to detect change in signal 
always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q3 <= 1'b0;
      end else begin
            q3 <= q2;
     end
end

//counter logic flip flop 
always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
		     //reset count
            stbl_count <= 1'b0;
      end else begin
             stbl_count <= (stbl_count+1) & {16{changed_n}}; //increment counter 
     end
end


//start of combination logic 
always_comb begin 
//checks for rising edge 
cadence_rise = q2 & (~q3);
//check for signal transition low to high or high to low 
changed_n = ~(q2 ^ q3);  //correct???? or (q2 ^ q3)
end


//final flip flop will check if timer is full then sample the candance signal
always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cadence_filt <= 1'b0; //if reset 
      end else if(full) begin
            cadence_filt <= q3; //when timer is full sample candance 
      end else begin
	       //else cycle the same signal
	       cadence_filt <= cadence_filt; 
	end
end


//  << This section is used for simulation purposes only >>
generate if (FAST_SIM) 
    assign full = &stbl_count[8:0];  //during fast simulation reduce bit width of counter 
else
    assign full = &stbl_count[15:0]; //normal operation timer should be 20-bits
endgenerate



endmodule