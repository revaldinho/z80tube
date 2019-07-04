/*
 * This code is part of the z80tube project for interfacing RaspberryPI or Acorn Second Processors
 * to an Amstrad CPC computer
 * 
 * https://github.com/revaldinho/z80tube
 * 
 * Copyright (C) 2018 Revaldinho
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */



/*
 * This is work in progress to explore a simpler latch based interface between Pi and CPC
 * for parallel data transfers.
 * 
 * Code is written so that it might be broken down into 74 series components later.
 * 
 * Following modules are implemented
 * 
 * - cpld_fifo = top level for use with the z80tube board
 * - glue      = possibly for implementation in a small XC9536-PC44 or in 74 series logic
 * - lvc374    = replace with a real 74lvc374 in a discrete implementation
 * - nand8     = replace with a real 74HCT30 in a discrete implementation
 * 
 * Work in progress
 * 
 * 1 debugging this code standalone (now)
 * 2 integrating this code with the z80tube to have both available in the 
 *   same CPLD firmware and switchable by the CPC host
 * 3 possible re-implementation in (cheap) 74 series components or mixed
 *   74 series + cheaper smaller CPLD
 * 
 * 
 * FIFO scheme is changed to be more similar to the cpc-cplink scheme using 74HC40105 FIFOs.
 * 
 * Changes are on the slave side mainly.
 * 
 * slave_dir and slave_dor are permanently driven and signal buffers are either ready for input
 * data or output data respectively.
 * 
 * Idle states
 * - slave_wr = low
 * - slave_rd_b = high
 * 
 * 
 * to write a byte from the slave
 * 
 * 1. check that slave_dir is high
 * 2. drive byte onto data lines
 * 3. drive slave_wr high
 * 4. waive for slave_dir to go low
 * 5. drive slave_wr low
 * 
 * to read a byte from the slave
 * 
 * 1. check that slave_dor is high
 * 2. drive slave_rd_b low
 * 3. read data from data lines
 * 4. wait until slave_dor is low
 * 5. drive slave_rd_b high
 * 
 * See the UCF file for definitive Pi pin assignments
 * 
 * grep slave cpld_fifo.ucf 
 * 
 * PIN "slave_data[0]"	LOC = PIN13; # PI_GPIO_08
 * PIN "slave_data[3]"	LOC = PIN14; # PI_GPIO_11
 * PIN "slave_data[7]"	LOC = PIN15; # PI_GPIO_25
 * PIN "slave_data[1]"	LOC = PIN17; # PI_GPIO_09
 * PIN "slave_data[2]"	LOC = PIN18; # PI_GPIO_10
 * PIN "slave_data[6]"	LOC = PIN19; # PI_GPIO_24
 * PIN "slave_data[5]"	LOC = PIN20; # PI_GPIO_23
 * PIN "slave_data[4]"	LOC = PIN21; # PI_GPIO_22
 * PIN "slave_dor"	LOC = PIN23; # PI_GPIO_27 (PI_GPIO_21 on early models)
 * PIN "slave_dir"	LOC = PIN24; # PI_GPIO_18
 * PIN "slave_rd_b"	LOC = PIN25; # PI_GPIO_17
 * PIN "slave_wr"	LOC = PIN26; # PI_GPIO_15 (not connected on PiTubeDirect)
 * PIN "slave_unused"	LOC = PIN33; # PI_GPIO_03 (PI_GPIO_1 on early models)
 * 
 * As on the original z80tube assignments all pi facing connections are on the 
 * first 26 pins to be compatible with the original Pi (model1) and the IO board
 * for the Pi 2 inside the Fuze-T2 keyboard.
 * 
 */

module lvc374(
              input clk,
              input oeb,
              input [7:0] d,
              output [7:0] q
              );

  reg[7:0]  q_q;
  
  always @ (posedge clk)
    q_q <= d;

  assign q = (!oeb) ? q_q : 8'bz;

endmodule

// Define a NAND8 to make it easier to map logic to a 7430 later
module nand8(
             input [7:0] i,
             output o
             );
  assign o = !( &i);
