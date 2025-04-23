//// <CORRECT FILE>
//// <CORRECT FILE>
//// <CORRECT FILE>
module sensorCondition(
    input logic clk, 
    input logic rst_n,
    input logic [11:0] torque,
    input logic cadence_raw,
    input logic signed [11:0] curr,
    input logic [11:0] incline, 
    input logic [2:0] scale,
    input logic [11:0] batt,
    output logic signed [12:0] error,
    output logic not_pedaling,
    output logic TX
);
        
parameter FAST_SIM = 0;

logic [11:0] curr_avg;
logic [11:0] torque_avg;

logic cadence_Sfilt; //filtered cadence signal  
logic cadence_rise;  //
logic candance_per;  //period of filtered candance signal 

//used to detect falling edge on not_pedaling
logic pedaling_resREG;
logic pedaling_resumes; 

logic [4:0] cadence; 

logic signed [11:0] target_curr;

//instantiate cadence filter module to filter raw candence signal 
cadence_filt #(.FAST_SIM(FAST_SIM)) filt1(.clk(clk), .rst_n(rst_n) , .cadence(cadence_raw), .cadence_filt(cadence_Sfilt), .cadence_rise(cadence_rise));
cadence_meas #(.FAST_SIM(FAST_SIM)) meas1( .clk(clk), .rst_n(rst_n), .cadence_filt(cadence_filt), .cadence_per(candance_per), .not_pedaling(not_pedaling));
cadence_LU lu1(.cadence_per(candance_per),.cadence(cadence));

//instantiate telemetry (also contains UART transmitter) ****NEEDS TO FILL IN PARAMS***
telemetry telem1(.clk(clk), .rst_n(rst_n), .batt_v(batt), .avg_curr(curr_avg), .avg_torque(torque_avg), .TX(TX));

//instantiate desired drive to get target_curr ****NEEDS TO FILL IN PARAMS***
desiredDrive drive1(.not_pedaling(not_pedaling), .avg_torque(torque_avg), .cadence(cadence), .incline(incline), .scale(scale), .target_curr(target_curr));

//falling edge detector for not_pedaling
always_ff @(posedge clk or negedge rst_n) begin 
    if(!rst_n)
        pedaling_resREG <= 0; 
    else 
        pedaling_resREG <=not_pedaling;    
end 

//falling edge on not_pedaling
assign pedaling_resumes = ~not_pedaling & pedaling_resREG; 

//<siganls used for current exponential average>
logic [13:0] current_accum; 
logic [13:0] newC_accum; 

logic  include_smpl; 

logic [22:0] tmr_c;  

//determine when timer is full 
generate if (FAST_SIM) 
    assign include_smpl = &tmr_c[16:0];  //during fast simulation reduce bit width of counter 
else
    assign include_smpl = &tmr_c;
endgenerate


//free running timer for current samples
always_ff @(posedge clk or negedge rst_n)begin 
    if(!rst_n)
        tmr_c <= 0; 
    else 
        tmr_c <= tmr_c +1;     
end 


//current exponential running average 
always_ff @(posedge clk or negedge rst_n)begin 
    if(!rst_n)
       current_accum <= 0;
    else if(include_smpl)  
      current_accum <= newC_accum;
end 

assign newC_accum = ((current_accum * 3) >>> 2) + curr;  //formula for exponential running average 
assign curr_avg = current_accum[13:2]; //average is current accum / 4

//<siganls used for torque exponential average>
logic [16:0] torque_accum; 
logic [16:0] newT_accum;


//current exponential running average 
always_ff @(posedge clk or negedge rst_n) begin 
    if(!rst_n)
        torque_accum <= 0;
    else if(pedaling_resumes)  
        torque_accum <= {1'b0,torque, 4'b0000};
    else if(cadence_rise)
        torque_accum <= newT_accum;
end

//formula for torque running average 
assign newT_accum = ((torque_accum * 31) / 32) + torque;
assign torque_avg = torque_accum[16:5];


assign error = target_curr - curr_avg;


endmodule



module cadence_meas(
    input clk,
    input rst_n,
    input cadence_filt,
    output logic [8:0] cadence_per,
    output logic not_pedaling
);

