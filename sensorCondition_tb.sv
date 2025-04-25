module sensorCondition_tb();

logic clk;
logic rst_n;
logic [11:0] torque;
logic cadence_raw;
logic [11:0] curr;
logic [11:0] incline;
logic [2:0] scale;
logic [11:0] batt;
logic [12:0] error;
logic not_pedaling;
logic TX;

sensorCondition #(.FAST_SIM(1)) dut (.clk(clk), .rst_n(rst_n), .torque(torque), 
            .cadence_raw(cadence_raw), .curr(curr), .incline(incline), 
            .scale(scale), .batt(batt), .error(error), 
            .not_pedaling(not_pedaling), .TX(TX));

always #5 clk = ~clk;

always #500 cadence_raw = ~cadence_raw; 

initial begin
    //signals cared about in the testbench
    clk = 0;
    rst_n = 0;
    curr = 12'h3FF;
    torque = 12'h2FF;
    cadence_raw = 1'b0;

    //signals not cared about in the testbench
    incline = 12'h0;
    scale = 3'b000;
    batt = 12'h0;

    @(negedge clk);
    @(negedge clk);

    rst_n = 1;

    repeat(500000) @(posedge clk);

    $stop();




    

end

endmodule