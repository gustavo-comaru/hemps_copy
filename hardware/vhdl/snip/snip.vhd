library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use work.standards.all;
use work.seek_pkg.all;
use work.snip_pkg.all;

-----------------------------------------------
-- Secure Network Interface with Peripherals --
-----------------------------------------------

entity snip is
    generic
    (
        SNIP_ID : regflit
    );
    port
    (
        clock   : in    std_logic;
        reset   : in    std_logic;

        ----------------------
        -- Hermes Interface --
        ----------------------

        hermes_primary_tx           : out   std_logic;
        hermes_primary_tx_clk       : out   std_logic;
        hermes_primary_data_out     : out   regflit;
        hermes_primary_eop_out      : out   std_logic;
        hermes_primary_credit_in    : in    std_logic;

        hermes_primary_rx           : in    std_logic;
        hermes_primary_rx_clk       : in    std_logic;
        hermes_primary_data_in      : in    regflit;
        hermes_primary_eop_in       : in    std_logic;
        hermes_primary_credit_out   : out   std_logic;

        ---------------------
        -- BrNoC Interface --
        ---------------------

        brnoc_primary_source_in     : in    regNsource;
        brnoc_primary_target_in     : in    regNtarget;
        brnoc_primary_service_in    : in    seek_bitN_service;
        brnoc_primary_payload_in    : in    regNpayload;
        brnoc_primary_req_in        : in    std_logic;
        brnoc_primary_opmode_in     : in    std_logic;
        brnoc_primary_ack_out       : out   std_logic;
        
        brnoc_primary_source_out    : out   regNsource;
        brnoc_primary_target_out    : out   regNtarget;
        brnoc_primary_service_out   : out   seek_bitN_service;
        brnoc_primary_payload_out   : out   regNpayload;
        brnoc_primary_req_out       : out   std_logic;
        brnoc_primary_opmode_out    : out   std_logic;
        brnoc_primary_ack_in        : in    std_logic
    );
end entity;

architecture snip of snip is

    ----------------------------
    -- Port Selection Signasl --
    ----------------------------
    
    signal hermes_rx                : std_logic;
    signal hermes_rx_ck             : std_logic;
    signal hermes_data_in           : regflit;
    signal hermes_eop_in            : std_logic;
    signal hermes_credit_out        : std_logic;

    signal hermes_tx                : std_logic;
    signal hermes_tx_ck             : std_logic;
    signal hermes_data_out          : regflit;
    signal hermes_eop_out           : std_logic;
    signal hermes_credit_in         : std_logic;

    -------------------------------
    -- Application Table Signals --
    -------------------------------

    signal tableIn_handlerOut   : AppTablePrimaryInput;
    signal tableOut_handlerIn   : AppTablePrimaryOutput;

    signal tableIn_builderOut   : AppTableSecondaryInput;
    signal tableOut_builderIn   : AppTableSecondaryOutput;

    --------------------------------
    -- Response Request Interface --
    --------------------------------

    signal response_req     : std_logic;
    signal response_param   : ResponseParametersType;
    signal tx_status        : TransmissionStatusType;

    --------------------
    -- Buffer Signals --
    --------------------

    -- buffer out

    signal buffer_o_wen     : std_logic;
    signal buffer_o_datain  : regflit;

    signal buffer_o_ren     : std_logic;
    signal buffer_o_dataout : regflit;

    signal buffer_o_status  : BufferStatusType;

    -- buffer in

    signal buffer_i_wen     : std_logic;
    signal buffer_i_datain  : regflit;

    signal buffer_i_ren     : std_logic;
    signal buffer_i_dataout : regflit;

    signal buffer_i_status  : BufferStatusType;

