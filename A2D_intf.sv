module d_flipflop(d, q, clk, en, rst_n);
    input logic d;
    output logic q;
    input logic clk;
    input logic en;
    input logic rst_n;
    
    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n)
            q <= 1'b0;
        else if (en)
            q <= d;
    end

endmodule


/**
* Free running counter used for the A2D to start a conversion
* every 328 microseconds.
*/
module fourteen_counter(clk, rst_n, full);
    input logic clk;
    input logic rst_n;
    output logic full;

    logic [13:0] count;

    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n) 
            count = 14'b0;
        else
            count = count + 1;
    end

    assign full = &count;
endmodule

/**
* This A2D interface has access to 8 channels, 4 of which will be used to read sensor
* data from the E-bike system.
*
* CHANNEL GUIDE:
* 000: Read battery voltage
* 001: Motor current draw
* 011: Brake lever position
* 100: Pedal torque sensor
*
* SPI read request format: {2’b00,channel[2:0],11’h000}
*/
module A2D_intf(clk, rst_n, batt, curr, brake, torque, SS_n, SCLK, MOSI, MISO);

input logic clk;
input logic rst_n;
output logic [11:0] batt;
output logic [11:0] curr;
output logic [11:0] brake;
output logic [11:0] torque;
output logic SS_n;
output logic SCLK;
output logic MOSI;
input logic MISO;



//State for which channel is being read
typedef enum logic[1:0]{BATT,CURR,BRAKE,PEDAL} channel_read;
channel_read curr_channel;
channel_read nxt_channel;

//state for which part of the transmission is taking place
typedef enum logic[1:0]{IDLE,REQ,WAIT,REC} comm_state;
comm_state curr_comm;
comm_state nxt_comm;

// State registers for both state machines
always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        curr_channel <= BATT;
        curr_comm <= IDLE;
    end
    else begin
        curr_channel <= nxt_channel;
        curr_comm <= nxt_comm;
    end
end

///////////////////////////////// SPI CONTROL NETS ////////////////////////////////
logic full; // raised to 1 whenever a new send/recieve transaction should start
fourteen_counter spi_cnt(.clk(clk), .rst_n(rst_n), .full(full));
logic send; // SM will raise to 1 to initiate transaction
logic done; // SPI will raise to 1 to indicate finished transaction to SM
///////////////////////////////////////////////////////////////////////////////////

//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! CHANNEL SELECT NETS !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
logic [15:0] command; // 16 bit request vector, determines which channel will be read
logic [15:0] response; // conversion result, channel select state machine will determine
                       // what port response will be written to
//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

//SPI model
SPI_mnrch iSPI(.clk(clk), .rst_n(rst_n), .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO), .snd(send), .cmd(command), .done(done), .resp(response));

logic [1:0] outputReg[15:0]; // enable signal that allows writing to an output reg

logic write_reg; //TODO: signal to control when data from SPI_mnrch can be loaded into appropriate 
//register: SHOULD ONLY ENABLE WHEN DATA IS RECIEVED FROM PERIPHERAL. 

//Example: If current state is reading/writing to channel BATT, one write_reg is asserted, load 
//data from SPI_mnrch into local reg BATT, THEN change state to next chanel. 
// CHANNEL SELECT STATE MACHINE

logic [3:0] enables; // enable bit vector to control output of registers

d_flipflop batt_ff [11:0] (.d(response[11:0]), .q(batt), .clk(clk), .rst_n(rst_n), .en(enables[0]));
d_flipflop curr_ff [11:0] (.d(response[11:0]), .q(curr), .clk(clk), .rst_n(rst_n), .en(enables[1]));
d_flipflop brake_ff [11:0] (.d(response[11:0]), .q(brake), .clk(clk), .rst_n(rst_n), .en(enables[2]));
d_flipflop torque_ff [11:0] (.d(response[11:0]), .q(torque), .clk(clk), .rst_n(rst_n), .en(enables[3]));

//TODO: finish implementing state machine. Implement logic for write_reg (\)
always_comb begin

    case(curr_channel)
        BATT: begin
            command={2'b00,3'b000,11'h000};
            if(write_reg) begin
            nxt_channel=CURR;
            enables=4'b0001;
            end
            else begin
            nxt_channel=BATT;
            enables=4'b0000;
            end
        end

        CURR: begin
            command={2'b00,3'b001,11'h000};
            if(write_reg)begin
                nxt_channel=BRAKE;
                enables=4'b0010;
            end
            else begin
            nxt_channel=CURR;
            enables=4'b0000;
            end
        end

        BRAKE: begin
             command={2'b00,3'b011,11'h000};
            if(write_reg)begin
                nxt_channel=PEDAL;
                enables=4'b0100;
            end
            else begin
            nxt_channel=BRAKE;
            enables=4'b0000;
            end
        end

        PEDAL: begin
            command={2'b00,3'b100,11'h000};
            if(write_reg)begin
                nxt_channel=BATT;
                enables=4'b1000;
            end
            else begin
            nxt_channel=PEDAL;
            enables=4'b0000;
            end
        end
    endcase

end

// SPI CONTROL STATE MACHINE
always_comb begin
    write_reg = 1'b0; // output regs should maintain their values until new data is recieved
    send = 1'b0;

    case(curr_comm)
        // Wait for 328us to elapse before starting another transaction
        IDLE: begin
            if(full) begin
                nxt_comm = REQ;
                send = 1'b1;
            end else begin
                nxt_comm = IDLE;
            end
        end

        // Send command to SPI to send channel data
        REQ: begin
            nxt_comm = (done) ? WAIT : REQ;
        end
        
        // wait 1 cycle between request and recieve transactions
        WAIT: begin
            if(SS_n) begin
                nxt_comm = REC;
                send = 1'b1;
            end else begin
                nxt_comm = WAIT;
                send = 1'b0;
            end
        end

        // recieve channel data from SPI
        REC: begin
            if(done) begin
                write_reg = 1'b1; // write the response to the correct output reg
                nxt_comm = IDLE;
            end else begin
                nxt_comm = REC;
            end
        end

        // catch case for 
        default: nxt_comm = IDLE;
    endcase

end

endmodule