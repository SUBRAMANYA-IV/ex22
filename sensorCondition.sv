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
logic cadence_rise;  
logic candance_per; //periof of filtered candance signal 
logic not_pedaling;
logic [4:0] cadence; 

//instantiate cadence filter module to filter raw candence signal 
cadence_filt filt1((.clk(clk), .rst_n(rst_n) , .cadence(cadence_raw), .cadence_filt(cadence_Sfilt), .cadence_rise(cadence_rise));

cadence_meas meas1( .clk(clk), .rst_n(rst_n), .cadence_filt(cadence_filt), .cadence_per(candance_per), .not_pedaling(not_pedaling));


cadence_LU(.cadence_per(candance_per),.cadence())


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
    if(!rst_n)rise_reg<=1'b0;
    else rise_reg<=cadence_filt;
end
assign cadence_rise=rise_reg&~cadence_filt;


//on the rising edge of cadence_filt, a 24 bit timer is cleared,
//BUT si

endmodule
    output wire[7:0] cadence_per_wire;
    output wire not_pedaling;
//24 bit counter
reg[23:0] threeSecTimer;



cadence_risecadence_rise) if FAST_SIM)
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
wire[7:0] stage_1_output=(FAST_SIM)?threeSecTimer[14:7]:threeSecTimer[23:16];
reg[7:0] cadence_per;

always(@posedge clk, negedge rst_n)begin
    //check for syncrhonous reset?
    if(!rst_n)begin
        threeSecTimer<=24'b0;
    end
    else begin
        //if the rising edge is true, load either bits [23:16] if FAST_SIM is false, bits [14:7] if FAST_SIM is true. 
        if(cadence_ise)begin
            threeSecTimer<=24'b0;
        end
    
    end
    
end

//STAGE 2 SYNCRHONOUS BLOCK
always@(posedge clk)begin
    


end

7