endmodule


module glue(
            input [15:0] adr,
            input	ioreq_b,
            input	clk,
            input	reset_b,
            input	wr_b,
            input	rd_b,
            input	slave_rd_b,
            input	slave_wr,

            output	host_slave_wclk,
            output	slave_host_oeb,
            
            output	slave_dor,
            inout	host_dor,
            output	slave_dir,
            inout	host_dir
            );

  reg	slave_wr_q;
  reg	slave_rd_qb;
  reg	host_wr_qb;
  reg	host_rd_qb;
  reg	host_dor_q;
  reg	slave_dor_q;
  reg	host_slave_wclk_en_lat_qb;
  

  // Hardwire FD80, FD81 for data, status registers (actually FD_1xxx_xxxR where R=0/1 for data/status)

  wire fd1_decode_b;
  
  wire host_sel_data_b = ( fd1_decode_b | adr[9] |  adr[0] | ioreq_b) ;
  wire host_sel_stat_b = ( fd1_decode_b | adr[9] | !adr[0] | ioreq_b) ;

  always @ ( clk )
    if ( !clk )
      host_slave_wclk_en_lat_qb <= host_sel_data_b | wr_b;
  
  assign host_slave_wclk = !host_slave_wclk_en_lat_qb & clk;
  
  assign slave_host_oeb =  host_sel_data_b | rd_b;

  // ensure that the 'ready' flags are false when the other side is in the middle performing a multi-cycle transaction
  
  assign {host_dir, host_dor} = ( host_sel_stat_b | rd_b ) ? 2'bz: { !slave_dor_q & slave_rd_qb, host_dor_q & !slave_wr_q};  
  assign {slave_dir, slave_dor} = { !host_dor_q & host_rd_qb , slave_dor_q & host_wr_qb};

  nand8 nand8_u(
                .i({adr[15:10], adr[8], adr[7]} ),
                .o(fd1_decode_b)
                );
  
  always @ ( posedge clk or negedge reset_b )
    if (!reset_b) 
      { slave_wr_q, slave_rd_qb, host_wr_qb, host_rd_qb, host_dor_q, slave_dor_q} <= 6'b011100;
    else begin 
      slave_wr_q  <= slave_wr;
      slave_rd_qb  <= slave_rd_b;    
      host_wr_qb   <= host_sel_data_b | wr_b;
      host_rd_qb <= host_sel_data_b  | rd_b;
      slave_dor_q <= !host_wr_qb | (slave_rd_qb & slave_dor_q);
      host_dor_q  <= slave_wr_q  | (host_rd_qb & host_dor_q);      
    end
  
  
endmodule

module cpld_fifo(
                 input [15:0] adr,
                 input	ioreq_b,
                 input	clk,
                 input	reset_b,
                 input	wr_b,
                 input	rd_b,
                 input	slave_rd_b,
                 input	slave_wr,
                 input  slave_unused,
                 
                 inout [7:0]	host_data,
                 inout [7:0]	slave_data,
                 output	slave_dor,
                 output	slave_dir
                 );


  wire host_slave_wclk, slave_host_oeb;
  
  glue glue_u(
            .adr(adr),
            .ioreq_b(ioreq_b),
            .clk(clk),
            .reset_b(reset_b),
            .wr_b(wr_b),
            .rd_b(rd_b),
            .slave_rd_b(slave_rd_b),
            .slave_wr(slave_wr),
            .host_slave_wclk(host_slave_wclk),
            .slave_host_oeb(slave_host_oeb),
            .slave_dor(slave_dor),
            .host_dor(host_data[1]),
            .slave_dir(slave_dir),
            .host_dir(host_data[0])
              
       );

  lvc374 slave_host_u(
                      .clk(slave_wr),
                      .oeb(slave_host_oeb),
                      .d(slave_data),
                      .q(host_data)
         );

  lvc374 host_slave_u(
                      .clk(host_slave_wclk),
                      .oeb(slave_rd),
                      .d(host_data),
                      .q(slave_data)                      
         );
    
  
endmodule

    
