module PWM( clk,rst_n, duty, PWM_sig, PWM_synch );

//module signals 
input clk;             //50MHz system clk
input rst_n;           //Asynch active low
input [10:0] duty;     //Specifies duty cycle (unsigned 11-bit)
output logic PWM_sig;  //PWM signal out (glitch free comes from flop)
output logic PWM_synch;      //When cnt is 11’h001 output a signal to allow commutator to synch to PWM

//counter used to determine when to set signal high/low based of duty 
logic [10:0] cnt; 


//counter ff will increment once per clk cycle this will be used to control duty by letting PWM_sig be high until cnt is greater than duty 
always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= 11'd0;       //reset count on rst_n
      end else begin
            cnt <= cnt + 1;    //free runing counter incrementing once per clk cycle 
     end
end

logic flop_PWM_SYNCH;

//when cnt is 11’h001 output a signal to allow commutator to synch to PWM
assign flop_PWM_SYNCH = (cnt == 11'h001) ? ( 1'b1 ):( 1'b0 );


always_ff @(posedge clk) begin 
	if(!rst_n) begin 
	  PWM_synch <= 0; 
   end else begin 
      PWM_synch <= flop_PWM_SYNCH;
   end 
end
//pwm output signal based off where we are in the duty cycle (will repeat since counter overflows after filling)
always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            PWM_sig <= 1'b0;
      end else if (cnt <= duty) begin
            PWM_sig <= 1'b1;          //while count is less than duty maintain high
      end else
            PWM_sig <= 1'b0;	      //once count is greater than duty maintain low
end

endmodule 