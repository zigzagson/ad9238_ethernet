//////////////////////////////////////////////////////////////////////////////////
//  sd bmp vga display                                                          //
//                                                                              //
//  Author: meisq                                                               //
//          msq@qq.com                                                          //
//          ALINX(shanghai) Technology Co.,Ltd                                  //
//          heijin                                                              //
//     WEB: http://www.alinx.cn/                                                //
//     BBS: http://www.heijin.org/                                              //
//                                                                              //
//////////////////////////////////////////////////////////////////////////////////
//                                                                              //
// Copyright (c) 2017,ALINX(shanghai) Technology Co.,Ltd                        //
//                    All rights reserved                                       //
//                                                                              //
// This source file may be used and distributed without restriction provided    //
// that this copyright statement is not removed from the file and that any      //
// derivative work contains the original copyright notice and the associated    //
// disclaimer.                                                                  //
//                                                                              //
//////////////////////////////////////////////////////////////////////////////////

//================================================================================
//  Revision History:
//  Date          By            Revision    Change Description
//--------------------------------------------------------------------------------
//  2017/6/21    meisq         1.0         Original
//*******************************************************************************/
module top(
	input                       clk,
	input                       rst_n,

	//ad9238
	output                      ad9238_clk_ch0, //ad9238 clock
   input[11:0]                 ad9238_data_ch0,//ad9238 data
	
   /*以太网接口信号*/	 	
   output                      e_mdc,
   inout                       e_mdio,
   output                      e_reset,
   input	                      e_rxc,                     //125Mhz ethernet gmii rx clock
   input                       e_rxdv,                    //GMII 接收数据有效信号
   input                       e_rxer,                    //GMII 接收数据错误信号                    
   input [7:0]                 e_rxd,                     //GMII 接收数据          

   input                       e_txc,                     //25Mhz ethernet mii tx clock         
   output                      e_gtxc,                    //125Mhz ethernet gmii tx clock  
   output                      e_txen,                    //GMII 发送数据有效信号    
   output                      e_txer,                    //GMII 发送数据错误信号                    
   output [7:0]                e_txd,                     //GMII 发送数据 
	
   /*ddr3接口信号*/	 
  	inout  [15:0]               mcb3_dram_dq,
	output [13:0]               mcb3_dram_a,
	output [2:0]                mcb3_dram_ba,
	output                      mcb3_dram_ras_n,
	output                      mcb3_dram_cas_n,
	output                      mcb3_dram_we_n,
	output                      mcb3_dram_odt,
	output                      mcb3_dram_reset_n,
	output                      mcb3_dram_cke,
	output                      mcb3_dram_dm,
	inout                       mcb3_dram_udqs,
	inout                       mcb3_dram_udqs_n,
	inout                       mcb3_rzq,
	inout                       mcb3_zio,
	output                      mcb3_dram_udm,
	inout                       mcb3_dram_dqs,
	inout                       mcb3_dram_dqs_n,
	output                      mcb3_dram_ck,
	output                      mcb3_dram_ck_n
);


parameter MEM_DATA_BITS         = 64  ;                 //external memory user interface data width
parameter ADDR_BITS             = 24  ;                 //external memory user interface address width
parameter BUSRT_BITS            = 10  ;                 //external memory user interface burst width
wire                            wr_burst_data_req;
wire                            wr_burst_finish;
wire                            rd_burst_finish;
wire                            rd_burst_req;
wire                            wr_burst_req;
wire[BUSRT_BITS - 1:0]          rd_burst_len;
wire[BUSRT_BITS - 1:0]          wr_burst_len;
wire[ADDR_BITS - 1:0]           rd_burst_addr;
wire[ADDR_BITS - 1:0]           wr_burst_addr;
wire                            rd_burst_data_valid;
wire[MEM_DATA_BITS - 1 : 0]     rd_burst_data;
wire[MEM_DATA_BITS - 1 : 0]     wr_burst_data;
wire                            read_req;
wire                            read_req_ack;  
wire                            read_en;
wire[15:0]                      read_data;
wire                            write_en;
wire[15:0]                      write_data;
wire [15:0]                     read_usedw ;
wire                            write_req;
wire                            write_req_ack;

wire                            phy_clk;
wire                            init_calib_complete;

