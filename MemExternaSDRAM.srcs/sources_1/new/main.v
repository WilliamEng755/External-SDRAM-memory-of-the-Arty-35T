

`default_nettype none

`ifdef SYNTHESIS
`define LAST_ADDRESS     25'h1ffffff
`else
`define LAST_ADDRESS     25'h1ffff
`endif

// Constantes para o controlador DDR3 (endereços, comandos, largura de dados, máscaras)
`define DDR3_DQ__WIDTH   16
`define DDR3_DQS_WIDTH   2
`define DDR3_ADR_WIDTH   14
`define DDR3_BA__WIDTH   3
`define DDR3_DM__WIDTH   2
`define APP_ADDR_WIDTH   28
`define APP_CMD__WIDTH   3
`define APP_DATA_WIDTH   128
`define APP_MASK_WIDTH   16
`define CMD_READ         3'b001
`define CMD_WRITE        3'b000

module m_main (
    input  wire w_clk,
    output wire [3:0] w_led,
    //sinais físicos que ligam a memória DDR3, essas portas são conectadas ao IP MIG, conectam o FPGA DDR3
    inout  wire [`DDR3_DQ__WIDTH-1 : 0]  ddr3_dq,
    inout  wire [`DDR3_DQS_WIDTH-1 : 0]  ddr3_dqs_n,
    inout  wire [`DDR3_DQS_WIDTH-1 : 0]  ddr3_dqs_p,
    output wire [`DDR3_ADR_WIDTH-1 : 0]  ddr3_addr,
    output wire [`DDR3_BA__WIDTH-1 : 0]  ddr3_ba,
    output wire                          ddr3_ras_n,
    output wire                          ddr3_cas_n,
    output wire                          ddr3_we_n,
    output wire                          ddr3_reset_n,
    output wire [0:0]                    ddr3_ck_p,
    output wire [0:0]                    ddr3_ck_n,
    output wire [0:0]                    ddr3_cke,
    output wire [0:0]                    ddr3_cs_n,
    output wire [`DDR3_DM__WIDTH-1 : 0]  ddr3_dm,
    output wire [0:0]                    ddr3_odt
);

    wire sys_clk;
    wire ref_clk;
    wire sys_rst = 0;
    // gerenciador de sinais de clock
    clk_wiz_0 m0 (sys_clk, ref_clk, w_clk);

    reg  [`APP_ADDR_WIDTH-1 : 0] r_app_addr = 0;
    reg  [`APP_CMD__WIDTH-1 : 0] r_app_cmd  = 0;
    reg                          r_app_en = 0;
    reg                          r_app_wdf_wren = 0;
    reg  [`APP_DATA_WIDTH-1 : 0] r_app_wdf_data = 128'hCAFEBABE_CAFEBABE_CAFEBABE_CAFEBABE;
    reg  [`APP_MASK_WIDTH-1 : 0] r_app_wdf_mask = 0;

    wire [`APP_DATA_WIDTH-1 : 0] app_rd_data;
    wire                         app_rd_data_valid;
    wire                         app_rdy;
    wire                         app_wdf_rdy;

    wire                         w_ui_clk;
    wire                         init_calib_complete;

    reg [3:0] r_state = 0;
    reg [127:0] r_expected = 128'hCAFEBABE_CAFEBABE_CAFEBABE_CAFEBABE;
    reg [127:0] r_read_data = 0;
    reg r_error = 0;
    reg r_success = 0;

    localparam S_IDLE     = 0;
    localparam S_WRITE    = 1;
    localparam S_WAIT     = 2;
    localparam S_READ     = 3;
    localparam S_COMPARE  = 4;
    localparam S_DONE     = 5;

    always @(posedge w_ui_clk) if (init_calib_complete) begin
        case (r_state)
            S_IDLE: begin
                r_app_addr <= 28'h0000000;
                r_app_cmd  <= `CMD_WRITE;
                r_app_en   <= 1;
                r_app_wdf_wren <= 1;
                r_app_wdf_data <= r_app_wdf_data;
                r_app_wdf_mask <= 0;
                r_state <= S_WAIT;
            end

            S_WAIT: begin
                if (app_rdy && app_wdf_rdy) begin
                    r_app_en <= 0;
                    r_app_wdf_wren <= 0;
                    r_state <= S_READ;
                end
            end

            S_READ: begin
                r_app_cmd <= `CMD_READ;
                r_app_en  <= 1;
                r_state <= S_COMPARE;
            end

            S_COMPARE: begin
                if (app_rdy) r_app_en <= 0;
                if (app_rd_data_valid) begin
                    r_read_data <= app_rd_data;
                    if (app_rd_data == r_expected)
                        r_success <= 1;
                    else
                        r_error <= 1;
                    r_state <= S_DONE;
                end
            end

            S_DONE: begin
                // Teste concluído
            end
        endcase
    end

    assign w_led = {init_calib_complete, r_error, r_success, r_state == S_DONE};

    vio_0 vio0 (w_ui_clk, r_app_addr, r_read_data[31:0]);

    mig_7series_0 mig (
        .ddr3_addr           (ddr3_addr),
        .ddr3_ba             (ddr3_ba),
        .ddr3_cas_n          (ddr3_cas_n),
        .ddr3_ck_n           (ddr3_ck_n),
        .ddr3_ck_p           (ddr3_ck_p),
        .ddr3_cke            (ddr3_cke),
        .ddr3_ras_n          (ddr3_ras_n),
        .ddr3_we_n           (ddr3_we_n),
        .ddr3_dq             (ddr3_dq),
        .ddr3_dqs_n          (ddr3_dqs_n),
        .ddr3_dqs_p          (ddr3_dqs_p),
        .ddr3_reset_n        (ddr3_reset_n),
        .ddr3_cs_n           (ddr3_cs_n),
        .ddr3_dm             (ddr3_dm),
        .ddr3_odt            (ddr3_odt),
        .app_addr            (r_app_addr),
        .app_cmd             (r_app_cmd),
        .app_en              (r_app_en),
        .app_wdf_data        (r_app_wdf_data),
        .app_wdf_end         (r_app_wdf_wren),
        .app_wdf_wren        (r_app_wdf_wren),
        .app_wdf_mask        (r_app_wdf_mask),
        .app_rd_data         (app_rd_data),
        .app_rd_data_valid   (app_rd_data_valid),
        .app_rd_data_end     (),
        .app_rdy             (app_rdy),
        .app_wdf_rdy         (app_wdf_rdy),
        .app_sr_req          (1'b0),
        .app_ref_req         (1'b0),
        .app_zq_req          (1'b0),
        .app_sr_active       (),
        .app_ref_ack         (),
        .app_zq_ack          (),
        .ui_clk              (w_ui_clk),
        .ui_clk_sync_rst     (),
        .init_calib_complete (init_calib_complete),
        .device_temp         (),
        .sys_clk_i           (sys_clk),
        .clk_ref_i           (ref_clk),
        .sys_rst             (sys_rst)
    );
endmodule
