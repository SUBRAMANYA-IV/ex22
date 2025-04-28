module shift_cntr(clk, shift, init, done16);
input logic clk;
input logic shift;
input logic init; // control signal used to clear counter
output logic done16; // signal shows that counter is full

logic [4:0] bit_cntr;
logic [4:0] init_mux_input;

always_ff @(posedge clk) begin
    bit_cntr <= (init) ? 5'b0 : init_mux_input;
end

assign init_mux_input = (shift) ? bit_cntr+1 : bit_cntr;
assign done16 = bit_cntr[4];

endmodule
//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
module sclk_cntr(clk, full, shft, ld_SCLK, SCLK);
input logic clk;
input logic ld_SCLK;
output logic full;
output logic shft;
output logic SCLK;

logic [4:0] SCLK_div;

always_ff @(posedge clk)
    SCLK_div <= (ld_SCLK) ? 5'b10111 : SCLK_div + 1;

assign SCLK = SCLK_div[4];
assign shft = (SCLK_div == 5'b10001);
assign full = &SCLK_div;

endmodule
//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
module monarch_shft(clk, cmd, MISO, init, shft, MOSI, shft_reg);
input logic [15:0] cmd;
input logic clk;
// control signals for shift register
input logic init;
input logic shft;

// data in/out for spi monarch
input logic MISO;
output logic MOSI;

output logic [15:0] shft_reg;

// infer the shift register mux, which either p-loads with a cmd, maintains 
// value, or shifts in from MISO LSB first
always_ff @(posedge clk) begin 
    MOSI = shft_reg[15];
    case ({init,shft})
        2'b00: begin
            shft_reg <= shft_reg;
        end
        2'b01: begin
            shft_reg <= {shft_reg[14:0],MISO};
        end
        default: begin
            shft_reg <= cmd;
        end
    endcase
end
endmodule

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$

module SPI_mnrch(clk, rst_n, SS_n, SCLK, MOSI, MISO, snd, cmd, done, resp);
// PORT DECLARATIONS /////////////////////////////////////////////////////
input logic clk;
input logic rst_n;
input logic snd;
input logic [15:0] cmd;
output logic done;
output logic [15:0] resp;
// SPI pins
input logic MISO;
output logic MOSI;
output logic SCLK;
output logic SS_n; // active low chip select
/////////////////////////////////////////////////////////////////////////////


// state enums
typedef enum  logic [1:0] {
    IDLE = 2'b00, // do nothing, wait until send happens 
    INIT = 2'b01, // reset counters
    SHIFT = 2'b10, // shift out/in a new 4 byte signal
    PORCH = 2'b11 // create the back porch of the chip select and sclk signals
}spi_state;

// state machine signals
spi_state state;
spi_state nxt_state;

// intermediate nets
logic shft;
logic init; // active high signal to clear counters and load new 4B value
logic full;
logic ld_SCLK; // active high set signal to reset sclk to initial count value
logic done16;
logic set_done;
logic set_ss;

// devices
shift_cntr cnt_shft(.clk(clk), .shift(shft), .init(init), .done16(done16));
sclk_cntr sclk_gen(.clk(clk), .full(full), .shft(shft), .ld_SCLK(ld_SCLK), .SCLK(SCLK));
monarch_shft shftreg(.clk(clk), .cmd(cmd), .MISO(MISO), .init(init), .shft(shft), .MOSI(MOSI), .shft_reg(resp));

// STATE MACHINE *****************************************************************
always_comb begin
    // default values
    init = 0;
    

    case(state)
        IDLE: begin
            set_ss = 1'b1;

            ld_SCLK = 1'b1;
            if(snd) begin
                set_done = 1'b0;
                nxt_state = INIT;
            end else begin
                set_done = 1'b1;
                nxt_state = IDLE;
            end
        end

        INIT: begin
            set_done = 1'b0;
            set_ss = 1'b1;

            nxt_state = SHIFT;
            init = 1'b1; // reset counters and load instruction
            ld_SCLK = 1'b0;
            

        end

        SHIFT: begin // shift state: perform 16 shifts to send data to serf
            set_done = 1'b0;
            set_ss = 1'b0;

            ld_SCLK = 1'b0;
            if(done16) begin
                nxt_state = PORCH;
            end else begin
                nxt_state = SHIFT;
            end

        end

        PORCH: begin // delay raising SS_n after SCLK stops to create back porch
            if(full) begin
                set_ss = 1'b1;
                set_done = 1'b1;

                //raise SS_n back to 1
                ld_SCLK = 1'b1;
                nxt_state = IDLE;
            end else begin
                set_ss = 1'b0;
                set_done = 1'b1;

                ld_SCLK = 1'b0;
                nxt_state = PORCH;
            end
        end
        default: nxt_state = IDLE;
    endcase
end

// done signal flop
always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        done <= 1'b0;
    else
        done <= set_done;
end

// SS_n signal flop
always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        SS_n <= 1'b1;
    else
        SS_n <= set_ss;
end

// sequential state assignment loop
always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        state <= IDLE;
    else
        state <= nxt_state;
end
//***********************************************************************************

endmodule