module PID(clk, rst_n, error, not_pedaling, drv_mag);

//Inputs and outputs to module 
input clk, rst_n, not_pedaling;  //clk & rst_n signals, also declaring signal to notify when rider has stopped pedaling 
input signed [12:0] error;       //current error between target current and actual current 
output logic [11:0] drv_mag;     //Output of module from PID terms using error input 

//counter variables 
logic full;             //will go high every 1/48 of a second and allows I & D terms to update 
logic [19:0] decimator; //20 bit counter to approximate 1/48 of a second with a 50 Mhz clk

//sim param used to speed up simulation for testing by reducing counter bit width
parameter FAST_SIM = 1;

//D term 
logic signed [12:0] q1, q2, q3;     //three pipeline flops used to represent derivitive q1 = f(t) q3 = f(t-△t) 
logic signed [12:0] d_diff;         //Holds the term f(t) - f(t-△t) used for dervitive 
logic signed [8:0] saturated_diff;  //saturate 13-bit signal down to 9-bit 
logic signed [9:0] D_term;          //perform signed multiply by 2 to achieve final D-term

//P Term and I term
logic signed [17:0] error_extend;   //will hold sign extended error term 
logic  [17:0] integrator;           //register used to hold sum over time
logic signed  [17:0] new_sum;       //new sum produced from adding current accumalator value to sign extended error 
logic  [17:0] saturate_newSum;      //used to hold saturated value if it went negative 
logic  [17:0] overflow_check;       //used to hold positive overflow value if it occurred (will set to max)
logic  [17:0] error_integrator_sum; //new value to be held in register for integrator 
logic pos_ov;                       //Used to determine if positive overflow occured 

logic [11:0] i_term;                // will hold final I term
logic signed [13:0] p_term;         // will hold final P term 

logic drv_mag1; 

//accumalator flop 
always_ff @(posedge clk, negedge rst_n) begin 
    if(!rst_n) begin
        integrator <= 0;        //reset integrator to 0 on reset
    end else if(not_pedaling) begin 
        integrator <= 0;        //reset integrator to 0 on not pedaling signal 
    end else begin 
        integrator <= error_integrator_sum;
    end     
end

assign error_extend = {{5{error[12]}}, error}; //sign extend error from 13-bit to 18 bits
assign new_sum = integrator + error_extend;    //add new sign extended error to current sum in register
assign saturate_newSum = new_sum[17] ? ( 18'd0 ) : ( new_sum[17:0] );  //check if result end up negative and clip to 0 
assign pos_ov = integrator[16] & new_sum[17];  // condition for positive overflow 
assign overflow_check = pos_ov ? (18'h1FFFF) : (saturate_newSum[17:0]); //if positive overflow occurred set to max positive value 
assign error_integrator_sum = full ? (overflow_check[17:0]) : (integrator[17:0]); //assign new value only on full signal 

assign i_term = integrator[16:5];   //The final I term is the top 12 bits from the integrator 
assign p_term = error_extend[13:0]; //p_term is sign extended error to 14 bits

//D term 
always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin 
        q1 <= 0;     //pipeline flop one 
        q2 <= 0;     //pipeline flop two 
        q3 <= 0;     //pipeline flop three 
    end 
    else if(full) begin 
        q1 <= error;  //on full receive f(t)
        q2 <= q1;
        q3 <= q2;     //3 full cyckles later this is  f(t-△t) 
    end      
end 

assign d_diff = error - q3; //subtract the term f(t) - f(t-△t) used for dervitive
//saturate the result down from 12-bits to 9-bits
assign saturated_diff = d_diff[12] ? ( &d_diff[11:9] ? d_diff[8:0] : 9'b1_0000_0000 ) : (  |d_diff[11:9] ? 9'b011111111 : d_diff[8:0] ); 
assign D_term = saturated_diff <<< 1; //now multiply the result by 2  ( <<< means signed multiply)

//  << Combining the the PID terms together  >>
logic [13:0] PID;
assign PID = p_term + {2'b00, i_term} + {{4{D_term[9]}} ,D_term}; //sum of all terms
assign drv_mag1 = PID[13] ? (12'h000) : (  PID[12]  ? 12'hFFF : PID[11:0] );

always_ff @(posedge clk, negedge rst_n)begin 
	if(!rst_n)
	  drv_mag <= 0;            
    else 
      drv_mag <= drv_mag1;
end 


//General counter that increment unconditionally every clk cycle will be used to generate a full signal periodically
always_ff @(posedge clk or negedge rst_n)  begin 
	if(!rst_n)
	  decimator <= 0;            //reset count to start at 0
    else 
      decimator <= decimator + 1;  	//else continously increment once per clock cycle until count is full                  
end 


//  << This section is used for simulation purposes only >>
generate if (FAST_SIM) 
    assign full = &decimator[14:0];  //during fast simulation reduce bit width of counter 
else
    assign full = &decimator[19:0]; //normal operation timer should be 20-bits
endgenerate



endmodule 
