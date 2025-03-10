
`timescale 1ns / 1ps
module i2c_phy (
    input wire clk,
    input wire rst_n,

    // Control signals
    input wire phy_start_bit,
    input wire phy_stop_bit,
    input wire phy_write_bit,
    input wire phy_read_bit,
    input wire phy_tx_data,
    input wire phy_release_bus,

    // I2C interface
    input  wire scl_i,
    output wire scl_o,
    input  wire sda_i,
    output wire sda_o,
    output wire sda_t,
    output wire scl_t,

    // Status and data
    output reg phy_busy = 1'b0,
    output reg bus_control_reg,
    output reg phy_rx_data_reg,
    output reg [4:0] phy_state_reg,

    // Configuration
    input wire [16:0] prescale
);
  localparam [4:0]
    PHY_STATE_IDLE = 5'd0,
    PHY_STATE_ACTIVE = 5'd1,
    PHY_STATE_REPEATED_START_1 = 5'd2,
    PHY_STATE_REPEATED_START_2 = 5'd3,
    PHY_STATE_START_1 = 5'd4,
    PHY_STATE_START_2 = 5'd5,
    PHY_STATE_WRITE_BIT_1 = 5'd6,
    PHY_STATE_WRITE_BIT_2 = 5'd7,
    PHY_STATE_WRITE_BIT_3 = 5'd8,
    PHY_STATE_READ_BIT_1 = 5'd9,
    PHY_STATE_READ_BIT_2 = 5'd10,
    PHY_STATE_READ_BIT_3 = 5'd11,
    PHY_STATE_READ_BIT_4 = 5'd12,
    PHY_STATE_STOP_1 = 5'd13,
    PHY_STATE_STOP_2 = 5'd14,
    PHY_STATE_STOP_3 = 5'd15;



  // Internal registers

  reg scl_o_reg = 1;
  reg scl_i_reg = 1;
  reg sda_i_reg = 1;
  reg sda_o_reg = 1;


  reg phy_rx_data_next = 0;

  reg [4:0] phy_state_next;

  reg [16:0] delay_reg = 17'd0, delay_next;
  reg delay_scl_reg = 1'b0, delay_scl_next;
  reg delay_sda_reg = 1'b0, delay_sda_next;

  reg scl_o_next = 1;
  reg sda_o_next = 1;

  reg bus_control_next = 0;

  assign scl_o = scl_o_reg;
  assign scl_t = scl_o_reg;
  assign sda_o = sda_o_reg;
  assign sda_t = sda_o_reg;


  always @* begin
    phy_state_next = PHY_STATE_IDLE;

    phy_rx_data_next = phy_rx_data_reg;

    delay_next = delay_reg;
    delay_scl_next = delay_scl_reg;
    delay_sda_next = delay_sda_reg;

    scl_o_next = scl_o_reg;
    sda_o_next = sda_o_reg;

    bus_control_next = bus_control_reg;

    if (phy_release_bus) begin
      // release bus and return to idle state
      sda_o_next = 1'b1;
      scl_o_next = 1'b1;
      delay_scl_next = 1'b0;
      delay_sda_next = 1'b0;
      delay_next = 17'd0;
      phy_state_next = PHY_STATE_IDLE;
    end else if (delay_scl_reg) begin
      // wait for SCL to match command
      delay_scl_next = scl_o_reg & ~scl_i_reg;
      phy_state_next = phy_state_reg;
    end else if (delay_sda_reg) begin
      // wait for SDA to match command
      delay_sda_next = sda_o_reg & ~sda_i_reg;
      phy_state_next = phy_state_reg;
    end else if (delay_reg > 0) begin
      // time delay
      delay_next = delay_reg - 1;
      phy_state_next = phy_state_reg;
    end else begin
      case (phy_state_reg)
        PHY_STATE_IDLE: begin
          //$display("idle, simply wait");
          // bus idle - wait for start command
          sda_o_next = 1'b1;
          scl_o_next = 1'b1;
          if (phy_start_bit) begin
            //$display("idle, ");
            sda_o_next = 1'b0;
            delay_next = prescale;
            phy_state_next = PHY_STATE_START_1;
          end else begin
            phy_state_next = PHY_STATE_IDLE;
          end
        end
        PHY_STATE_ACTIVE: begin
          // bus active
          if (phy_start_bit) begin
            //$display("start bit should have reset");

            sda_o_next = 1'b1;
            delay_next = prescale;
            phy_state_next = PHY_STATE_REPEATED_START_1;
          end else if (phy_write_bit) begin
            sda_o_next = phy_tx_data;
            delay_next = prescale;
            phy_state_next = PHY_STATE_WRITE_BIT_1;
          end else if (phy_read_bit) begin
            sda_o_next = 1'b1;
            delay_next = prescale;
            phy_state_next = PHY_STATE_READ_BIT_1;
          end else if (phy_stop_bit) begin
            sda_o_next = 1'b0;
            delay_next = prescale;
            phy_state_next = PHY_STATE_STOP_1;
          end else begin
            //$display("Do nothing, leave things as is");
            phy_state_next = PHY_STATE_ACTIVE;
          end
        end
        PHY_STATE_REPEATED_START_1: begin
          // generate repeated start bit
          //         ______
          // sda XXX/      \_______
          //            _______
          // scl ______/       \___
          //

          scl_o_next = 1'b1;
          delay_scl_next = 1'b1;
          delay_next = prescale;
          phy_state_next = PHY_STATE_REPEATED_START_2;
        end
        PHY_STATE_REPEATED_START_2: begin
          // generate repeated start bit
          //         ______
          // sda XXX/      \_______
          //            _______
          // scl ______/       \___
          //

          sda_o_next = 1'b0;
          delay_next = prescale;
          phy_state_next = PHY_STATE_START_1;
        end
        PHY_STATE_START_1: begin
          // generate start bit
          //     ___
          // sda    \_______
          //     _______
          // scl        \___
          //

          scl_o_next = 1'b0;
          delay_next = prescale;
          phy_state_next = PHY_STATE_START_2;
        end
        PHY_STATE_START_2: begin
          // generate start bit
          //     ___
          // sda    \_______
          //     _______
          // scl        \___
          //

          bus_control_next = 1'b1;
          phy_state_next   = PHY_STATE_ACTIVE;
        end
        PHY_STATE_WRITE_BIT_1: begin
          // write bit
          //      ________
          // sda X________X
          //        ____
          // scl __/    \__

          scl_o_next = 1'b1;
          delay_scl_next = 1'b1;
          delay_next = prescale << 1;
          phy_state_next = PHY_STATE_WRITE_BIT_2;
        end
        PHY_STATE_WRITE_BIT_2: begin
          // write bit
          //      ________
          // sda X________X
          //        ____
          // scl __/    \__

          scl_o_next = 1'b0;
          delay_next = prescale;
          phy_state_next = PHY_STATE_WRITE_BIT_3;
        end
        PHY_STATE_WRITE_BIT_3: begin
          // write bit
          //      ________
          // sda X________X
          //        ____
          // scl __/    \__

          phy_state_next = PHY_STATE_ACTIVE;
        end
        PHY_STATE_READ_BIT_1: begin
          // read bit
          //      ________
          // sda X________X
          //        ____
          // scl __/    \__

          scl_o_next = 1'b1;
          delay_scl_next = 1'b1;
          delay_next = prescale;
          phy_state_next = PHY_STATE_READ_BIT_2;
        end
        PHY_STATE_READ_BIT_2: begin
          // read bit
          //      ________
          // sda X________X
          //        ____
          // scl __/    \__

          phy_rx_data_next = sda_i_reg;
          delay_next = prescale;
          phy_state_next = PHY_STATE_READ_BIT_3;
        end
        PHY_STATE_READ_BIT_3: begin
          // read bit
          //      ________
          // sda X________X
          //        ____
          // scl __/    \__

          scl_o_next = 1'b0;
          delay_next = prescale;
          phy_state_next = PHY_STATE_READ_BIT_4;
        end
        PHY_STATE_READ_BIT_4: begin
          // read bit
          //      ________
          // sda X________X
          //        ____
          // scl __/    \__

          phy_state_next = PHY_STATE_ACTIVE;
        end
        PHY_STATE_STOP_1: begin
          // stop bit
          //                 ___
          // sda XXX\_______/
          //             _______
          // scl _______/

          scl_o_next = 1'b1;
          delay_scl_next = 1'b1;
          delay_next = prescale;
          phy_state_next = PHY_STATE_STOP_2;
        end
        PHY_STATE_STOP_2: begin
          // stop bit
          //                 ___
          // sda XXX\_______/
          //             _______
          // scl _______/

          sda_o_next = 1'b1;
          delay_next = prescale;
          phy_state_next = PHY_STATE_STOP_3;
        end
        PHY_STATE_STOP_3: begin
          // stop bit
          //                 ___
          // sda XXX\_______/
          //             _______
          // scl _______/

          bus_control_next = 1'b0;
          phy_state_next   = PHY_STATE_IDLE;
        end
        default: begin
          phy_state_next = PHY_STATE_IDLE;
        end
      endcase
    end
  end


  always @(posedge clk or negedge rst_n) begin

    if (~rst_n) begin
      phy_rx_data_reg <= 1'b0;
      phy_state_reg <= PHY_STATE_IDLE;
      delay_reg <= 17'd0;
      delay_scl_reg <= 1'b0;
      delay_sda_reg <= 1'b0;
      scl_o_reg <= 1'b1;
      sda_o_reg <= 1'b1;
      bus_control_reg <= 1'b0;
    end else begin
      phy_state_reg <= phy_state_next;

      phy_rx_data_reg <= phy_rx_data_next;


      delay_reg <= delay_next;
      delay_scl_reg <= delay_scl_next;
      delay_sda_reg <= delay_sda_next;


      scl_i_reg <= scl_i;
      sda_i_reg <= sda_i;

      scl_o_reg <= scl_o_next;
      sda_o_reg <= sda_o_next;

      bus_control_reg <= bus_control_next;
    end
  end



endmodule