begin

    -- Resetando as saídas inutilizadas até o momento para reduzir os warnings
    process (reset)
    begin
        if reset = '1' then
            brnoc_primary_source_out    <= (others => '0');
            brnoc_primary_target_out    <= (others => '0');
            brnoc_primary_service_out   <= (others => '0');
            brnoc_primary_payload_out   <= (others => '0');
            brnoc_primary_req_out       <= '0';
            brnoc_primary_opmode_out    <= '0';
            brnoc_primary_ack_out       <= '1';
        end if;
    end process;

    --------------------
    -- Port Selection --
    --------------------

    hermes_rx                   <= hermes_primary_rx;
    hermes_rx_ck                <= hermes_primary_rx_clk;
    hermes_data_in              <= hermes_primary_data_in;
    hermes_eop_in               <= hermes_primary_eop_in;
    hermes_primary_credit_out   <= hermes_credit_out;

    hermes_primary_tx           <= hermes_tx;
    hermes_primary_tx_clk       <= '1';
    hermes_primary_data_out     <= hermes_data_out;
    hermes_primary_eop_out      <= hermes_eop_out;
    hermes_credit_in            <= hermes_primary_credit_in;

    -------------------------------------
    -- Application Table Instantiation --
    -------------------------------------

    ApplicationTable: entity work.snip_application_table
    port map
    (
        clock           => clock,
        reset           => reset,

        primaryIn       => tableIn_handlerOut,
        primaryOut      => tableOut_handlerIn,

        secondaryIn     => tableIn_builderOut,
        secondaryOut    => tableOut_builderIn
    );

    ----------------------------------
    -- Packet Handler Instantiation --
    ----------------------------------

    PacketHandler: entity work.snip_packet_handler
    port map
    (
        clock               => clock,
        reset               => reset,

        hermes_rx           => hermes_rx,
        hermes_data_in      => hermes_data_in,
        hermes_eop_in       => hermes_eop_in,
        hermes_credit_out   => hermes_credit_out,

        tableIn             => tableOut_handlerIn,
        tableOut            => tableIn_handlerOut,

        response_req        => response_req,
        response_param      => response_param,
        tx_status           => tx_status,

        buffer_wdata        => buffer_o_datain,
        buffer_wen          => buffer_o_wen,
        buffer_full         => buffer_o_status.full
    );

    ----------------------------------
    -- Packet Builder Instantiation --
    ----------------------------------

    PacketBuilder: entity work.snip_packet_builder
    generic map
    (
        SNIP_ID             => SNIP_ID
    )
    port map
    (
        clock               => clock,
        reset               => reset,

        hermes_tx           => hermes_tx,
        hermes_data_out     => hermes_data_out,
        hermes_eop_out      => hermes_eop_out,
        hermes_credit_in    => hermes_credit_in,

        tableIn             => tableOut_builderIn,
        tableOut            => tableIn_builderOut,

        response_req        => response_req,
        response_param_in   => response_param,
        status              => tx_status,

        buffer_rdata        => buffer_i_dataout,
        buffer_ren          => buffer_i_ren,
        buffer_empty        => buffer_i_status.empty
    );

    ------------------------------
    -- IO Buffers Instantiation --
    ------------------------------

    OutputBuffer: entity work.snip_io_buffer
    port map
    (
        clock   => clock,
        reset   => reset,

        w_en    => buffer_o_wen,
        data_i  => buffer_o_datain,

        r_en    => buffer_o_ren,
        data_o  => buffer_o_dataout,

        status  => buffer_o_status
    );

    InputBuffer: entity work.snip_io_buffer
    port map
    (
        clock   => clock,
        reset   => reset,

        w_en    => buffer_i_wen,
        data_i  => buffer_i_datain,

        r_en    => buffer_i_ren,
        data_o  => buffer_i_dataout,

        status  => buffer_i_status
    );

    --------------------------------------------------
    -- Peripheral Instantiation -- Testing Purposes --
    --------------------------------------------------

    DummyPeripheral: entity work.dummy_peripheral
    port map
    (
        clock               =>  clock,
        reset               =>  reset,

        r_en                => buffer_o_ren,
        w_en                => buffer_i_wen,

        data_in             => buffer_o_dataout,
        data_out            => buffer_i_datain,

        space_unavailable   => buffer_i_status.full,
        data_unavailable    => buffer_o_status.empty
    );

end architecture;
