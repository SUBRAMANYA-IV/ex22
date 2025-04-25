module sensorCondition_tb();

//signals to feed into the module
logic clk,rst_n;
logic [11:0] torque;
logic cadence_raw;
logic signed [11:0] curr;
logic [11:0] incline;
logic [2:0] scale;
logic [11:0] batt;
logic signed [12:0] error; //output
logic not_pedaling; //output
logic TX; //output

sensorCondition #(.FAST_SIM(1))iDUT(.clk(clk),.rst_n(rst_n),.torque(torque),.cadence_raw(cadence_raw),.curr(curr),.incline(incline),.scale(scale),.batt(batt),.error(error),.not_pedaling(not_pedaling),.TX(TX));

initial clk=0;
always #10 clk=~clk;




endmodule
