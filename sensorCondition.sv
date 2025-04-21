//// <CORRECT FILE>
//// <CORRECT FILE>
//// <CORRECT FILE>
module sensorCondition(
    input logic clk, 
    input logic rst_n,
    input logic [11:0] torque,
    input logic cadence_raw,
    input logic [11:0] curr,
    input logic [11:0] incline, 
    input logic [2:0] scale,
    input logic [11:0] batt,
    output logic [12:0] error,
    output logic not_pedaling,
    output logic TX
);
        
logic cadence_Sfilt; //filtered cadence signal  
logic cadence_rise;  //
logic candance_per;  //period of filtered candance signal 

//used to detect falling edge on not_pedaling
logic pedaling_resREG;
logic pedaling_resumes; 

logic [4:0] cadence; 

//instantiate cadence filter module to filter raw candence signal 
cadence_filt filt1(.clk(clk), .rst_n(rst_n) , .cadence(cadence_raw), .cadence_filt(cadence_Sfilt), .cadence_rise(cadence_rise));
cadence_meas meas1( .clk(clk), .rst_n(rst_n), .cadence_filt(cadence_filt), .cadence_per(candance_per), .not_pedaling(not_pedaling));
cadence_LU lu1(.cadence_per(candance_per),.cadence(cadence));

//instantiate telemetry (also contains UART transmitter) ****NEEDS TO FILL IN PARAMS***
telemetry telem1(.clk(clk), .rst_n(rst_n), .batt_v(batt), .avg_curr(curr_avg), .avg_torque(), .TX(TX));

//instantiate desired drive to get target_curr ****NEEDS TO FILL IN PARAMS***
desiredDrive drive1(.not_pedaling(not_pedaling), .avg_torque(), .cadence(cadence), .incline(), .scale(), .target_curr());

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
logic [13:0] curr_accum; 
logic [11:0] curr_avg;
logic  include_smpl; 

//determine when timer is full 
generate if (FAST_SIM) 
    logic [16:0] tmr_c;  //during fast simulation reduce bit width of counter 
else
    logic [22:0] tmr_c;  
endgenerate


//free running timer for current samples
always_ff(@posedge clk or negedge rst_n)begin 
    if(!rst_n)
        tmr_c <= 0; 
    else 
        tmr_c <= tmr_c +1;     
end 

include_smpl = &tmr_c;

//current exponential running average 
always_ff @(posedge clk or negedge rst_n)begin 
    if(!rst_n)
        curr_accum <= 0;
    else if(include_smpl)  
      current_accum <=  ((curr_accum*3) >>> 2) + curr_avg;
end 



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
    

generate if (FAST_SIM)
    localparam THIRD_SEC = THIRD_SEC_FAST;
else
    localparam THIRD_SEC = THIRD_SEC_REAL;
endgenerate

// rising edge detection for cadence filt
wire cadence_rise;
reg rise_reg;

always(@posedge clk, negedge rst_n)begin
    if(!rst_n)
        rise_reg<=1'b0;
    else 
        rise_reg<=cadence_filt;
end

assign cadence_rise=rise_reg&~cadence_filt;


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
wire[7:0] stage_1_output = (FAST_SIM) ? threeSecTimer[14:7] : threeSecTimer[23:16];
reg[7:0] cadence_per;
wire capture_per;

assign capture_per= cadence_rise || (threeSecTimer == THIRD_SEC);

always(@posedge clk, negedge rst_n) begin
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
wire[7:0] stg2Input;
reg[7:0] cadence_per;
wire not_pedaling;

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

//TODO: implement sensorCondition for avg_torque. not as a module. 

//KEY IDEA:
/*
sensors require averaging. (ie, avearge of last n samples). 
normal averaging is expensive, perform exponential avrages. 
exponential average gives more weight to more recent measurements than older measurements. 

has an accumulator log2(w) bits wider than the bus width. So an exponential average of weight 16
ie 16 past measurements(?), accumulator needs to be 4 bits wider than the bus width. 
if bus width is 12 bits, then 16 bit accumulator. 

for every new sample, accum is updated with
accum=((accum*(w-1)/w))+smpl. 
the average of the samples is then accum/w

W should always be a power of 2 so its just bit shifting. 




*/


endmodule