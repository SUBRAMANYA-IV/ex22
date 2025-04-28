module nonoverlap(clk,rst_n,highIn,lowIn,highOut,lowOut);

input clk;      //50MHz clock
input rst_n;    //asynch active low reset signal 
input highIn;   //In Control for high side FET
input lowIn;    //In Control for low side FET
output logic highOut;  //Out Control for high side FET with ensured non-overlap
output logic lowOut;   //Out Control for low side FET with ensured non-overlap

//internal to detect change in signal
//logic enable;      //enable counter signal
logic L1,L2,L3;    //used to double flop and detect change in lowIn
logic changed;     //signal to detect change in either lowIn or highIN
logic H1,H2,H3;    //used to double flop and detect change in highIN

logic [4:0] count; //used to count min of 32 clk cycles of deatime in between signal input changes

logic deadtime;  //signal to determine if we are currently in deadtime


//signal change detector used to detect rise or falling edge within lowIn
always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            L1 <= 1'b0;  //reset flops to zero on rst_n
            L2 <= 1'b0;
			L3 <= 1'b0;    
      end else begin
            L1 <= lowIn; //double flop first for meta-stability 
            L2 <= L1;
			L3 <= L2;    //stable signal used to detect change
     end
end
//signal change detector used to detect rise or falling edge within highIN
always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            H1 <= 1'b0;   //reset flops to zero on rst_n
            H2 <= 1'b0;
			H3 <= 1'b0; 
      end else begin
            H1 <= highIn; //double flop first for meta-stability 
            H2 <= H1;
			H3 <= H2;    //stable signal used to detect change
     end
end

always_comb begin 
changed =  H2^H3 || L2^L3 ; //will detect a change in either signal
deadtime = ~(&count);     //if counter is not full then deadtime is still active and signals show remain both low
end


//counter logic 
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
	    count <= 0;                  //reset flops
    end else if (changed) begin
        count <= 5'b00001;           // Reset counter when input changes               
    end else if (count < 31) begin   //while count is less than 31 increment count 
        count <= count + 1;
    end 
 end


//output flops to prevent glitching
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin         //reset to 0
        highOut <= 0;
        lowOut  <= 0;
    end else if (changed || deadtime) begin //once a change is detected or if we are in deadtime after a chnage then set output low 
	    highOut <= 0;    //after a change and during deadtime maintain both signals low
        lowOut  <= 0;
    end else begin       //once deatime is done and no new change we can allow the signals to be transparent  
        highOut <= H2;   
        lowOut  <= L2;
    end
end




endmodule