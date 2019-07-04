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

    
