module sensorCondition(
    input logic clk, 
    input logic rst_n,
    input logic [11:0] torque,
    input logic cadence_raw,
    input logic [11:0] curr,
    input logic [11:0] incline, 
    input logic [2:0] scale,
    input logic [11:0] batt,
    input logic        
);


endmodule


module cadence_meas(
    input wire cadence_filt;
    output wire[7:0] cadence_per_wire;
    output wire not_pedaling;
);

//24 bit counter
reg[23:0] threeSecTimer;




// rising edge detection for cadence filt
wire cadence_rise;
reg rise_reg;
always(@posedge clk, negedge rst_n)begin
    if(!rst_n)rise_reg<=1'b0;
    else rise_reg<=cadence_filt;
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



endmodule
