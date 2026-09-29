/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-11-2019 */
 
module jtbtiger_game(
    // Clocks / reset
    input           rst,
    input           clk,
    input           rst24,
    input           clk24,

    // Video
    output          pxl2_cen,
    output          pxl_cen,
    output [3:0]    red,
    output [3:0]    green,
    output [3:0]    blue,
    output          LHBL,
    output          LVBL,
    output          HS,
    output          VS,

    // Cabinet
    input  [3:0]    cab_1p,
    input  [3:0]    coin,
    input  [5:0]    joystick1,
    input  [5:0]    joystick2,

    // DIP / controls
    input  [31:0]   dipsw,
    input           dip_pause,
    input           service,
    output          dip_flip,

    // Video enables
    input  [3:0]    gfx_en,

    // Debug
    input  [7:0]    debug_bus,
    output [7:0]    debug_view,

    // Main ROM
    output [18:0]   main_addr,
    output          main_cs,
    input           main_ok,
    input  [7:0]    main_data,

    // Sound ROM
    output [14:0]   snd_addr,
    output          snd_cs,
    input           snd_ok,
    input  [7:0]    snd_data,

    // Character ROM
    output [14:1]   char_addr,
    input           char_ok,
    input  [15:0]   char_data,

    // Scroll ROM
    output [17:1]   scr_addr,
    input           scr_ok,
    input  [15:0]   scr_data,

    // Object ROM
    output [17:1]   obj_addr,
    input           obj_ok,
    input  [15:0]   obj_data,

    // PROM / MCU programming
    input  [25:0]   ioctl_addr,
    input  [24:0]   prog_addr,
    input  [15:0]   prog_data,
    input           prom_we,

    // Audio channels
    output signed [15:0] fm0,
    output signed [15:0] fm1,
    output signed [15:0] psg0,
    output signed [15:0] psg1,
    
    // MCU 
    output [11:0] mcu_rom_addr,
    output        mcu_rom_cen,
    input  [7:0] mcu_rom_data,
    
    // Priority PROM
    output [7:0] prior_rom_addr,
    output       prior_rom_cen,
    input  [3:0] prior_rom_data
);

`define JTFRAME_PROM_START 26'hD8000

localparam [25:0]   PROM_START = `JTFRAME_PROM_START,
                    MCUOVER    = PROM_START+26'h1000;

wire [12:0] cpu_AB;
wire [10:0] scr_hpos, scr_vpos;
wire [ 8:0] obj_AB, V, H;
wire [ 7:0] mcu_din, mcu_dout, cpu_dout, char_dout, scr_dout, snd_latch, main_ram;

wire [9:0] psg0_raw;
wire [9:0] psg1_raw;

wire [ 4:0] prom;
wire [ 1:0] scr_bank;
wire        mcu_wr, mcu_rd, preLHBL, preLVBL, sres_b,
            cen12, cen6, cen3, cen1p5, cenfm,
            cen8, RnW, blue_cs, redgreen_cs, CHRON, SCRON, OBJON,
            OKOUT, blcnten, bus_req, bus_ack, LHBL_obj, LVBL_obj,
            rd, cpu_cen, char_busy, scr_busy, mcuover,
            scr_layout, HINIT, char_cs, flip, scr_cs;
reg         pause;
//wire        prom_prior_we = prom[0];
//wire        prom_mcu      = prom[4];