wire [ 7:0]                     gmii_txd;
wire                            gmii_tx_en;
wire                            gmii_tx_clk;

wire [ 7:0]                     gmii_rxd;
wire                            gmii_rx_dv;
wire                            gmii_rx_clk;

wire [11:0]                     fifo_data_count;
wire [7:0]                      fifo_data;
wire                            fifo_rd_en;                               

wire                            write_finish ;

wire                            ad_data_req ;
wire                            ad_data_ack ;
wire                            ad_sample_req ;
wire                            ad_sample_ack ;
wire [31:0]                     sample_len  ;

assign ad9238_clk_ch0 = adc_clk;

assign gmii_tx_clk = e_rxc;
assign gmii_rxd = e_rxd;
assign gmii_rx_dv = e_rxdv;
assign gmii_rx_clk = e_rxc;
assign e_gtxc = gmii_tx_clk;
assign e_txen = gmii_tx_en;
assign e_txd = gmii_txd;
assign e_txer = 1'b0;

assign e_reset = 1'b1; 
 //generate adc clock
adc_pll adc_pll_m0
(
  .clk_in1                 (clk_bufg        ),
  .clk_out1                (adc_clk         ),
  .reset                   (1'b0            ),
  .locked                  (                )
);

//MDIO寄存器配置
miim_top miim_top_m0(
  .reset_i                 (1'b0            ),
  .miim_clock_i            (gmii_tx_clk     ),
  .mdc_o                   (e_mdc           ),
  .mdio_io                 (e_mdio          ),
  .link_up_o               (                ),  //link status
  .speed_o                 (                ),  //link speed
  .speed_override_i        (2'b11           )   //11: autonegoation
 ); 

//在这里只选择千兆网络传输AD数据
eth_top eth_top_inst
(

  .rst_n                   (rst_n           ),    
  
  .fifo_data               (read_data       ),          //FIFO读出皿8bit数据/
  .fifo_data_count         (read_usedw      ),          //FIFO中的数据数量
  .fifo_rd_en              (read_en         ),          //FIFO读使胿
  
  .read_req_ack            (read_req_ack    ),
  .read_req                (read_req        ),
  .ad_sample_req           (ad_sample_req   ),
  .ad_sample_ack           (ad_sample_ack   ),
  .sample_len              (sample_len      ),
  .gmii_tx_clk             (gmii_tx_clk     ),
  .gmii_rx_clk             (gmii_rx_clk     ) ,
  .gmii_rx_dv              (gmii_rx_dv      ),
  .gmii_rxd                (gmii_rxd        ),
  .gmii_tx_en              (gmii_tx_en      ),
  .gmii_txd                (gmii_txd        )
  
);


//AD9238 AD sample
ad9238_sample ad9238_sample_m0
 (
   .adc_clk                (adc_clk                    ),
   .rst                    (~rst_n                     ),
   .adc_data               (ad9238_data_ch0            ),
   .adc_buf_wr             (write_en                   ),
   .adc_buf_data           (write_data                 ),
   .sample_len             (sample_len                 ),
   .ad_sample_req          (ad_sample_req              ),
   .ad_sample_ack          (ad_sample_ack              ),
   .write_req              (write_req                  ),
   .write_req_ack          (write_req_ack              )
 );

// frame data read-write control
frame_read_write frame_read_write_m0
(
	.rst                        (~rst_n                   ),
	.mem_clk                    (phy_clk                  ),
	.rd_burst_req               (rd_burst_req             ),
	.rd_burst_len               (rd_burst_len             ),
	.rd_burst_addr              (rd_burst_addr            ),
	.rd_burst_data_valid        (rd_burst_data_valid      ),
	.rd_burst_data              (rd_burst_data            ),
	.rd_burst_finish            (rd_burst_finish          ),
	.read_clk                   (gmii_tx_clk              ),
	.read_req                   (read_req                 ),
	.read_req_ack               (read_req_ack             ),
	.read_finish                (                         ),
	.read_addr_0                (24'd0                    ), //first frame base address is 0
	.read_addr_1                (24'd2073600              ), //The second frame address is 24'd2073600 ,large enough address space for one frame of video
	.read_addr_2                (24'd4147200              ),
	.read_addr_3                (24'd6220800              ),
	.read_addr_index            (2'd0                     ), //use only read_addr_0
	.read_len                   (sample_len               ), //
	.read_en                    (read_en                  ),
	.read_data                  (read_data                ),
   .read_usedw                 (read_usedw               ),
	 
	.wr_burst_req               (wr_burst_req             ),
	.wr_burst_len               (wr_burst_len             ),
	.wr_burst_addr              (wr_burst_addr            ),
	.wr_burst_data_req          (wr_burst_data_req        ),
	.wr_burst_data              (wr_burst_data            ),
	.wr_burst_finish            (wr_burst_finish          ),
	.write_clk                  (adc_clk                  ), //ADC write clock
	.write_req                  (write_req                ),
	.write_req_ack              (write_req_ack            ),
	.write_finish               (                         ),
	.write_addr_0               (24'd0                    ),
	.write_addr_1               (24'd2073600              ),
	.write_addr_2               (24'd4147200              ),
	.write_addr_3               (24'd6220800              ),
	.write_addr_index           (2'd0                     ),
	.write_len                  (sample_len               ), 
	.write_en                   (write_en                 ),
	.write_data                 (write_data               )
);

//实例化mem_ctrl
mem_ctrl		
#(
	.MEM_DATA_BITS(MEM_DATA_BITS),
	.ADDR_BITS(ADDR_BITS)
)
mem_ctrl_inst
(
	//global clock
   .source_clk                      (clk),
	.phy_clk                         (phy_clk), 	            //ddr control clock	
	.clk_bufg  			               (clk_bufg),		         //50Mhz ref clock	
	.rst_n			                  (rst_n),			         //global reset

	//ddr read&write internal interface		
	.wr_burst_req		               (wr_burst_req), 	      //ddr write request
	.wr_burst_addr		               (wr_burst_addr),      	//ddr write address 	
	.wr_burst_data_req               (wr_burst_data_req), 	//ddr write data request
	.wr_burst_data		               (wr_burst_data),     	//fifo 2 ddr data input	
	.wr_burst_finish	               (wr_burst_finish),      //ddr write burst finish	
	
	.rd_burst_req		               (rd_burst_req), 	      //ddr read request
	.rd_burst_addr		               (rd_burst_addr), 	      //ddr read address
	.rd_burst_data_valid             (rd_burst_data_valid),  //ddr read data valid
	.rd_burst_data		               (rd_burst_data),   	   //ddr 2 fifo data input
	.rd_burst_finish	               (rd_burst_finish),      //ddr read burst finish	
	
	.calib_done                      (init_calib_complete), 

	//burst length
	.wr_burst_len		               (wr_burst_len),	            //ddr write burst length
	.rd_burst_len		               (rd_burst_len),		         //ddr read burst length
	
	//ddr interface
	.mcb3_dram_dq                    (mcb3_dram_dq       ),
	.mcb3_dram_a                     (mcb3_dram_a        ),
	.mcb3_dram_ba                    (mcb3_dram_ba       ),
	.mcb3_dram_ras_n                 (mcb3_dram_ras_n    ),
	.mcb3_dram_cas_n                 (mcb3_dram_cas_n    ),
	.mcb3_dram_we_n                  (mcb3_dram_we_n     ),
	.mcb3_dram_odt                   (mcb3_dram_odt      ),
	.mcb3_dram_reset_n               (mcb3_dram_reset_n  ),
	.mcb3_dram_cke                   (mcb3_dram_cke      ),
	.mcb3_dram_dm                    (mcb3_dram_dm       ),
	.mcb3_dram_udqs                  (mcb3_dram_udqs     ),
	.mcb3_dram_udqs_n                (mcb3_dram_udqs_n   ),
	.mcb3_rzq                        (mcb3_rzq           ),
	.mcb3_zio                        (mcb3_zio           ),
	.mcb3_dram_udm                   (mcb3_dram_udm      ),
	.mcb3_dram_dqs                   (mcb3_dram_dqs      ),
	.mcb3_dram_dqs_n                 (mcb3_dram_dqs_n    ),
	.mcb3_dram_ck                    (mcb3_dram_ck       ),
	.mcb3_dram_ck_n                  (mcb3_dram_ck_n     )

);



endmodule
