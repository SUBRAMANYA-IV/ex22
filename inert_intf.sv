/*
* enableable ff model used to construct holding registers in inert_intf
*/
module d_flipflop(clk, rst_n, en, d, q);
    input logic clk, rst_n, en, d;
    output logic q;
    reg state;
    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n)
            state <= 1'b0;
        else if (en)
            state <= d;
    end
    assign q = state;
endmodule

/*
* Initialization timer used to ensure acceleration chip has adequate startup time
*/
module tmr_16b(clk, rst_n, full, rst);
    input logic clk, rst_n, rst;
    output logic full;

    logic [15:0] count;
    always @(posedge clk, negedge rst_n) begin
        if(!rst_n)
            count <= 16'b0;
        else if (rst)
            count <= 16'b0;
        else
            count <= count + 1;
    end
    assign full = &count;
endmodule

/*
* Double flops the asynch interrupt signal
*/
module INT_synch(clk, rst_n, d, q);
    input logic clk, rst_n, d;
    output logic q;

    reg int1, int2;
    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n) begin
            int1 <= 1'b0;
            int2 <= 1'b0;
        end else begin
            int1 <= d;
            int2 <= int1;
        end
    end
    assign q = int2;
endmodule

/*
* This module samples the acceleration, roll, and yaw values from the E-bike's on-board
* accelerometer. This will be fed into the integrator module, which will calculate the 
* incline experienced by the bike, which will be used in the motor current calculation.
*/
module inert_intf(clk, rst_n, SS_n, SCLK, MOSI, MISO, INT, vld, incline);
    input logic clk;
    input logic rst_n;
    input logic INT;
    input logic MISO;

    output logic SS_n;
    output logic SCLK;
    output logic MOSI;
    output logic [12:0] incline;
    output logic vld;

    logic [15:0] nxt_cmd, curr_cmd;
    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n)
            curr_cmd = 16'b0;
        else    
            curr_cmd = nxt_cmd;
    end

    logic snd, done;
    logic [15:0] resp; // only lowest 8 bits of resp are used
    SPI_mnrch iSPI(.clk(clk), .rst_n(rst_n), .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO), .snd(snd), .cmd(curr_cmd), .done(done), .resp(resp));

    // state definitions and transition structure
    typedef enum logic [3:0]  {INIT1, INIT2, INIT3, INIT4, WAIT_INT, READDATA, WAIT1, WAIT2, WAIT3, WAIT4, WAIT5} state_t;
    state_t curr_state, nxt_state;

    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n)
            curr_state = INIT1;
        else    
            curr_state = nxt_state;
    end

    // initialization timer, used to ensure accelerometer has adequate startup time before sending
    logic tmr_rst, tmr_full;
    tmr_16b init_tmr(.clk(clk), .rst_n(rst_n), .rst(tmr_rst), .full(tmr_full));

    // holding registers used to store the responses from the accelerometer. 
    logic [7:0] R_H_out, R_L_out, Y_H_out, Y_L_out, AY_H_out, AY_L_out, AZ_H_out, AZ_L_out;
    logic R_H_en, R_L_en, Y_H_en, Y_L_en, AY_H_en, AY_L_en, AZ_H_en, AZ_L_en;
    d_flipflop roll_high [7:0] (.clk(clk), .rst_n(rst_n), .en(R_H_en), .d(resp[7:0]), .q(R_H_out));
    d_flipflop roll_low [7:0] (.clk(clk), .rst_n(rst_n), .en(R_L_en), .d(resp[7:0]), .q(R_L_out));
    d_flipflop yaw_high [7:0] (.clk(clk), .rst_n(rst_n), .en(Y_H_en), .d(resp[7:0]), .q(Y_H_out));
    d_flipflop yaw_low [7:0] (.clk(clk), .rst_n(rst_n), .en(Y_L_en), .d(resp[7:0]), .q(Y_L_out));
    d_flipflop ay_high [7:0] (.clk(clk), .rst_n(rst_n), .en(AY_H_en), .d(resp[7:0]), .q(AY_H_out));
    d_flipflop ay_low [7:0] (.clk(clk), .rst_n(rst_n), .en(AY_L_en), .d(resp[7:0]), .q(AY_L_out));
    d_flipflop az_high [7:0] (.clk(clk), .rst_n(rst_n), .en(AZ_H_en), .d(resp[7:0]), .q(AZ_H_out));
    d_flipflop az_low [7:0] (.clk(clk), .rst_n(rst_n), .en(AZ_L_en), .d(resp[7:0]), .q(AZ_L_out));

    // INT must be synchronized to the system clock. It is then used to signal to the SM when the accelerometer has data ready to read
    logic INT_synched;
    INT_synch synch(.d(INT), .q(INT_synched), .clk(clk), .rst_n(rst_n));

    // 8-bit counter to differentiate between each read and store operation during the READDATA stage.
    logic [3:0] curr_op, nxt_op;
    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n) begin
            curr_op <= 4'b0;
        end
        else 
            curr_op <= nxt_op;
    end

    

    // computes the incline of the bicycle from the values within our holding registers
    inertial_integrator inert_int(.clk(clk), .rst_n(rst_n), .vld(vld), .roll_rt({R_H_out,R_L_out}), .yaw_rt({Y_H_out,Y_L_out}), 
        .AY({AY_H_out,AY_L_out}), .AZ({AZ_H_out,AZ_L_out}), .incline(incline), .LED()); //TODO: do we need LED connected?

    // state machine
    always_comb begin
        tmr_rst = 1'b0;
        vld = 1'b0;
        snd = 1'b0;
        R_H_en = 1'b0;
        R_L_en = 1'b0;
        Y_H_en = 1'b0;
        Y_L_en = 1'b0;
        AY_H_en = 1'b0;
        AY_L_en = 1'b0;
        AZ_H_en = 1'b0;
        AZ_L_en = 1'b0;
        nxt_op = curr_op;
        nxt_cmd = curr_cmd;

        case(curr_state)
            INIT1: begin
                
                if(tmr_full) begin
                    // enable interrupt pin on accelerometer
                    nxt_cmd = 16'h0D02;
                    snd = 1'b1;
                    nxt_state = WAIT1;
                end else begin
                    nxt_state = INIT1;
                end
            end
            WAIT1: begin
                nxt_state = (!SS_n) ? INIT2 : WAIT1;
            end
            INIT2: begin
                if(SS_n) begin 
                    // accelerometer setup
                    nxt_cmd = 16'h1053;
                    snd = 1'b1;
                    nxt_state = WAIT2;
                end
                else   
                    nxt_state = INIT2;
            end
            WAIT2: begin
                nxt_state = (!SS_n) ? INIT3 : WAIT2;
            end
            INIT3: begin
                // gyrometer setup
                if(SS_n) begin
                    nxt_cmd = 16'h1150;
                    snd = 1'b1;
                    nxt_state = WAIT3;
                end
                else   
                    nxt_state = INIT3;
            end
            WAIT3: begin
                nxt_state = (!SS_n) ? INIT4 : WAIT3;
            end
            INIT4: begin
                if(SS_n) begin
                    // enable rounding for gyro and accelerometer
                    nxt_cmd = 16'h1460;
                    snd = 1'b1;
                    nxt_state = WAIT5;
                end
                else   
                    nxt_state = INIT4;
            end
            WAIT5: begin
                nxt_state = (!SS_n) ? READDATA : WAIT5;
            end

            WAIT_INT: begin // only read into holding registers when integrator is ready for new data
                if(INT_synched)
                    nxt_state = READDATA; // TODO: Should we send a read command as we transition to the read stage?
                else
                    nxt_state = WAIT_INT;
            end
           
            READDATA: begin // read all required values into holding regs
                if(SS_n) begin
                    case (curr_op)
                        4'd0: begin // roll high
                            nxt_cmd = 16'hA500;
                        end
                        4'd1: begin // roll low
                            nxt_cmd = 16'hA400;
                            R_H_en = 1'b1;
                        end
                        4'd2: begin // yaw high
                            nxt_cmd = 16'hA700;
                            R_L_en = 1'b1;
                        end
                        4'd3: begin // yaw low 
                            nxt_cmd = 16'hA600;
                            Y_H_en = 1'b1;
                        end
                        4'd4: begin // ay high
                            nxt_cmd = 16'hAB00;
                            Y_L_en = 1'b1;
                        end
                        4'd5: begin // ay low
                            nxt_cmd = 16'hAA00;
                            AY_H_en = 1'b1;
                        end
                        4'd6: begin // az high
                            nxt_cmd = 16'hAD00;
                            AY_L_en = 1'b1;
                        end
                        4'd7: begin // az low
                            nxt_cmd = 16'hAC00;
                            AZ_H_en = 1'b1;
                        end
                        4'd8: begin
                            AZ_L_en = 1'b1; // cmd is a don't care, we just need the final reading from the spi
                        end
                        4'd9: begin
                            vld = 1'b1; // don't tell integrator to collect data until AZ_L appears at holding reg output after op 8
                        end
                    endcase
                    snd = 1'b1;
                    nxt_op = (curr_op != 4'd9) ? (curr_op + 1) : 4'd0;
                    nxt_state = (curr_op == 4'd9) ? WAIT_INT : WAIT5;
                end
                else begin
                    nxt_op = curr_op;
                    nxt_state = READDATA;
                end
            end
            default: begin
                tmr_rst = 1'b1;
                nxt_state = INIT1;
            end
        endcase

    end


endmodule