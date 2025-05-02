module desiredDrive(avg_torque, cadence, not_pedaling, incline, scale, target_curr,clk);


///Input and ouput signals////
input not_pedaling;
input  [11:0] avg_torque; 
input  [4:0]  cadence;
input  [12:0] incline;
input  [2:0]  scale;
input clk; 
output [11:0] target_curr;

/////Intermidiate signals/////
logic [9:0] incline_sat;
logic [10:0] incline_sat2;

logic [10:0] incline_factor; 
logic [10:0]incline_factor1;
logic [8:0] incline_lim; 
logic [8:0] incline_lim1;

logic [5:0] cadence_factor;

logic  [11:0] avg_torque1; 
logic [12:0] avg_torque2; 
logic [12:0] torque_off; 
logic [12:0] torque_off1; 
logic [11:0] torque_pos; 
logic [11:0] torque_pos1; 

logic [29:0] assist_prod;
logic [29:0]assist_prod1;

//local param 
localparam TORQUE_MIN = 13'h380;


/*
Looks at MSB to determine if positive or negative then determines if number is in range to be converted to 10-bit 
if not in range value is saturated 
*/
assign incline_sat = incline[12] ? ( &incline[11:9] ? incline[9:0] : 10'b1000000000 ) //incline[12] is 1 so we have negative number
                                  :( |incline[11:9] ? 10'b0111111111 : incline[9:0] );//incline [12] is 0 so we have positive number

//sign extend to match factor signal
assign incline_sat2 = {incline_sat[9], incline_sat[9:0]};

assign incline_factor1 = incline_sat2 + $signed(11'd256);

always_ff@(posedge clk)begin 
	incline_factor <= incline_factor1; 
end 

always_ff@(posedge clk)begin 
	avg_torque1 <= avg_torque; 
end 

//limit incline factor to non negative values and max value of 511
assign incline_lim1 = incline_factor[10] ? ( 9'b000000000 ):( incline_factor[9] ? 9'b111111111 : incline_factor[8:0] );

always_ff@(posedge clk)begin 
	incline_lim <= incline_lim1; 
end 

//if cadance input is not greater than one set factor to 0, else scale by adding 32
assign cadence_factor = |cadence[4:1] ? ( cadence[4:0] + 6'd32 ):( 6'd0 );

//zero extend avg_torque to 13 bit quantity 
assign avg_torque2 = { 1'b0, avg_torque1[11:0] }; 

//should be 13-bits wide and formed from the subtraction of two zero extended 12-bit quantities (avg_torque & TORQUE_MIN)
assign torque_off1 = avg_torque2 - TORQUE_MIN; 

always_ff@(posedge clk)begin 
	torque_off <= torque_off1; 
end

//zero clip torque_off if it became negative (look at MSB) else copy lower n-1 bits 
assign torque_pos1 = torque_off[12] ? ( 12'd0 ):( torque_off[11:0] );

always_ff@(posedge clk)begin 
	torque_pos <= torque_pos1; 
end

logic [20:0] prod1;
// Cycle 2 — partial product 1
always_ff @(posedge clk) begin
    prod1 <= torque_pos * incline_lim;
end

logic [26:0] prod2;

always_ff @(posedge clk) begin
    prod2 <= prod1 * cadence_factor;
end

logic [29:0] prod3; 
// Cycle 4 — apply scale and not_pedaling condition
always_ff @(posedge clk) begin
    prod3 <= prod2 * scale;
end


always_ff@(posedge clk)begin 
	assist_prod <= not_pedaling ? 30'd0 : prod3; 
end 

//If any of bits [29:27] of assist_prod are set then we set this signal to 12’hFFF otherwise we set it to assist_prod[26:15].
assign target_curr = |assist_prod[29:27] ? (12'hFFF) : (assist_prod[26:15]);

endmodule