assign debug_view  = { 5'd0, OBJON, SCRON, CHRON };
assign dip_flip    = ~dipsw[6];
assign pxl2_cen    = cen12;
assign pxl_cen     = cen6;
assign mcuover     = ioctl_addr>=MCUOVER;
assign prom[0] = prom_we &&  mcuover && ioctl_addr[10:8]==0;
assign prom[1] = prom_we &&  mcuover && ioctl_addr[10:8]==1;
assign prom[2] = prom_we &&  mcuover && ioctl_addr[10:8]==2;
assign prom[3] = prom_we &&  mcuover && ioctl_addr[10:8]==3;
assign prom[4] = prom_we && !mcuover;
/* verilator tracing_off */
always @(posedge clk) pause <= ~dip_pause;

/* verilator lint_off PINMISSING */
jtframe_cen48 u_cen(
    .clk    ( clk       ),
    .cen12  ( cen12     ),
    .cen12b (           ),
    .cen8   ( cen8      ),
    .cen6   ( cen6      ),
    .cen6b  (           ),
    .cen3   ( cen3      ),
    .cen1p5 ( cen1p5    )
);

jtframe_cen3p57 u_cen3p57(
    .clk      ( clk       ),
    .cen_3p57 ( cenfm     ),
    .cen_1p78 (           )     // unused
);/* verilator lint_on PINMISSING */

jtgng_timer u_timer(
    .clk       ( clk      ),
    .cen6      ( cen6     ),
    .V         ( V        ),
    .H         ( H        ),
    .Hinit     ( HINIT    ),
    .LHBL      ( preLHBL  ),
    .LVBL      ( preLVBL  ),
    .LHBL_obj  ( LHBL_obj ),
    .LVBL_obj  ( LVBL_obj ),
    .HS        ( HS       ),
    .VS        ( VS       ),
    .Vinit     (          )
);

jtbtiger_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cpu_cen    ( cpu_cen       ),
    // Timing
    .flip       ( flip          ),
    .V          ( V             ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .H1         ( H[0]          ),
    // Palette
    .blue_cs    ( blue_cs       ),
    .redgreen_cs( redgreen_cs   ),
    // sound
    .sres_b     ( sres_b        ),
    .snd_latch  ( snd_latch     ),
    // security
    .mcu_din    ( mcu_din       ),
    .mcu_dout   ( mcu_dout      ),
    .mcu_wr     ( mcu_wr        ),
    .mcu_rd     ( mcu_rd        ),
    // CHAR
    .char_dout  ( char_dout     ),
    .cpu_dout   ( cpu_dout      ),
    .char_cs    ( char_cs       ),
    .char_busy  ( char_busy     ),
    .CHRON      ( CHRON         ),
    // SCROLL
    .scr_dout   ( scr_dout      ),
    .scr_cs     ( scr_cs        ),
    .scr_busy   ( scr_busy      ),
    .scr_hpos   ( scr_hpos      ),
    .scr_vpos   ( scr_vpos      ),
    .SCRON      ( SCRON         ),
    .scr_bank   ( scr_bank      ),
    .scr_layout ( scr_layout    ),
    // OBJ - bus sharing
    .obj_AB     ( obj_AB        ),
    .cpu_AB     ( cpu_AB        ),
    .ram_dout   ( main_ram      ),
    .OKOUT      ( OKOUT         ),
    .blcnten    ( blcnten       ),
    .bus_req    ( bus_req       ),
    .bus_ack    ( bus_ack       ),
    .OBJON      ( OBJON         ),
    // ROM
    .rom_cs     ( main_cs       ),
    .rom_addr   ( main_addr     ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),
    // Cabinet input
    .cab_1p     ( cab_1p[1:0]   ),
    .coin       ( coin[1:0]     ),
    .service    ( service       ),
    .joystick1  ( joystick1[5:0]),
    .joystick2  ( joystick2[5:0]),

    .RnW        ( RnW           ),
    // DIP switches
    .dip_pause  ( dip_pause     ),
    .dipsw_a    ( dipsw[15:8]   ),
    .dipsw_b    ( dipsw[ 7:0]   )
);

`ifndef NOMCU
jtbtiger_mcu u_mcu(
    .rst        (  rst24      ),
    .clk        (  clk24      ),
    //.clk_rom    (  clk        ),
    .LVBL       ( LVBL        ),
    .mcu_dout   (  mcu_dout   ),
    .mcu_din    (  mcu_din    ),
    .mcu_wr     (  mcu_wr     ),
    .mcu_rd     (  mcu_rd     ),
    //.prog_addr  (  prog_addr[11:0]  ),
    //.prom_din   (  prog_data  ),
    //.prom_we    (  prom_mcu   )
    
    .rom_addr_o ( mcu_rom_addr ),
    .rom_cen_o  ( mcu_rom_cen  ),
    .rom_data_i ( mcu_rom_data )
);
`else
assign mcu_dout = 8'hff;
`endif

jtgng_sound #(.LAYOUT(4)) u_sound (
    .rst            ( rst            ),
    .clk            ( clk            ),
    .cen3           ( cenfm          ),
    .cen1p5         ( cenfm          ),
    // Interface with main CPU
    .sres_b         ( sres_b         ),
    .snd_latch      ( snd_latch      ),
    .snd_int        ( 1'b0           ),
    // ROM
    .rom_addr       ( snd_addr       ),
    .rom_data       ( snd_data       ),
    .rom_cs         ( snd_cs         ),
    .rom_ok         ( snd_ok         ),
    // sound output
    .fm0            ( fm0            ),
    .fm1            ( fm1            ),
    //.psg0           ( psg0           ),
    //.psg1           ( psg1           ),
    .psg0           ( psg0_raw       ),
    .psg1           ( psg1_raw       ),
    // Unused
    .mcu_sdin       ( 8'd0           ),
    .mcu_srd        (                ),
    .snd2_latch     (                ),
    .debug_view     (                ),
    .debug_bus      ( debug_bus      )
);

assign psg0 = { 1'b0, psg0_raw, 5'd0 };
assign psg1 = { 1'b0, psg1_raw, 5'd0 };

jtbtiger_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen12      ( cen12         ),
    .cen8       ( cen8          ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cpu_cen    ( cpu_cen       ),
    .cpu_AB     ( cpu_AB[11:0]  ),
    .V          ( V[7:0]        ),
    .H          ( H             ),
    .RnW        ( RnW           ),
    .flip       ( flip          ),
    .cpu_dout   ( cpu_dout      ),
    .pause      ( pause         ),
    // CHAR
    .char_cs    ( char_cs       ),
    .char_dout  ( char_dout     ),
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .char_busy  ( char_busy     ),
    .char_ok    ( char_ok       ),
    .CHRON      ( CHRON         ),
    // SCROLL - ROM
    .scr_cs     ( scr_cs        ),
    .scr_dout   ( scr_dout      ),
    .scr_addr   ( scr_addr      ),
    .scr_data   ( scr_data      ),
    .scr_busy   ( scr_busy      ),
    .scr_hpos   ( scr_hpos      ),
    .scr_vpos   ( scr_vpos      ),
    .scr_ok     ( scr_ok        ),
    .scr_bank   ( scr_bank      ),
    .scr_layout ( scr_layout    ),
    .SCRON      ( SCRON         ),
    // OBJ
    .HINIT      ( HINIT         ),
    .obj_AB     ( obj_AB        ),
    .main_ram   ( main_ram      ),
    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),
    .obj_ok     ( obj_ok        ),
    .OKOUT      ( OKOUT         ),
    .bus_req    ( bus_req       ), // Request bus
    .bus_ack    ( bus_ack       ), // bus acknowledge
    .blcnten    ( blcnten       ), // bus line counter enable
    .OBJON      ( OBJON         ),
    // PROMs
    //.prog_addr    ( prog_addr[7:0]),
    //.prom_prior_we( prom_prior_we ),
    //.prom_din     ( prog_data[3:0]),
    
    .prior_rom_addr  ( prior_rom_addr ),
    .prior_rom_cen   ( prior_rom_cen  ),
    .prior_rom_data  ( prior_rom_data ),
    
    // Palette RAM
    .blue_cs    ( blue_cs       ),
    .redgreen_cs( redgreen_cs   ),
    // Color Mix
    .preLHBL    ( preLHBL       ),
    .preLVBL    ( preLVBL       ),
    .LHBL_obj   ( LHBL_obj      ),
    .LVBL_obj   ( LVBL_obj      ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .gfx_en     ( gfx_en        ),
    // Pixel Output
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

endmodule
