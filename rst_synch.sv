module rst_synch(
input wire RST_n,
input wire clk,
output wire rst_n
);

reg inp1;
reg inp2;
assign rst_n=inp2;

always@(negedge clk,negedge RST_n)begin
if(!RST_n)begin
inp1<=1'b0;
inp2<=1'b0;
end else begin
inp1<=1'b1;
inp2<=inp1;
end

end

endmodule