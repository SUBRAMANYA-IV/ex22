/**
* This timer enforces 8-byte packets of telemetry data being sent at a rate of
* about 48Bps. 
*/
module counter_20b(
    input logic rst_n, // asynch counter reset
    input logic clk,
    output logic full // asserts when timer hits max value
);

    logic [19:0] count;

    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n)
            count <= 20'hFFFFF; // initialized near full so we can immediately start sending
        else
            count <= count + 1;
    end

    assign full = &count;
endmodule

/**
* This module periodically sends system information about the bike to a handlebar
* display via UART. It sends battery voltage, current consumption, and motor output info.
*/
module telemetry(TX, batt_v, avg_curr, avg_torque, clk, rst_n);
output logic TX;
input logic [11:0] batt_v;
input logic [11:0] avg_curr;
input logic [11:0] avg_torque;
input logic clk;
input logic rst_n;

typedef enum logic [1:0] {
    IDLE = 2'b00,
    SEND = 2'b01,
    WAIT = 2'b10
} state_t;

// synchronously update state and the byte number being transmitted during operation
state_t state;
state_t nxt_state;
logic [2:0] byte_num; // specifies which byte 1-8 to send through the tx
logic [2:0] curr_byte; // input D to the byte_num flop inferred below

always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        state <= IDLE;
        byte_num <= 4'b0;
    end
        
    else begin
        state <= nxt_state;
        byte_num <= curr_byte;
    end
end

// Timer used to send ~48 packets per second
logic full; // asserts when it's time to send a new packet
counter_20b uart_tmr(.clk(clk), .rst_n(rst_n), .full(full));

logic [7:0] tx_data;

// UART device used to transmit telemetry data
logic trmt;
logic tx_done;
UART_tx uart(.clk(clk),.rst_n(rst_n),.TX(TX),.trmt(trmt),.tx_data(tx_data),.tx_done(tx_done));

// STATE MACHINE &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
always_comb begin
    // default values
    trmt = 1'b0;
	tx_data = 8'h0;
    
    case(state)
        IDLE: begin
            curr_byte = 3'b000; 
            if(full) // once 1/48th of a second elapses, we are ready to send new packet
                nxt_state = SEND;
            else 
                nxt_state = IDLE;
        end
        SEND: begin // put a single byte of data into the tx
            curr_byte = byte_num;
            nxt_state = (&curr_byte) ? IDLE : WAIT; // start over after last byte is transmitted
            case(byte_num)
                3'b000: tx_data = 8'hAA;
                3'b001: tx_data = 8'h55;
                3'b010: tx_data = {4'h0, batt_v[11:8]};
                3'b011: tx_data = batt_v[7:0];
                3'b100: tx_data = {4'h0, avg_curr[11:8]};
                3'b101: tx_data = avg_curr[7:0];
                3'b110: tx_data = {4'h0, avg_torque[11:8]};
                3'b111: tx_data = avg_torque[7:0];
                default: tx_data = 8'h0;
            endcase
            trmt = 1'b1;
            
        end
        WAIT : begin // wait for byte to finish transmitting 
            curr_byte = byte_num; // maintain byte number
            if(tx_done) begin
                nxt_state = SEND;
                curr_byte = byte_num + 1;
            end
            else 
                nxt_state = WAIT;
        end

        default: nxt_state = IDLE;
    endcase
end

endmodule