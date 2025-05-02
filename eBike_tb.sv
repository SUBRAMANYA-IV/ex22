
`default_nettype none
module eBike_tb();
 
  // include or import tasks?

  localparam FAST_SIM = 1;		// accelerate simulation by default

  ///////////////////////////
  // Stimulus of type reg //
  /////////////////////////
  reg clk,RST_n;
  reg [11:0] BATT;				// analog values
  reg [11:0] BRAKE,TORQUE;		// analog values
  reg tgglMd;					// push button for assist mode
  reg [15:0] YAW_RT;			// models angular rate of incline (+ => uphill)


  //////////////////////////////////////////////////
  // Declare any internal signal to interconnect //
  ////////////////////////////////////////////////
  wire A2D_SS_n,A2D_MOSI,A2D_SCLK,A2D_MISO;
  wire highGrn,lowGrn,highYlw,lowYlw,highBlu,lowBlu;
  wire hallGrn,hallBlu,hallYlw;
  wire inertSS_n,inertSCLK,inertMISO,inertMOSI,inertINT;
  logic cadence;
  wire [1:0] LED;			// hook to setting from PB_intf
  
  wire signed [11:0] coilGY,coilYB,coilBG;
  logic [11:0] curr;		// comes from hub_wheel_model
  wire [11:0] BATT_TX, TORQUE_TX, CURR_TX;
  logic vld_TX;
	logic TX_RX;
  
  //////////////////////////////////////////////////
  // Instantiate model of analog input circuitry //
  ////////////////////////////////////////////////
  AnalogModel iANLG(.clk(clk),.rst_n(RST_n),.SS_n(A2D_SS_n),.SCLK(A2D_SCLK),
                    .MISO(A2D_MISO),.MOSI(A2D_MOSI),.BATT(BATT),
		    .CURR(curr),.BRAKE(BRAKE),.TORQUE(TORQUE));

  ////////////////////////////////////////////////////////////////
  // Instantiate model inertial sensor used to measure incline //
  //////////////////////////////////////////////////////////////
  eBikePhysics iPHYS(.clk(clk),.RST_n(RST_n),.SS_n(inertSS_n),.SCLK(inertSCLK),
	             .MISO(inertMISO),.MOSI(inertMOSI),.INT(inertINT),
		     .yaw_rt(YAW_RT),.highGrn(highGrn),.lowGrn(lowGrn),
		     .highYlw(highYlw),.lowYlw(lowYlw),.highBlu(highBlu),
		     .lowBlu(lowBlu),.hallGrn(hallGrn),.hallYlw(hallYlw),
		     .hallBlu(hallBlu),.avg_curr(curr));

         assign coilGY=iPHYS.coilGY;
         assign coilYB=iPHYS.coilYB;
         assign coilBG=iPHYS.coilBG;

  //////////////////////
  // Instantiate DUT //
  ////////////////////
  eBike #(FAST_SIM) iDUT(.clk(clk),.RST_n(RST_n),.A2D_SS_n(A2D_SS_n),.A2D_MOSI(A2D_MOSI),
                         .A2D_SCLK(A2D_SCLK),.A2D_MISO(A2D_MISO),.hallGrn(hallGrn),
			 .hallYlw(hallYlw),.hallBlu(hallBlu),.highGrn(highGrn),
			 .lowGrn(lowGrn),.highYlw(highYlw),.lowYlw(lowYlw),
			 .highBlu(highBlu),.lowBlu(lowBlu),.inertSS_n(inertSS_n),
			 .inertSCLK(inertSCLK),.inertMOSI(inertMOSI),
			 .inertMISO(inertMISO),.inertINT(inertINT),
			 .cadence(cadence),.tgglMd(tgglMd),.TX(TX_RX),
			 .LED(LED));
			 
			 
  ////////////////////////////////////////////////////////////
  // Instantiate UART_rcv or some other telemetry monitor? //
  //////////////////////////////////////////////////////////
  logic [7:0] rx_data;
  logic rdy;
  logic clr_rdy;
	
  UART_rcv monitor(.clk(clk), .rst_n(RST_n), .RX(TX_RX), .rdy(rdy), .rx_data(rx_data), .clr_rdy(clr_rdy)); // TODO: How do we check signals from telemetry?

  ////////////////////////////
  // Main testcases to run //
  //////////////////////////
  initial begin
    init();
    brakeTest();
    $stop();
  end
  
  ///////////////////
  // Generate clk //
  /////////////////
  always
    #10 clk = ~clk;

  ///////////////////////
  // Generate cadence //
  /////////////////////
  always begin
    repeat(2048) begin
      @(posedge clk);
    end
    cadence = ~cadence;
  end
    

  
  //maybe use a task to change the frequency of cadence?

  ///////////////////////////////////////////
  // Block for cadence signal generation? //
  /////////////////////////////////////////
	

  /*//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  /                                                        TASKS                                                                     /
  *///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  task init();
    clr_rdy = 1'b0;
    clk = 1'b0;
    RST_n = 1'b0;
    cadence = 1'b0;
    BATT = 12'hfff;
    BRAKE = 12'hFFF;
    TORQUE = 12'h000;
    tgglMd = 1'b0;
    YAW_RT = 16'h0;
    @(posedge clk);
    @(negedge clk);
    RST_n = 1'b1;
  endtask

  /**
  * Check that the torque and current values are corre
  */
  task telemetryTest();
        // We don't stimulate current in our TB, so just visually check for reasonable waveforms
        BATT = $random()%13'h1000;
        TORQUE = $random()%13'h1000;
        // First cycle of telemetry reads will be 0 because of delay in inertial integrator 
        repeat(8) begin
          @(posedge rdy);
          clr_rdy = 1;
          @(posedge clk);
          clr_rdy = 0;
        end
      
        // BYTE 1 CHECK &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
        @(posedge rdy);
        clr_rdy = 1;
        if(rx_data != 8'hAA) begin
            $error("Byte 1 incorrectly recieved!");
            $stop();
        end
        @(posedge clk);
        clr_rdy = 0;
        // BYTE 2 CHECK &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
        @(posedge rdy);
        clr_rdy = 1;
        if(rx_data != 8'h55) begin
            $error("Byte 2 incorrectly recieved!");
            $stop();
        end
        @(posedge clk);
        clr_rdy = 0;
        // BYTE 3 CHECK &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
        @(posedge rdy);
        clr_rdy = 1;
        if(rx_data != {4'h0, BATT[11:8]}) begin
           $error("Byte 3 incorrectly recieved!");
           $stop();
        end
        @(posedge clk);
        clr_rdy = 0;
        // BYTE 4 CHECK &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
        @(posedge rdy);
        clr_rdy = 1;
        if(rx_data != BATT[7:0]) begin
            $error("Byte 4 incorrectly recieved!");
            $stop();
        end
        @(posedge clk);
        clr_rdy = 0;
        // BYTE 5 CHECK &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
        @(posedge rdy);
        clr_rdy = 1;
        // 4'h0, top 4 bits of current should be on the waveform here
        @(posedge clk);
        clr_rdy = 0;
        // BYTE 6 CHECK &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
        @(posedge rdy);
        clr_rdy = 1;
        // low 8 bits of current should be on the waveform here
        @(posedge clk);
        clr_rdy = 0;
        // BYTE 7 CHECK &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
        @(posedge rdy);
        clr_rdy = 1;
        if(rx_data != {4'h0, TORQUE[11:8]}) begin
           $error("Byte 7 incorrectly recieved!");
           $stop();
        end
        @(posedge clk);
        clr_rdy = 0;
        // BYTE 8 CHECK &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
        @(posedge rdy);
        clr_rdy = 1;
        if((rx_data > (TORQUE[7:0] + 8'd10)) | (rx_data < (TORQUE[7:0] - 8'd10))) begin // When the TORQUE is held constant, avg should be within 1-2 of the held value
           $error("Byte 8 incorrectly recieved!");
           $stop();
        end
        @(posedge clk);
        clr_rdy = 0;
  endtask

  /*
  * Test that setting torque to higher/lower values increases/decreases current and related signals (non-self checking)
  */
  task torqueTest();
    //set torque to initial value: hold for some amount of time?
    TORQUE=12'h500;
    //just wait for a bunch of clock cyles to observe the thing?
    repeat(1000000)begin
      @(posedge clk) begin
      end
    end

    TORQUE=12'h000;
    //just wait for a bunch of clock cyles to observe the thing?
    repeat(1000000)begin
      @(posedge clk) begin
      end
    end

    TORQUE=12'h700;
    //just wait for a bunch of clock cyles to observe the thing?
    repeat(1000000)begin
      @(posedge clk) begin
      end
    end
  endtask

  /*
  * Test that increasing/decreasing incline increases/decreases the current supplied to the motor. This test is not
  * self checking.
  */
  task inclineTest();
    // Start off with zero incline, ensure current reaches constant level with given torque
    TORQUE = 12'h0500;
    YAW_RT = 16'h0000;
    repeat(1000000)
      @(posedge clk);
    // set the incline to be steep uphill, should cause a gradual increase in current
    YAW_RT = 16'h2000;
    repeat(1000000)
      @(posedge clk);
    // set the incline to be steep downhill, should cause a gradual decrease in current
    YAW_RT = 16'hE000;
    repeat(1000000)
      @(posedge clk);
    $stop();
  endtask

  /*
  * Check that the bike resets to medium pedal assist, and that it switches mode, scale, and current when the
  * button is pushed. This IS a self-checking testbench
  */
  task tgglMdTest();
    $display("beginning tgglMd Test");
    //check if its in the 10 state, AND That the output value is 101
    //state and values:
    //00->000
    //01->011
    //10->101
    //11->111
    @(posedge clk) begin
      if (iDUT.scale != 3'b101)
        $error("Incorrect scale value in reset state. Expected: 101, actual:%b", iDUT.scale);
    end
    //after, setting high,s hould be 111
    @(posedge clk) begin
      tgglMd <= 1'b0;
    end
    //wait for a bit
    repeat (2000) begin
      @(posedge clk) begin
      end
    end
    //release the button
    @(posedge clk) begin
      tgglMd <= 1'b1;
    end

    repeat (100) begin
      @(posedge clk) begin
      end
    end

    @(posedge clk) begin
      if (iDUT.scale != 3'b111)
        $error("Incorrect scale value in reset state. Expected: 111, actual:%b", iDUT.scale);
    end

    @(posedge clk) begin
      tgglMd <= 1'b0;
    end
    //wait for a bit
    repeat (2000) begin
      @(posedge clk) begin
      end
    end
    //release the button
    @(posedge clk) begin
      tgglMd <= 1'b1;
    end

    repeat (100) begin
      @(posedge clk) begin
      end
    end

    @(posedge clk) begin
      if (iDUT.scale != 3'b000)
        $error("Incorrect scale value in reset state. Expected: 000, actual:%b", iDUT.scale);
    end

    @(posedge clk) begin
      tgglMd <= 1'b0;
    end
    //wait for a bit
    repeat (2000) begin
      @(posedge clk) begin
      end
    end
    //release the button
    @(posedge clk) begin
      tgglMd <= 1'b1;
    end

    repeat (100) begin
      @(posedge clk) begin
      end
    end

    @(posedge clk) begin
      if (iDUT.scale != 3'b011)
        $error("Incorrect scale value in reset state. Expected: 011, actual:%b", iDUT.scale);
    end

    repeat (50000) begin
      @(posedge clk) begin
      end
    end
    $display("YAHOO! passed tgglMd test");
  endtask

  task cadenceTest();
  endtask

  /*
  * Check that applying the brakes during motor assist cuts off all current,
    which should shoot back up when the brake lever is depressed. This is a non-self checking testbench.
  */
  task brakeTest();
    //just wait for a bunch of clock cyles to let current build
    TORQUE = 12'h700;
    repeat(1000000)begin
      @(posedge clk) begin
      end
    end
    // apply brake for a few cycles
    BRAKE = 12'h000;  
    repeat(1000000)
     @(posedge clk);
    BRAKE = 12'hFFF;
    // current should build back up after brake was applied
    repeat(2000000)begin
      @(posedge clk) begin
      end
    end
  endtask

endmodule

