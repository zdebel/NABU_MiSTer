//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;

assign AUDIO_S = 0;
assign AUDIO_L = 0;
assign AUDIO_R = 0;
assign AUDIO_MIX = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

wire [1:0] ar = status[122:121];

assign VIDEO_ARX = (!ar) ? 12'd4 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 12'd3 : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
	"NABU;;",
	"-;",
	"O[122:121],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"O[2],TV Mode,NTSC,PAL;",
	"O[4:3],Noise,White,Red,Green,Blue;",
	"-;",
	"P1,Test Page 1;",
	"P1-;",
	"P1-, -= Options in page 1 =-;",
	"P1-;",
	"P1O[5],Option 1-1,Off,On;",
	"d0P1F1,BIN;",
	"H0P1O[10],Option 1-2,Off,On;",
	"-;",
	"P2,Test Page 2;",
	"P2-;",
	"P2-, -= Options in page 2 =-;",
	"P2-;",
	"P2S0,DSK;",
	"P2O[7:6],Option 2,1,2,3,4;",
	"-;",
	"-;",
	"T[0],Reset;",
	"R[0],Reset and close OSD;",
	"V,v",`BUILD_DATE 
};

wire forced_scandoubler;
wire   [1:0] buttons;
wire [127:0] status;
wire  [10:0] ps2_key;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
	.gamma_bus(),

	.forced_scandoubler(forced_scandoubler),

	.buttons(buttons),
	.status(status),
	.status_menumask({status[5]}),
	
	.ps2_key(ps2_key)
);

///////////////////////   CLOCKS   ///////////////////////////////

wire clk_sys;
pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys)
);

wire reset = RESET | status[0] | buttons[1];

wire [1:0] col = status[4:3];

wire HBlank;
wire HSync;
wire VBlank;
wire VSync;
wire ce_pix;
wire [7:0] video;

/*
	TODO: ...everything!
*/
reg [4:0] ce_cnt = 0;
//cpu clock enable
reg z80_ce = 0;
//psg clock enable
reg ay8910_ce = 0;
//vdp clock enable
reg tms9918_ce = 0;

/* CLOCK AND CLOCK ENABLE GENERATION */
//clk_sys is set to 42.95454 MHz
//modulo twice the divider, because we're generating edges here
always @(posedge clk_sys) begin
	ce_cnt <= ce_cnt + 1;
	if (ce_cnt == 23) begin
		 ce_cnt <= 0;
	end
	//42.95454 / 24 = 1.7897725 MHz
	if ((ce_cnt % 12) == 0) begin
		 ay8910_ce = !ay8910_ce;
	end
	//42.95454 / 12 = 3.579545 MHz
	// /6 because we're using only cen_p in T80pa so we need 7.15909 MHz
	if ((ce_cnt % 3) == 0) begin
		 z80_ce = !z80_ce;
	end
	//42.95454 / 2 = 21.47727 MHz
	tms9918_ce = !tms9918_ce;
end


wire        io_wr = ~nIORQ & ~nWR & nM1;
wire        io_rd = ~nIORQ & ~nRD & nM1;
wire        m1    = ~nM1 & ~nMREQ;

/* Z80 */
wire [15:0] addr;
wire  [7:0] cpu_dout;
wire        nM1;
wire        nMREQ;
wire        nIORQ;
wire        nRD;
wire        nWR;
wire        nRFSH;
wire        nBUSACK;
wire        nINT;
wire	[7:0] cpu_din = 
	!nMREQ ? ((!ctrl_reg[0] & (addr < rom_size)) ? rom_dout : ram_dout) :
	!io_rd ? 8'hff :
	(addr == 8'hA0) ? vdp_out :
	8'hff
;

always @(posedge clk_sys) begin
	if (!nIORQ & nM1 & !nWR & (addr == 0)) begin
		ctrl_reg <= cpu_dout;
	end
end

T80pa cpu
(
	.RESET_n(~reset),
	.CLK(clk_sys),
	.CEN_p(z80_ce),
	.CEN_n(1),
	
	.WAIT_n(1),
	
	.INT_n(nINT),
	.NMI_n(1),
	.BUSRQ_n(1),
	
	.M1_n(nM1),
	.MREQ_n(nMREQ),
	.IORQ_n(nIORQ),
	
	.RD_n(nRD),
	.WR_n(nWR),
	
	.RFSH_n(nRFSH),
	.HALT_n(1),
	
	.BUSAK_n(nBUSACK),
	.A(addr),
	.DO(cpu_dout),
	.DI(cpu_din)
);

wire [7:0] vdp_out;
wire vdp_cs;
wire vdp_int;
VDP vdp_inst(
	.CLK21M(tms9918_ce),
   .RESET(reset),
   .REQ(vdp_cs),
	.ACK(),
	.WRT(!nWR),
	.ADR(addr),
	.DBI(vdp_out),
	.DBO(cpu_dout),

	.INT_N(vdp_int),

	.PRAMOE_N(),
	.PRAMWE_N(vram_we_n),
	.PRAMADR(vram_addr),
	.PRAMDBI({vram_dout, vram_dout}),
	.PRAMDBO(vram_din),
	
	.VDPSPEEDMODE(0),
	.RATIOMODE(3'b000),
	.CENTERYJK_R25_N(),

	.PVIDEOR(),             //: OUT   STD_LOGIC_VECTOR(  5 DOWNTO 0 );
	.PVIDEOG(),             //: OUT   STD_LOGIC_VECTOR(  5 DOWNTO 0 );
	.PVIDEOB(),             //: OUT   STD_LOGIC_VECTOR(  5 DOWNTO 0 );
	.PVIDEODE(VGA_DE),

	.PVIDEOHS_N(VGA_HS),
	.PVIDEOVS_N(VGA_VS),
	.PVIDEOCS_N(),

	.PVIDEODHCLK(),
	.PVIDEODLCLK(),

	.DISPRESO(0),
	.NTSC_PAL_TYPE(0),
	.FORCED_V_MODE(0),
	.LEGACY_VGA(0),

	.DEBUG_OUTPUT()
  );

wire [7:0] ram_dout;
cpu_ram ram_inst(
	.address(addr),
	.data(cpu_dout),
	.clock(clk_sys),
	.wren(!nWR),
	.q(ram_dout)
);

/* NABU control reg - U6 */
reg [7:0] ctrl_reg;

wire [7:0] rom_dout;
reg [15:0] rom_size = 4096;
bios bios_inst (
	.address(addr),
	.clock(clk_sys),
	.q(rom_dout)
);

wire [13:0] vram_addr;
wire vram_we_n;
wire [7:0] vram_din;
wire [7:0] vram_dout;
vram vram_inst (
	.address(vram_addr),
	.clock(clk_sys),
	.data(vram_din),
	.wren(!vram_we_n),
	.q(vram_dout)
);

assign CLK_VIDEO = clk_sys;
assign CE_PIXEL = z80_ce;

//assign VGA_DE = ~(HBlank | VBlank);
//assign VGA_HS = HSync;
//assign VGA_VS = VSync;
assign VGA_G  = ctrl_reg[3] ? 8'hff : 8'h00;
assign VGA_R  = ctrl_reg[4] ? 8'hff : 8'h00;
assign VGA_B  = ctrl_reg[5] ? 8'hff : 8'h00;

reg  [26:0] act_cnt;
always @(posedge clk_sys) act_cnt <= act_cnt + 1'd1; 
assign LED_USER    = act_cnt[26]  ? act_cnt[25:18]  > act_cnt[7:0]  : act_cnt[25:18]  <= act_cnt[7:0];

endmodule
