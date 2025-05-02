module sensorCondition (
    input logic clk,
    input logic rst_n,
    input logic [11:0] torque,
    input logic cadence_raw,
    input logic signed [11:0] curr,
    input logic [12:0] incline,
    input logic [2:0] scale,
    input logic [11:0] batt,
    output logic signed [12:0] error,
    output logic not_pedaling,
    output logic TX
);

  logic forcedFiltCadence;

  parameter FAST_SIM = 1;
  
  logic signed [12:0] error1;

  logic [11:0] curr_avg;
  logic [11:0] torque_avg;

  logic cadence_Sfilt;  //filtered cadence signal
  logic cadence_rise;  //
  logic [7:0] cadence_per;  //period of filtered candance signal

  //used to detect falling edge on not_pedalin
  logic pedaling_resREG;
  logic pedaling_resumes;

  logic [4:0] cadence;
  logic [4:0] cadence1;

  logic signed [11:0] target_curr;
  
  logic [12:0] incline1; 
  
   always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) 
		incline1 <= 0;
    else  
		incline1 <= incline;
  end
  

  //instantiate cadence filter module to filter raw candence signal
  cadence_filt #(
      .FAST_SIM(FAST_SIM)
  ) filt1 (
      .clk(clk),
      .rst_n(rst_n),
      .cadence(cadence_raw),
      .cadence_filt(cadence_Sfilt),
      .cadence_rise(cadence_rise)
  );
  cadence_meas #(
      .FAST_SIM(FAST_SIM)
  ) meas1 (
      .clk(clk),
      .rst_n(rst_n),
      .cadence_filt(cadence_Sfilt),
      .cadence_per(cadence_per),
      .not_pedaling(not_pedaling)
  );
  cadence_LU lu1 (
      .cadence_per(cadence_per),
      .cadence(cadence1)
  );

always_ff @(posedge clk)begin 
 
 cadence <= cadence1;

end 

  //instantiate telemetry (also contains UART transmitter) ****NEEDS TO FILL IN PARAMS**
  telemetry telem1 (
      .clk(clk),
      .rst_n(rst_n),
      .batt_v(batt),
      .avg_curr(curr_avg),
      .avg_torque(torque_avg),
      .TX(TX)
  );

  //instantiate desired drive to get target_curr ****NEEDS TO FILL IN PARAMS**
  desiredDrive drive1 (
      .not_pedaling(not_pedaling),
      .avg_torque(torque_avg),
      .cadence(cadence),
      .incline(incline1),
      .scale(scale),
      .target_curr(target_curr),
	  .clk(clk)
  );

  //falling edge detector for not_pedalin
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) pedaling_resREG <= 0;
    else pedaling_resREG <= not_pedaling;
  end

  //falling edge on not_pedalin
  assign pedaling_resumes = ~not_pedaling & pedaling_resREG;

  //<siganls used for current exponential average
  logic [13:0] current_accum;
  logic [13:0] newC_accum;
  logic include_smpl;
  logic [21:0] tmr_c;

  //determine when timer is full
  generate
    if (FAST_SIM)
      assign include_smpl = &tmr_c[15:0];  //during fast simulation reduce bit width of counter
    else assign include_smpl = &tmr_c;
  endgenerate


  //free running timer for collecting periodic current sample
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) tmr_c <= 0;
    else tmr_c <= tmr_c + 1;
  end

  //current exponential running average
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) current_accum <= 0;
    else if (include_smpl) current_accum <= newC_accum;
  end

  assign newC_accum = ((current_accum * 3) >>> 2) + curr;  //formula for exponential running average
  assign curr_avg = current_accum[13:2];  //average is current accum 

  //<siganls used for torque exponential average
  logic [16:0] torque_accum;
  logic [16:0] newT_accum;


  //torque exponential running average
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) torque_accum <= 0;
    else if (pedaling_resumes) torque_accum <= {1'b0, torque, 4'b0000};
    else if (cadence_rise) torque_accum <= newT_accum;
  end

  //formula for torque running avera
  assign newT_accum = ((torque_accum * 31) / 32) + torque;
  assign torque_avg = torque_accum[16:5];


  //FIX ERROR: SHOULD INCLUDE LOW_BATT_THRES AND NOT_PEDALIN
  localparam LOW_BATT_THRES = 12'ha98;

  always_comb begin
    if (not_pedaling || batt < LOW_BATT_THRES) error1 = 13'b0;
    else error1 = target_curr - curr_avg;
  end
  
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) 
		error <= 0;
    else  
	    error <= error1; 
  end
  
  
endmodule


module cadence_meas (
    input clk,
    input rst_n,
    input cadence_filt,
    output logic [7:0] cadence_per,
    output logic not_pedaling
);

  //FAST SIM logic that was provide
  localparam THIRD_SEC_REAL = 24'hE4E1C0;
  localparam THIRD_SEC_FAST = 24'h007271;
  localparam THIRD_SEC_UPPER = 8'hE4;

  parameter FAST_SIM = 0;
  logic [23:0] THIRD_SEC;

  generate
    if (FAST_SIM) assign THIRD_SEC = THIRD_SEC_FAST;
    else assign THIRD_SEC = THIRD_SEC_REAL;
  endgenerate

  //first stage 24 wide re
  reg [23:0] firstReg;

  logic cadence_rise;
  reg cadenceReg;
  assign cadence_rise = ~cadenceReg & cadence_filt;
  //detect rising edge of cadence, cadence_ris
  always @(posedge clk, negedge rst_n) begin
    if (!rst_n) cadenceReg <= 1'b0;
    else cadenceReg <= cadence_filt;
  end

  logic third_sec_equals; 
  assign third_sec_equals=(THIRD_SEC == firstReg);


  always @(posedge clk, negedge rst_n) begin
    if (!rst_n) firstReg <= 24'b0;
    else begin
      if (third_sec_equals && ~cadence_rise) firstReg <= firstReg;
      else if (third_sec_equals && cadence_rise) firstReg <= 24'b0;
      else if (~third_sec_equals && ~cadence_rise) firstReg <= firstReg + 1;
      else if (~third_sec_equals && cadence_rise) firstReg <= 24'b0;
    end
  end

  logic capture_per;
  assign capture_per=cadence_rise||third_sec_equals;
  logic [7:0] stg_2_input;
  assign stg_2_input = (FAST_SIM) ? firstReg[14:7] : firstReg[23:16];
  always @(posedge clk) begin
    if (!rst_n) cadence_per <= THIRD_SEC_UPPER;
    else begin
      if (capture_per) cadence_per <= stg_2_input;
      else cadence_per <= cadence_per;
    end
  end

  assign not_pedaling = (cadence_per == THIRD_SEC_UPPER);


endmodule












