module mtr_drv(clk, rst_n, duty, selGrn, selYlw, selBlu,
               highGrn, lowGrn, highYlw,lowYlw, highBlu, lowBlu,PWM_synch); 

input [10:0] duty;    //input to pwm module which sets duty cycle 
input [1:0]  selGrn;  //Determines how green high and low signals should be driven (PWM, ~PWM, LOW)
input [1:0]  selYlw;  //Determines how yellow high and low signals should be driven (PWM, ~PWM, LOW)
input [1:0]  selBlu;  //Determines how Blue high and low signals should be driven (PWM, ~PWM, LOW)
input clk,rst_n;      //clk and rst_n
output PWM_synch;     //pwm synch signal
output highGrn,lowGrn,highYlw,lowYlw,highBlu,lowBlu; //output from nonoverlap block 

logic PWM_sig; //general PWM signal from produced from PWM module 

//inputs into no overlap block change based off select signals for green blue and yellow 
logic G_low_in; 
logic G_hig_in;
logic B_low_in;
logic B_hig_in;
logic Y_low_in;
logic Y_hig_in;

//instantiate pwm module to produce pwm signal 
PWM  PWMBLOCK( .clk(clk) ,.rst_n(rst_n), .duty(duty), .PWM_sig(PWM_sig), .PWM_synch(PWM_synch) );  

//nonoverlap block for green signals 
nonoverlap NOBLOCK1(.clk(clk),.rst_n(rst_n),.highIn(G_hig_in),.lowIn(G_low_in),.highOut(highGrn),.lowOut(lowGrn));

//nonoverlap block for blue signals 
nonoverlap NOBLOCK2(.clk(clk),.rst_n(rst_n),.highIn(B_hig_in),.lowIn(B_low_in),.highOut(highBlu),.lowOut(lowBlu));

//nonoverlap block for yellow signals 
nonoverlap NOBLOCK3(.clk(clk),.rst_n(rst_n),.highIn(Y_hig_in),.lowIn(Y_low_in),.highOut(highYlw),.lowOut(lowYlw));


//<Set Signal Outputs based off input select signals>

//assign inputs to green nonoverlap block based off green select signals 
assign G_hig_in = selGrn[1] ? ( selGrn[0] ? 1'b0 : PWM_sig ):( selGrn[0] ? ~PWM_sig : 1'b0 );
assign G_low_in =  selGrn[1] ? ( selGrn[0] ? PWM_sig : ~PWM_sig ):( selGrn[0] ? PWM_sig : 1'b0 );

//assign inputs to blue nonoverlap block based off blue select signals 
assign B_hig_in = selBlu[1] ? ( selBlu[0] ? 1'b0 : PWM_sig ):( selBlu[0] ? ~PWM_sig : 1'b0 );
assign B_low_in =  selBlu[1] ? ( selBlu[0] ? PWM_sig : ~PWM_sig ):( selBlu[0] ? PWM_sig : 1'b0 );

//assign inputs to yellow nonoverlap block based off ywllow select signals 
assign Y_hig_in = selYlw[1] ? ( selYlw[0] ? 1'b0 : PWM_sig ):( selYlw[0] ? ~PWM_sig : 1'b0 );
assign Y_low_in =  selYlw[1] ? ( selYlw[0] ? PWM_sig : ~PWM_sig ):( selYlw[0] ? PWM_sig : 1'b0 );

endmodule 