`timescale 1ns / 1ps

module i2c_phy_tb;

  // Parameters
  parameter CLK_PERIOD = 10;  // 10ns clock period (100MHz clock)

  // Signals
  reg clk = 0;
  reg rst = 1;
  reg phy_start_bit = 0;
  reg phy_stop_bit = 0;
  reg phy_write_bit = 0;
  reg phy_read_bit = 0;
  reg phy_tx_data = 0;
  reg phy_release_bus = 0;
  reg scl_i = 1;//Technically they are not registers but in testbench we need to store them somewhere
  wire scl_o;
  reg sda_i = 1;
  wire sda_o;
  reg sda2 = 1;  //dummy registers
  reg scl2 = 1;
  wire sda_t;
  wire scl_t;
  wire phy_busy;
  wire bus_control_reg;
  wire phy_rx_data_reg;
  wire [4:0] phy_state_reg;

  // Clock generation
  always #(CLK_PERIOD / 2) clk <= ~clk;

  // Tri-state buffer modeling
  wire scl_wire;
  wire sda_wire;

  reg scl_i_reg_tb, sda_i_reg_tb;
  // Model pull-up resistors with weak pull-ups
  pullup (scl_wire);
  pullup (sda_wire);

  // Model open-drain outputs
  assign scl_wire = (scl_o & scl2) ? 1'bz : 1'b0;
  assign sda_wire = (sda_o & sda2) ? 1'bz : 1'b0;

  // Sample the bus with non-blocking assignments to avoid race conditions
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      scl_i_reg_tb <= 1'b1;
      sda_i_reg_tb <= 1'b1;
    end else begin
      scl_i_reg_tb <= scl_wire;
      sda_i_reg_tb <= sda_wire;

      // Assert that sda_i_reg is not X
      if (sda_i_reg_tb === 1'bx) $fatal(1, "sda_i_reg is X at time %t", $time);
    end
  end



  // Instantiate the i2c_phy module
  i2c_phy uut (
      .clk(clk),
      .rst(rst_n),
      .phy_start_bit(phy_start_bit),
      .phy_stop_bit(phy_stop_bit),
      .phy_write_bit(phy_write_bit),
      .phy_read_bit(phy_read_bit),
      .phy_tx_data(phy_tx_data),
      .phy_release_bus(phy_release_bus),
      .scl_i(scl_i_reg_tb),
      .scl_o(scl_o),
      .sda_i(sda_i_reg_tb),
      .sda_o(sda_o),
      .sda_t(sda_t),
      .scl_t(scl_t),
      .phy_busy(phy_busy),
      .bus_control_reg(bus_control_reg),
      .phy_rx_data_reg(phy_rx_data_reg),
      .phy_state_reg(phy_state_reg),
      .prescale(17'd3)
  );
  task initialize;
    begin
      rst = 0;
      phy_start_bit = 0;
      phy_stop_bit = 0;
      phy_write_bit = 0;
      phy_read_bit = 0;
      phy_tx_data = 0;
      phy_release_bus = 0;
    end
  endtask

  task reset;
    begin
      rst = 0;
      #(CLK_PERIOD * 5);
      rst = 1;
      #(CLK_PERIOD * 5);
    end
  endtask
  task write_operation(input tx_data);
    begin
      wait (phy_state_reg == 5'd1);  // Wait for PHY_STATE_ACTIVE
      phy_write_bit = 1;
      phy_tx_data   = tx_data;
      #(CLK_PERIOD * 2);
    end
  endtask
  task read_operation;
    begin
      wait (phy_state_reg == 5'd1);  // Wait for PHY_STATE_ACTIVE
      phy_write_bit = 0;
      phy_read_bit  = 1;
      #(CLK_PERIOD * 2);
    end
  endtask

  task wait_for_idle;
    begin
      wait (phy_state_reg == 5'd0);  // Assuming PHY_STATE_IDLE is 5'd0
    end
  endtask

  // Specific test scenarios
  task test_write_byte;
    begin
      $display("Testing write byte operation");
      phy_start_bit = 1;
      #(CLK_PERIOD);
      phy_start_bit = 0;

      // Write byte 0x81 (10000001)
      write_operation(1);
      write_operation(0);
      write_operation(0);
      write_operation(0);
      write_operation(0);
      write_operation(0);
      write_operation(0);
      write_operation(1);

      // Read ACK
      //Send ACK
      sda2 = 0;
      read_operation;
      wait (phy_state_reg == 5'd1);  // Wait for PHY_STATE_ACTIVE
      sda2 = 1;  //pull sda2 back up
      if (phy_rx_data_reg != 0) $finish(1,"Expecting ACK but found NACK: %d ", phy_rx_data_reg);
    end
  endtask

  task test_read_byte;
    begin
      $display("Testing read byte operation");
      phy_start_bit = 1;
      #(CLK_PERIOD);
      phy_start_bit = 0;

      // Send read command (e.g., 0xA1 for read)
      write_operation(1);
      write_operation(0);
      write_operation(1);
      write_operation(0);
      write_operation(0);
      write_operation(0);
      write_operation(0);
      write_operation(1);

      // Read ACK
      read_operation;

      // Read byte
      repeat (8) begin
        read_operation;
      end

      // Send NACK
      write_operation(1);
    end
  endtask

  // Main test procedure
  initial begin
    $display("Starting I2C PHY Test");
    initialize;
    $display("Initialized");
    reset;
    $display("reseted");

    $display("Test write");
    test_write_byte;
    $display("Test idle?");
    //wait_for_idle;

    //test_read_byte;
    //wait_for_idle;

    $display("I2C PHY Test Completed");
    $finish;
  end
  // Optional: Dump waveforms
  initial begin
    $dumpfile("i2c_phy_tb.vcd");
    $dumpvars(0, i2c_phy_tb);
  end

endmodule
