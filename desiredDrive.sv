module desiredDrive(avg_torque, cadence, not_pedaling, incline, scale, target_curr);


///Input and ouput signals////
input not_pedaling;
input  [11:0] avg_torque; 
input  [4:0]  cadence;
input  [12:0] incline;
input  [2:0]  scale;
output [11:0] target_curr;

/////Intermidiate signals/////
logic [9:0] incline_sat;
logic [10:0] incline_sat2;

logic [10:0] incline_factor; 
logic [8:0] incline_lim; 

logic [5:0] cadence_factor;


logic [12:0] avg_torque2; 
logic [12:0] torque_off; 
logic [11:0] torque_pos; 

logic [29:0] assist_prod;

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

assign incline_factor = incline_sat2 + $signed(11'd256);

//limit incline factor to non negative values and max value of 511
assign incline_lim = incline_factor[10] ? ( 9'b000000000 ):( incline_factor[9] ? 9'b111111111 : incline_factor[8:0] );



//if cadance input is not greater than one set factor to 0, else scale by adding 32
assign cadence_factor = |cadence[4:1] ? ( cadence[4:0] + 6'd32 ):( 6'd0 );

//zero extend avg_torque to 13 bit quantity 
assign avg_torque2 = { 1'b0, avg_torque[11:0] }; 

//should be 13-bits wide and formed from the subtraction of two zero extended 12-bit quantities (avg_torque & TORQUE_MIN)
assign torque_off = avg_torque2 - TORQUE_MIN; 

//zero clip torque_off if it became negative (look at MSB) else copy lower n-1 bits 
assign torque_pos = torque_off[12] ? ( 12'd0 ):( torque_off[11:0] );

//if not pedaling then just equal to zero else this is a product of torque_pos, incline_lim,cadence_factor,and scale. 
assign assist_prod =  not_pedaling ? ( 30'd0 ) :( torque_pos*incline_lim*cadence_factor*scale);

//If any of bits [29:27] of assist_prod are set then we set this signal to 12’hFFF otherwise we set it to assist_prod[26:15].
assign target_curr = |assist_prod[29:27] ? (12'hFFF) : (assist_prod[26:15]);

endmodule