//FAST SIM logic that was provided
localparam THIRD_SEC_REAL = 24'hE4E1C0;
localparam THIRD_SEC_FAST = 24'h007271;
localparam THIRD_SEC_UPPER = 8'hE4;

parameter FAST_SIM = 0;
logic cadence_rise;
logic [23:0] THIRD_SEC;

generate if (FAST_SIM)
   assign THIRD_SEC = THIRD_SEC_FAST;
else
   assign THIRD_SEC = THIRD_SEC_REAL;
endgenerate

logic capture_per;
logic third_sec_equals;
logic [23:0] third_sec_cnt;



//equals block for THIRD_SEC
always_comb begin
    if (third_sec_cnt == THIRD_SEC) begin
        third_sec_equals = 1'b1;
    end else begin
        third_sec_equals = 1'b0;
    end
end

//assign capture_per
assign capture_per = third_sec_equals || cadence_rise;


//assign third_sec_cnt (value stored in first flop)
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) 
        third_sec_cnt <= 24'h0;
    else if (cadence_rise) 
        third_sec_cnt <= 24'h0;
    else if (!third_sec_equals) 
        third_sec_cnt <= third_sec_cnt + 1;
    else
        third_sec_cnt <= third_sec_cnt;
end
    

// rising edge detection for cadence filt

logic rise_reg;

always@(posedge clk, negedge rst_n)begin
    if(!rst_n)
        rise_reg<=1'b0;
    else 
        rise_reg<=cadence_filt;
end

assign cadence_rise = rise_reg &~ cadence_filt;


//on the rising edge of cadence_filt, a 24 bit timer is cleared,
//BUT its upper 8 bits are captured (or bits [14:7) if FAST_SIM)
//are captured in an 8 bit register that forms cadence_per


/*
If the 24-bit timer gets to THIRD_SEC then the timer is frozen at that value and the value is
captured in the 8-bit cadence_per register. If this value equals THIRD_SEC_UPPER then
the not_pedaling signal is asserted (if no pulses were recorded in 1/3 of second then it is
assumed the rider is not pedaling).
*/

/*
A parameter FAST_SIM is used for accelerated simulations and significantly shortens both
the 1/3 second period (THIRD_SEC) and also grabs lower bits (14:7]) of the 24-bit counter
to serve as cadence_per.
• cadence_per register resets to THIRD_SEC_UPPER so that we reset to a “not_pedaling”
scenario.
*/


//8 bit register that holes value of "cadence_per"
//NOTE: CADENCE_PER HAS A SYNCHRONOUS RESET?!
//STAGE 1 ASYNCH RESET. 
//should values out of fastsim?
logic [23:0] threeSecTimer;

logic [7:0] stage_1_output = (FAST_SIM) ? threeSecTimer[14:7] : threeSecTimer[23:16];


always@(posedge clk, negedge rst_n) begin
    //check for syncrhonous reset?
    if (!rst_n) begin
        threeSecTimer <= 24'b0;
    end

    else begin
        //if the rising edge is true, load either bits [23:16] if FAST_SIM is false,
        //bits [14:7] if FAST_SIM is true. 

        //if THIRD_SEC is true, then freeze the clock
        if (cadence_rise) 
            threeSecTimer <= 24'b0;

        else if(threeSecTimer == THIRD_SEC) 
            threeSecTimer <= threeSecTimer;

        else 
            threeSecTimer <= threeSecTimer + 1;
        
        //if the 24 bit timer gets to THIRD_SEC, then timer is frozen
        //at that value and the value is captured in the 8-bit cadence_per registe
    end
end

//STAGE 2 SYNCRHONOUS BLOCK
logic [7:0] stg2Input;

assign not_pedaling = (cadence_per == THIRD_SEC_UPPER);
assign stg2Input = FAST_SIM ? (threeSecTimer[14:7]) : (threeSecTimer[23:16]);

logic [7:0] cadence_per_input;
always_comb begin
    if(!rst_n) begin
        cadence_per_input = THIRD_SEC_UPPER;
    end else begin
        if(capture_per) 
            cadence_per_input=stg2Input;
        else 
            cadence_per_input=cadence_per;
    end
end

always@(posedge clk)begin
    cadence_per <= cadence_per_input;
end


endmodule