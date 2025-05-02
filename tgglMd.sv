module tgglMd(clk,rst_n,tgglMode,scale);

input clk, rst_n, tgglMode;
   output logic [2:0] scale;
   output logic [1:0] cycle;

logic q1,q2,q3;   //Signals used to double flop Asynch signal and then detect rising edge on synched signal
logic rise_edge;  //capture rising edge 


always_ff @(posedge clk or negedge rst_n ) begin 
   
   if(!rst_n) begin
    q1 <= 1;            //PB is pulled up normally when not being pressed 
    q2 <= 1;
    q3 <= 1;
   end else begin 
    q1 <= tgglMode;
    q2 <= q1;        //double flops for metastability 
    q3 <= q2;        //third flop to detect rising edge 
   end  
end

assign rise_edge = q2 & ~q3; //capture rising edge on tgglMode after stabilizing signal 

always_ff @(posedge clk or negedge rst_n ) begin    
   if(!rst_n) begin
     cycle <= 2'b10;       //reset to medium 
   end else if(rise_edge) 
     cycle <= cycle + 1;   //else cycle through 10 -> 11 -> 00 -> 01
end


always_comb begin 
  
  scale = 3'b101; //default to medium 

  case(cycle)  

    2'b00: scale = 3'b000;    //set scale depending where we are in the cycle

    2'b01: scale = 3'b011;

    2'b10: scale = 3'b101;

    2'b11: scale = 3'b111;
  endcase 
end


endmodule

