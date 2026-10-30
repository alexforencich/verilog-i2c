// SPDX-License-Identifier: MIT
// Standalone digital bus tests; no MyHDL or external Python packages required.
`timescale 1ns/1ps
module test_i2c_master_faults;
    parameter STOP_ON_NACK=1;
    reg clk=0,rst=1;
    always #20 clk=~clk; // 25 MHz
    reg[6:0] address=7'h50;
    reg start=0,read_cmd=0,write_cmd=0,multiple=0,stop=0,valid=0;
    wire ready,tx_ready,rx_valid,busy,control,active,missed_ack;
    reg[7:0] tx=8'h5a;reg tx_valid=0,tx_last=0;
    wire[7:0] rx;
    wire scl_release,sda_release;
    reg target_low=0,stretch=0;
    wire scl=scl_release && !stretch;
    wire sda=sda_release && !target_low;
    reg[15:0] prescale=63;
    i2c_master #(.STOP_ON_NACK(STOP_ON_NACK)) dut(.clk(clk),.rst(rst),
        .s_axis_cmd_address(address),.s_axis_cmd_start(start),.s_axis_cmd_read(read_cmd),
        .s_axis_cmd_write(write_cmd),.s_axis_cmd_write_multiple(multiple),.s_axis_cmd_stop(stop),
        .s_axis_cmd_valid(valid),.s_axis_cmd_ready(ready),.s_axis_data_tdata(tx),
        .s_axis_data_tvalid(tx_valid),.s_axis_data_tready(tx_ready),.s_axis_data_tlast(tx_last),
        .m_axis_data_tdata(rx),.m_axis_data_tvalid(rx_valid),.m_axis_data_tready(1'b1),
        .scl_i(scl),.scl_o(scl_release),.sda_i(sda),.sda_o(sda_release),
        .busy(busy),.bus_control(control),.bus_active(active),.missed_ack(missed_ack),
        .prescale(prescale),.stop_on_idle(1'b0));
    integer checks=0,edges=0,starts=0,stops=0,acks=0,rx_bytes=0,tx_bytes=0;
    integer nack_byte=-1;
    reg reading=0,selected=0;
    reg timing=0;
    time start_time=0,rise_time=0,stop_time=0,fall_time=0;
    integer start_min=4000,setup_min=4700,stop_min=4000,bus_free_min=4700;
    task automatic check(input bit ok,input string msg);
        if(!ok)$fatal(1,"%s edges=%0d",msg,edges);checks++;
    endtask
    always @(posedge clk) if(!rst)begin
        if(missed_ack)acks++;
        if(rx_valid)rx_bytes++;
        if(tx_valid && tx_ready)tx_bytes++;
    end
    always @(negedge sda) if(!rst && scl)begin
        if(timing && starts>0 && selected)check($time-rise_time>=setup_min,"repeated START setup minimum");
        if(timing && stop_time>0)check($time-stop_time>=bus_free_min,"bus-free minimum");
        start_time=$time;edges=0;starts++;selected=1;reading=read_cmd;
    end
    always @(posedge sda) if(!rst && scl && selected)begin
        if(timing)check($time-rise_time>=stop_min,"STOP setup minimum");
        stops++;selected=0;stop_time=$time;
    end
    always @(posedge scl) if(!rst)begin
        rise_time=$time;
        if(selected)edges++;
    end
    always @(negedge scl) if(!rst && selected)begin
        if(timing && edges==0)check($time-start_time>=start_min,"START hold minimum");
        fall_time=$time;
        // ACK address and write bytes, except the selected NACK index.
        #1;target_low=(edges%9==8) && (edges/9!=nack_byte) && (!reading || edges<9);
    end
    task automatic reset;
        @(negedge clk);rst=1;valid=0;tx_valid=0;target_low=0;stretch=0;timing=0;selected=0;
        repeat(5)@(negedge clk);
        edges=0;starts=0;stops=0;acks=0;rx_bytes=0;tx_bytes=0;start_time=0;stop_time=0;
        rst=0;repeat(5)@(negedge clk);
    endtask
    task automatic command(input bit r,input bit mul,input bit stp);
        @(negedge clk);read_cmd=r;write_cmd=!r && !mul;multiple=mul;stop=stp;start=1;valid=1;
        begin: wait_cmd
            for(integer n=0;n<50000;n++)begin
                @(posedge clk);if(ready)begin @(negedge clk);valid=0;disable wait_cmd;end
            end
            $fatal(1,"command timeout");
        end
    endtask
    task automatic wait_stop;
        begin: wait_done
            for(integer n=0;n<100000;n++)begin
                @(negedge clk);if(stops>0 && !busy && !control)disable wait_done;
            end
            $fatal(1,"STOP timeout");
        end
    endtask
    initial begin
        if(STOP_ON_NACK)begin
            for(integer r=0;r<2;r++)begin
                reset();nack_byte=0;command(r,0,0);wait_stop();
                check(starts==1 && stops==1 && edges==10,"address NACK stops before payload");
                check(acks==1 && rx_bytes==0 && tx_bytes==0,"address NACK reports once without fabricated data");
            end
            reset();nack_byte=1;command(0,1,0);tx_valid=1;tx_last=0;wait_stop();tx_valid=0;
            check(acks==1 && tx_bytes==1 && edges==19,"data NACK stops non-final streaming write");
        end else begin
            reset();nack_byte=0;command(1,0,1);wait_stop();
            check(rx_bytes==1 && acks==1,"legacy mode retains notification-only behavior");
        end
        // Accepted write, repeated START read, STOP, then immediate new command.
        for(integer fast=0;fast<2;fast++)begin
            reset();nack_byte=-1;prescale=fast?16:63;
            start_min=fast?600:4000;setup_min=fast?600:4700;stop_min=fast?600:4000;bus_free_min=fast?1300:4700;
            timing=1;command(0,0,0);tx_valid=1;tx_last=1;
            begin: sent
                for(integer n=0;n<50000;n++)begin
                    @(negedge clk);if(tx_bytes==1)begin tx_valid=0;disable sent;end
                end
                $fatal(1,"TX timeout");
            end
            command(1,0,1);wait_stop();
            check(starts==2 && rx_bytes==1 && acks==0,"ACKed repeated START transaction");
            command(1,0,1);
            begin: second_stop
                for(integer n=0;n<100000;n++)begin
                    @(negedge clk);if(stops==2 && !busy)disable second_stop;
                end
                $fatal(1,"second STOP timeout");
            end
            check(rx_bytes==2,"new transaction after STOP");
        end
        $display("PASS I2C master faults/timing STOP_ON_NACK=%0d checks=%0d",STOP_ON_NACK,checks);$finish;
    end
    initial begin #100000000;$fatal(1,"global timeout");end
endmodule
