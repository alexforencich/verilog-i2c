// Language: Verilog 2001

`timescale 1ns / 1ps

/*
 * Testbench for i2c_master
 */
module i2c_master_tb;

  // Parameters

  parameter CLK_PERIOD = 10;  // 10ns clock period (100MHz clock)
  parameter ENABLE_DEVICE_3 = 1;  // Set to 0 to disable device 3
  parameter ENABLE_DEVICE_4 = 1;  // Set to 0 to disable device 4

  reg clk = 0;
  reg rst = 0;
  wire rst_n;
  assign rst_n=~rst;
  reg [7:0] current_test = 0;

  // I2C master signals
  reg [6:0] s_axis_cmd_address = 0;
  reg s_axis_cmd_start = 0;
  reg s_axis_cmd_read = 0;
  reg s_axis_cmd_write = 0;
  reg s_axis_cmd_write_multiple = 0;
  reg s_axis_cmd_stop = 0;
  reg s_axis_cmd_valid = 0;
  reg [7:0] s_axis_data_tdata = 0;
  reg s_axis_data_tvalid = 0;
  reg s_axis_data_tlast = 0;
  reg m_axis_data_tready = 0;
  reg scl_i = 1;
  reg sda_i = 1;
  reg [15:0] prescale = 0;
  reg stop_on_idle = 0;


  wire s_axis_cmd_ready;
  wire s_axis_data_tready;
  wire [7:0] m_axis_data_tdata;
  wire m_axis_data_tvalid;
  wire m_axis_data_tlast;
  wire scl_o;
  wire scl_t;
  wire sda_o;
  wire sda_t;
  wire busy;
  wire bus_control;
  wire bus_active;
  wire missed_ack;
  wire value_has_been_written;  //never used

  // Wires for modeling pull-up resistors and open-drain outputs
  wire scl_wire;
  wire sda_wire;

  // Dummy registers
  reg sda2 = 1;
  reg scl2 = 1;

  task wait_for_success;
    reg continue_waiting;
    begin
      continue_waiting = 1;
      while (continue_waiting) begin
        @(posedge missed_ack or posedge value_has_been_written or posedge m_axis_data_tvalid or posedge s_axis_cmd_stop);
        if (missed_ack) begin
          s_axis_data_tvalid = 1;
          $display("missed ack detected we retry happily?");
        end else if (value_has_been_written | m_axis_data_tvalid | s_axis_cmd_stop) begin
          s_axis_data_tvalid = 0;
          s_axis_cmd_valid   = 0;
          continue_waiting   = 0;
        end
      end
    end
  endtask
  // Generate block for Device 3
  generate
    if (ENABLE_DEVICE_3) begin : device_3
      wire sda_o_3;
      wire sda_t_3;
      wire scl_o_3;
      wire scl_t_3;
      reg [7:0] data_in_3;
      reg data_latch_3;
      wire [7:0] data_out_3;

      i2c_single_reg #(
          .FILTER_LEN(4),
        .DEV_ADDR  (7'h70),
        .DEBUG(1)
      ) i2c_reg (
          .clk(clk),
          .rst_n,
          .scl_i(scl_wire),
          .scl_o(scl_o_3),
          .scl_t(scl_t_3),
          .sda_i(sda_wire),
          .sda_o(sda_o_3),
          .sda_t(sda_t_3),
          .data_in(data_in_3),
          .data_latch(data_latch_3),
          .data_out(data_out_3)
      );


      // Task to test i2c_single_reg writing
      task test_i2c_single_reg_writing;
        begin
          $display("Testing i2c_single_reg writing");
          //wait_for_ready();
          i2c_start(7'h70, 0);
          s_axis_data_tdata  = 8'd55;
          s_axis_data_tvalid = 1;
          wait_for_success;

          wait_for_ready();
          if (data_out_3 != 8'd55) $fatal(1, "We didn't get what we sent");
          $display("Received data %d", data_out_3);
        end
      endtask

      // Task to test i2c_single_reg reading
      task test_i2c_single_reg_reading;
        begin
          $display("Testing i2c_single_reg reading");
          data_latch_3 = 1;
          data_in_3 = 8'd123;
          m_axis_data_tready = 1;
          #(CLK_PERIOD);
          data_latch_3 = 0;
          i2c_start(7'h70, 1);
          wait_for_success;
          //@(posedge m_axis_data_tvalid);
          $display("Received m_axis_data_tdata %d", m_axis_data_tdata);
          if (m_axis_data_tdata != 8'd123) $fatal(1, "We didn't get what we sent");
        end
      endtask

    end else begin : device_3
      wire scl_o_3 = 1'b1;
      wire sda_o_3 = 1'b1;
      reg  data_out_3 = 1'b1;

      task test_i2c_single_reg_writing;
        $display("not implemented");
      endtask

      // Task to test i2c_single_reg reading
      task test_i2c_single_reg_reading;
        $display("not implemented");
      endtask


    end
  endgenerate

  // Generate block for Device 4
  generate
    if (ENABLE_DEVICE_4) begin : device_4
      wire sda_o_4;
      wire sda_t_4;
      wire scl_o_4;
      wire scl_t_4;
      wire [7:0] m_axis_data_tdata_4;
      wire m_axis_data_tvalid_4;
      reg m_axis_data_tready_4;
      wire m_axis_data_tlast_4;
      reg [7:0] s_axis_data_tdata_4;
      reg s_axis_data_tvalid_4;
      wire s_axis_data_tready_4;
      reg s_axis_data_tlast_4;
      wire busy_4;
      wire [6:0] bus_address_4;
      wire bus_addressed_4;
      wire bus_active_4;
      reg release_bus_4;
      reg enable_4;
      reg [6:0] device_address_4;
      reg [6:0] device_address_mask_4;

      i2c_slave #(
          .FILTER_LEN(4)
      ) i2c_slave_inst (
          .clk(clk),
          .rst_n,
          .release_bus(release_bus_4),
          .s_axis_data_tdata(s_axis_data_tdata_4),
          .s_axis_data_tvalid(s_axis_data_tvalid_4),
          .s_axis_data_tready(s_axis_data_tready_4),
          .s_axis_data_tlast(s_axis_data_tlast_4),
          .m_axis_data_tdata(m_axis_data_tdata_4),
          .m_axis_data_tvalid(m_axis_data_tvalid_4),
          .m_axis_data_tready(m_axis_data_tready_4),
          .m_axis_data_tlast(m_axis_data_tlast_4),
          .scl_i(scl_wire),
          .scl_o(scl_o_4),
          .scl_t(scl_t_4),
          .sda_i(sda_wire),
          .sda_o(sda_o_4),
          .sda_t(sda_t_4),
          .busy(busy_4),
          .bus_address(bus_address_4),
          .bus_addressed(bus_addressed_4),
          .bus_active(bus_active_4),
          .enable(enable_4),
          .device_address(device_address_4),
          .device_address_mask(device_address_mask_4)
      );

      task test_write_to_i2c_slave;
        begin
          $display("Testing writing to i2c_slave (device_4)");
          enable_4 = 1;
          device_address_4 = 7'h42;  // Set slave address
          device_address_mask_4 = 7'h7F;  // Check all bits

          i2c_start(7'h42, 0);  // Start write operation
          s_axis_data_tdata = 8'hAA;  // Data to write
          s_axis_data_tvalid = 1;
          stop_on_idle = 1;
          wait_for_success;

          wait_for_ready();

          if (m_axis_data_tdata_4 !== 8'hAA) $fatal(1, "First byte mismatch");
          s_axis_data_tdata  = 8'h55;  // Second byte to write
          s_axis_data_tvalid = 1;
          s_axis_cmd_valid   = 1;  //still valid
          s_axis_cmd_write   = 1;  //really write the second

          wait_for_ready();
          #(CLK_PERIOD * 120);  //for verilator
          if (m_axis_data_tdata_4 !== 8'h55) begin
            // It seems verilator has trouble with this
            $display("instead of 55 we get %h", m_axis_data_tdata_4);
            $fatal(1, "Second byte mismatch");
          end

          s_axis_cmd_valid = 0;
          wait_for_ready();

          #(CLK_PERIOD * 10);  // Wait for slave to process

          $display("Write to i2c_slave successful");
        end
      endtask

      // Task to test reading from i2c_slave
      task test_read_from_i2c_slave;
        begin
          $display("Testing reading from i2c_slave (device_4)");
          enable_4 = 1;
          device_address_4 = 7'h42;  // Set slave address
          device_address_mask_4 = 7'h7F;  // Check all bits

          // Prepare data to be read
          s_axis_data_tdata_4 = 8'hCC;
          s_axis_data_tvalid_4 = 1;
          i2c_start(7'h42, 1);  // Start read operation
          m_axis_data_tready = 1;
          $display("i2c start was started and now waiting for m_axis_data_tvalid..");
          wait_for_success;
          s_axis_data_tvalid_4 = 0;
          if (m_axis_data_tdata !== 8'hCC) $fatal(1, "First read byte mismatch");

          s_axis_cmd_valid = 1;  //read 2 times
          s_axis_cmd_read = 1;
          s_axis_data_tvalid_4 = 1;
          s_axis_data_tdata_4 = 8'hDD;
          wait_for_success;
          if (m_axis_data_tdata !== 8'hDD) $fatal(1, "Second read byte mismatch");

          s_axis_cmd_valid = 0;
          wait_for_ready();

          $display("Read from i2c_slave successful");
        end
      endtask

      // Task to test bus release, incomplete (not done)
      task test_bus_release;
        begin
          $display("Testing bus release for i2c_slave (device_4)");
          enable_4 = 1;
          device_address_4 = 7'h42;  // Set slave address
          device_address_mask_4 = 7'h7F;  // Check all bits

          i2c_start(7'h42, 0);  // Start write operation
          #(CLK_PERIOD * 10);

          if (!bus_active_4) $fatal(1, "Bus should be active");

          release_bus_4 = 1;
          #(CLK_PERIOD);
          release_bus_4 = 0;

          #(CLK_PERIOD * 10);

          if (bus_active_4) $fatal(1, "Bus should not be active after release");

          $display("Bus release test successful");
        end
      endtask

    end else begin : device_4
      wire scl_o_4 = 1'b1;
      wire sda_o_4 = 1'b1;
      reg  m_axis_data_tready_4 = 0;

      task test_write_to_i2c_slave;
        begin
          $display("not implemented");
        end
      endtask
      task test_read_from_i2c_slave;
        begin
          $display("not implemented");
        end
      endtask

    end

  endgenerate

  // Model pull-up resistors with weak pull-ups
  pullup (scl_wire);
  pullup (sda_wire);

  // Model open-drain outputs, including conditional devices
  assign scl_wire = (scl_o & scl2 & device_3.scl_o_3 & device_4.scl_o_4) ? 1'bz : 1'b0;
  assign sda_wire = (sda_o & sda2 & device_3.sda_o_3 & device_4.sda_o_4) ? 1'bz : 1'b0;


  always #(CLK_PERIOD / 2) clk <= ~clk;

  // Sample the bus with non-blocking assignments to avoid race conditions
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      scl_i <= 1'b1;
      sda_i <= 1'b1;
    end else begin
      scl_i <= scl_wire;
      sda_i <= sda_wire;

      // Assert that sda_i is not X
      if (sda_i === 1'bx) begin

        $display("sda4 %d", device_4.sda_o_4);

        $fatal(1, "sda_i is X at time %t", $time);
      end
    end
  end

  initial begin
    // dump file
    $dumpfile("i2c_master_tb.vcd");
    $dumpvars(0, i2c_master_tb);

  end

  i2c_master UUT (
      .clk(clk),
      .rst_n,
      .s_axis_cmd_address(s_axis_cmd_address),
      .s_axis_cmd_start(s_axis_cmd_start),
      .s_axis_cmd_read(s_axis_cmd_read),
      .s_axis_cmd_write(s_axis_cmd_write),
      .s_axis_cmd_write_multiple(s_axis_cmd_write_multiple),
      .s_axis_cmd_stop(s_axis_cmd_stop),
      .s_axis_cmd_valid(s_axis_cmd_valid),
      .s_axis_cmd_ready(s_axis_cmd_ready),
      .s_axis_data_tdata(s_axis_data_tdata),
      .s_axis_data_tvalid(s_axis_data_tvalid),
      .s_axis_data_tready(s_axis_data_tready),
      .s_axis_data_tlast(s_axis_data_tlast),
      .m_axis_data_tdata(m_axis_data_tdata),
      .m_axis_data_tvalid(m_axis_data_tvalid),
      .m_axis_data_tready(m_axis_data_tready),
      .m_axis_data_tlast(m_axis_data_tlast),
      .scl_i(scl_i),
      .scl_o(scl_o),
      .scl_t(scl_t),
      .sda_i(sda_i),
      .sda_o(sda_o),
      .sda_t(sda_t),
      .busy(busy),
      .bus_control(bus_control),
      .bus_active(bus_active),
      .missed_ack(missed_ack),
      .value_has_been_written(value_has_been_written),
      .prescale(prescale),
      .stop_on_idle(stop_on_idle)
  );

  task initialize_testbench;
    begin
      clk = 0;
      rst = 1;
      s_axis_cmd_address = 0;
      s_axis_cmd_start = 0;
      s_axis_cmd_read = 0;
      s_axis_cmd_write = 0;
      s_axis_cmd_write_multiple = 0;
      s_axis_cmd_stop = 0;
      s_axis_cmd_valid = 0;
      s_axis_data_tdata = 0;
      s_axis_data_tvalid = 0;
      s_axis_data_tlast = 0;
      m_axis_data_tready = 0;
      scl_i = 1;
      sda_i = 1;
      prescale = 0;
      stop_on_idle = 0;
      sda2 = 1;
      scl2 = 1;

      #10 rst = 0;
    end
  endtask

  task i2c_start;
    input [6:0] address;
    input is_read;
    begin
      s_axis_cmd_address = address;
      //s_axis_cmd_start = 1;
      s_axis_cmd_read = is_read;
      s_axis_cmd_write = !is_read;
      s_axis_cmd_valid = 1;

      //cant enforce anyway

      //@(negedge sda_wire);
      //@(negedge scl_wire);  //start condition done! 

      //s_axis_cmd_start = 0;
      //s_axis_cmd_read  = 0;
      //s_axis_cmd_write = 0;
      //s_axis_cmd_valid = 0;
    end
  endtask

  task send_byte;
    input [7:0] byte_to_send;
    integer i;
    begin
      for (i = 7; i >= 0; i = i - 1) begin
        sda2 = byte_to_send[i];
        @(negedge scl_o);
      end
    end

  endtask

  task wait_for_ready;
    begin
      $display("Waiting for ready");
      @(posedge s_axis_cmd_ready);
      #CLK_PERIOD;
    end
  endtask

  task send_ack;
    begin
      @(negedge scl_o);
      sda2 = 0;
      #CLK_PERIOD;
      @(negedge scl_o);
      sda2 = 1;
    end
  endtask

  // Task to test NACK handling
  task test_nack_handling;
    begin
      $display("Testing NACK handling.");
      i2c_start(7'b0000001, 0);
      s_axis_data_tdata  = 8'b10100101;
      s_axis_data_tvalid = 1;
      @(posedge missed_ack);
      $display("NACK expected!");
      wait_for_ready();
    end
  endtask

  // Task to test writing
  task test_writing;
    begin
      $display("Testing Writing.");
      i2c_start(7'b0000001, 0);
      s_axis_data_tdata  = 8'b10101111;
      s_axis_data_tvalid = 1;
      repeat (7) @(negedge scl_o);
      s_axis_cmd_valid = 0;
      send_ack();
      @(negedge scl_o);
      //send_byte(8'b01111111);
      wait_for_ready();
    end
  endtask
  // Task to test writing
  task test_write_weird;
    begin
      $display("Testing something write weird.");
      i2c_start(7'h70, 0);
      $display("send address?");
      @(posedge s_axis_data_tready);
      s_axis_data_tdata  = 8'b10101111;
      s_axis_data_tvalid = 1;
      wait_for_success;
      $display("success %b", device_3.data_out_3);
      //wait 1000 cycles
      #1000;
      s_axis_cmd_valid   = 1;
      s_axis_data_tdata  = 8'd2;
      s_axis_data_tvalid = 1;
      wait_for_success;
      $display("success %b", device_3.data_out_3);
      #1000;
      stop_on_idle = 1;

      //repeat (7) @(negedge scl_o);
      //send_ack();
      //@(negedge scl_o);
      //send_byte(8'b01111111);
      wait_for_ready();
    end
  endtask

  task test_read_weird;
    begin
      stop_on_idle = 0;
      $display("Testing something read weird.");
      i2c_start(7'h70, 1);
      m_axis_data_tready = 1;
      wait_for_success;
      m_axis_data_tready = 0;
      $display("success %b", m_axis_data_tdata);
      //wait 1000 cycles
      #1000;
      s_axis_cmd_valid   = 1;
      m_axis_data_tready = 1;
      wait_for_success;
      $display("success %b", m_axis_data_tdata);
      #1000;
      stop_on_idle = 1;

      //repeat (7) @(negedge scl_o);
      //send_ack();
      //@(negedge scl_o);
      //send_byte(8'b01111111);
      wait_for_ready();
    end
  endtask


  // Task to test reading
  task test_reading;
    begin
      $display("Testing reading.");
      s_axis_data_tdata  = 8'b10101111;
      s_axis_data_tvalid = 1;
      i2c_start(7'b0000001, 1);
      repeat (8) @(negedge scl_o);
      s_axis_cmd_valid = 0;
      send_ack();
      send_byte(8'b01111111);
      s_axis_cmd_read = 1;
      s_axis_cmd_valid = 1;
      m_axis_data_tready = 1;
      @(negedge scl_o);

      if (sda_wire) #1000 $fatal(1, "Got NACK from master");
      $display("Received m_axis_data_tdata %d", m_axis_data_tdata);
      if (m_axis_data_tdata != 8'b01111111) $fatal(1, "We didn't get what we sent");
      #(CLK_PERIOD);
      stop_on_idle = 1;
      send_byte(8'd69);
      @(posedge m_axis_data_tvalid);
      if (m_axis_data_tdata != 8'd69) $fatal(1, "We didn't get what we sent");
      $display("Received m_axis_data_tdata %d", m_axis_data_tdata);
      s_axis_cmd_valid = 0;
      wait_for_ready();
    end
  endtask
  // Task to test writing to i2c_slave
  initial begin
    /*new goal: read 1, then decide wether to stop or read 2. both options
    * must be allowed*/
    $display("Starting I2C Master test");
    initialize_testbench;
    stop_on_idle = 1;
    device_3.test_i2c_single_reg_writing();
    test_nack_handling();  //killing time for dev3 it needs time to initialize
    test_read_weird();
    device_3.test_i2c_single_reg_writing();
    stop_on_idle = 0;
    test_write_weird();
    test_writing();

    #1000;  //stopping

    test_reading();
    wait_for_ready();
    device_3.test_i2c_single_reg_reading();
    #1000;  //stopping
    //we are always ready
    device_4.m_axis_data_tready_4 = 1;
    device_4.test_write_to_i2c_slave();
    device_4.test_read_from_i2c_slave();
    // test_bus_release();

    #1000;
    $finish;
  end
endmodule
