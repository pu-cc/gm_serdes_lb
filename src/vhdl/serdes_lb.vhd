library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity serdes_lb is
    port (
        pll_rstn_i               : in std_logic;
        trx_rstn_i               : in std_logic;

        RX_DATA_O                : out std_logic_vector(63 downto 0);
        CLK_CORE_PLL_O           : out std_logic;
        CLK_CORE_RX_O            : out std_logic;

        RX_RESET_DONE_O_N        : out std_logic;
        TX_RESET_DONE_O_N        : out std_logic;

        TX_DETECT_RX_PRESENT_O_N : out std_logic;
        TX_DETECT_RX_DONE_O_N    : out std_logic;

        TX_BUF_ERR_O_N           : out std_logic;
        RX_BUF_ERR_O_N           : out std_logic
    );
end entity;

architecture rtl of serdes_lb is

    constant ENABLE_8B10B : std_logic := '1';
    constant ENABLE_COMMADETECT : std_logic := '1';

    constant PRBS_SEL : std_logic_vector(2 downto 0) :=
      "000"; -- PRBS checker disabled
    --"001"; -- PRBS-7
    --"010"; -- PRBS-15
    --"011"; -- PRBS-23
    --"100"; -- PRBS-31
    --"101"; -- RESERVED
    --"110"; -- 2 UI square wave (TX ONLY)
    --"111"; -- 20/40/80 UI square wave, depending on data path width (TX ONLY)

    constant LOOPBACK_SEL : std_logic_vector(2 downto 0) :=
      "000"; -- normal operation
    --"001"; -- near-end PCS Loopback
    --"010"; -- near-end PMA Loopback
    --"011"; -- reserved
    --"100"; -- far-end PMA Loopback
    --"101"; -- reserved
    --"110"; -- far-end PCS Loopback
    --"111"; -- reserved

    constant TX_PMA_LOOPBACK : bit_vector(1 downto 0) :=
      "01"; -- loopback from TX driver
    --"00"; -- disabled
    --"10"; -- loopback from TX pads

    constant DATAPATH_SEL : bit_vector(1 downto 0) :=
      "11"; --when (DATAPATH = 80 or DATAPATH = 64)
    --"01"; --when (DATAPATH = 40 or DATAPATH = 32)
    --"00"; --when (DATAPATH = 20 or DATAPATH = 16)
    --"XX"; --else

    constant PLL_FCNTRL : bit_vector(5 downto 0) :=
      "111010"; --when DATAPATH = 80
    --"110110"; --when DATAPATH = 64
    --"111010"; --when DATAPATH = 40
    --"110110"; --when DATAPATH = 32
    --"011010"; --when DATAPATH = 20
    --"010111"; --when DATAPATH = 16
    --"XXXXXX"; --else

    constant PLL_MAIN_DIVSEL : bit_vector(5 downto 0) :=
      "0"  & --PLL_MAINDIV[5]: not used
      "00" & --when N3=3
    --"10" & --when N3=4
    --"11" & --when N3=5
      "0"  & --when N1=1
    --"1"  & --when N1=2
    --"00";  --when N2=3
      "01";  --when N2=2
    --"10";  --when N2=4
    --"11";  --when N2=5

    constant PLL_OUT_DIVSEL : bit_vector(1 downto 0) :=
    --"00"; --when OUTDIV=1
    --"01"; --when OUTDIV=2
    "11"; --when OUTDIV=4

    -- CC_SERDES instance generator
    -- generated: 2025-01-23 18:43:22

    component CC_SERDES is
    generic (
        RX_BUF_RESET_TIME : bit_vector(4 downto 0);
        RX_PCS_RESET_TIME : bit_vector(4 downto 0);
        RX_RESET_TIMER_PRESC : bit_vector(4 downto 0);
        RX_RESET_DONE_GATE : bit_vector(0 downto 0);
        RX_CDR_RESET_TIME : bit_vector(4 downto 0);
        RX_EQA_RESET_TIME : bit_vector(4 downto 0);
        RX_PMA_RESET_TIME : bit_vector(4 downto 0);
        RX_WAIT_CDR_LOCK : bit_vector(0 downto 0);
        RX_CALIB_EN : bit_vector(0 downto 0);
        RX_CALIB_OVR : bit_vector(0 downto 0);
        RX_CALIB_VAL : bit_vector(3 downto 0);
        RX_RTERM_VCMSEL : bit_vector(2 downto 0);
        RX_RTERM_PD : bit_vector(0 downto 0);
        RX_EQA_CKP_LF : bit_vector(7 downto 0);
        RX_EQA_CKP_HF : bit_vector(7 downto 0);
        RX_EQA_CKP_OFFSET : bit_vector(7 downto 0);
        RX_EN_EQA : bit_vector(0 downto 0);
        RX_EQA_LOCK_CFG : bit_vector(3 downto 0);
        RX_TH_MON1 : bit_vector(4 downto 0);
        RX_EN_EQA_EXT_VALUE : bit_vector(3 downto 0);
        RX_TH_MON2 : bit_vector(4 downto 0);
        RX_TAPW : bit_vector(4 downto 0);
        RX_AFE_OFFSET : bit_vector(4 downto 0);
        RX_EQA_CONFIG : bit_vector(15 downto 0);
        RX_AFE_PEAK : bit_vector(4 downto 0);
        RX_AFE_GAIN : bit_vector(3 downto 0);
        RX_AFE_VCMSEL : bit_vector(2 downto 0);
        RX_CDR_CKP : bit_vector(7 downto 0);
        RX_CDR_CKI : bit_vector(7 downto 0);
        RX_CDR_TRANS_TH : bit_vector(8 downto 0);
        RX_CDR_LOCK_CFG : bit_vector(5 downto 0);
        RX_CDR_FREQ_ACC : bit_vector(14 downto 0);
        RX_CDR_PHASE_ACC : bit_vector(15 downto 0);
        RX_CDR_SET_ACC_CONFIG : bit_vector(1 downto 0);
        RX_CDR_FORCE_LOCK : bit_vector(0 downto 0);
        RX_ALIGN_MCOMMA_VALUE : bit_vector(9 downto 0);
        RX_MCOMMA_ALIGN_OVR : bit_vector(0 downto 0);
        RX_MCOMMA_ALIGN : bit_vector(0 downto 0);
        RX_ALIGN_PCOMMA_VALUE : bit_vector(9 downto 0);
        RX_PCOMMA_ALIGN_OVR : bit_vector(0 downto 0);
        RX_PCOMMA_ALIGN : bit_vector(0 downto 0);
        RX_ALIGN_COMMA_WORD : bit_vector(1 downto 0);
        RX_ALIGN_COMMA_ENABLE : bit_vector(9 downto 0);
        RX_SLIDE_MODE : bit_vector(1 downto 0);
        RX_COMMA_DETECT_EN_OVR : bit_vector(0 downto 0);
        RX_COMMA_DETECT_EN : bit_vector(0 downto 0);
        RX_SLIDE : bit_vector(1 downto 0);
        RX_EYE_MEAS_EN : bit_vector(0 downto 0);
        RX_EYE_MEAS_CFG : bit_vector(14 downto 0);
        RX_MON_PH_OFFSET : bit_vector(5 downto 0);
        RX_EI_BIAS : bit_vector(3 downto 0);
        RX_EI_BW_SEL : bit_vector(3 downto 0);
        RX_EN_EI_DETECTOR_OVR : bit_vector(0 downto 0);
        RX_EN_EI_DETECTOR : bit_vector(0 downto 0);
        RX_DATA_SEL : bit_vector(0 downto 0);
        RX_BUF_BYPASS : bit_vector(0 downto 0);
        RX_CLKCOR_USE : bit_vector(0 downto 0);
        RX_CLKCOR_MIN_LAT : bit_vector(5 downto 0);
        RX_CLKCOR_MAX_LAT : bit_vector(5 downto 0);
        RX_CLKCOR_SEQ_1_0 : bit_vector(9 downto 0);
        RX_CLKCOR_SEQ_1_1 : bit_vector(9 downto 0);
        RX_CLKCOR_SEQ_1_2 : bit_vector(9 downto 0);
        RX_CLKCOR_SEQ_1_3 : bit_vector(9 downto 0);
        RX_PMA_LOOPBACK : bit_vector(0 downto 0);
        RX_PCS_LOOPBACK : bit_vector(0 downto 0);
        RX_DATAPATH_SEL : bit_vector(1 downto 0);
        RX_PRBS_OVR : bit_vector(0 downto 0);
        RX_PRBS_SEL : bit_vector(2 downto 0);
        RX_LOOPBACK_OVR : bit_vector(0 downto 0);
        RX_PRBS_CNT_RESET : bit_vector(0 downto 0);
        RX_POWER_DOWN_OVR : bit_vector(0 downto 0);
        RX_POWER_DOWN_N : bit_vector(0 downto 0);
        RX_RESET_OVR : bit_vector(0 downto 0);
        RX_RESET : bit_vector(0 downto 0);
        RX_PMA_RESET_OVR : bit_vector(0 downto 0);
        RX_PMA_RESET : bit_vector(0 downto 0);
        RX_EQA_RESET_OVR : bit_vector(0 downto 0);
        RX_EQA_RESET : bit_vector(0 downto 0);
        RX_CDR_RESET_OVR : bit_vector(0 downto 0);
        RX_CDR_RESET : bit_vector(0 downto 0);
        RX_PCS_RESET_OVR : bit_vector(0 downto 0);
        RX_PCS_RESET : bit_vector(0 downto 0);
        RX_BUF_RESET_OVR : bit_vector(0 downto 0);
        RX_BUF_RESET : bit_vector(0 downto 0);
        RX_POLARITY_OVR : bit_vector(0 downto 0);
        RX_POLARITY : bit_vector(0 downto 0);
        RX_8B10B_EN_OVR : bit_vector(0 downto 0);
        RX_8B10B_EN : bit_vector(0 downto 0);
        RX_8B10B_BYPASS : bit_vector(7 downto 0);
        RX_BYTE_REALIGN : bit_vector(0 downto 0);
        TX_SEL_PRE : bit_vector(4 downto 0);
        TX_SEL_POST : bit_vector(4 downto 0);
        TX_AMP : bit_vector(4 downto 0);
        TX_BRANCH_EN_PRE : bit_vector(4 downto 0);
        TX_BRANCH_EN_MAIN : bit_vector(5 downto 0);
        TX_BRANCH_EN_POST : bit_vector(4 downto 0);
        TX_TAIL_CASCODE : bit_vector(2 downto 0);
        TX_DC_ENABLE : bit_vector(6 downto 0);
        TX_DC_OFFSET : bit_vector(4 downto 0);
        TX_CM_RAISE : bit_vector(4 downto 0);
        TX_CM_THRESHOLD_0 : bit_vector(4 downto 0);
        TX_CM_THRESHOLD_1 : bit_vector(4 downto 0);
        TX_SEL_PRE_EI : bit_vector(4 downto 0);
        TX_SEL_POST_EI : bit_vector(4 downto 0);
        TX_AMP_EI : bit_vector(4 downto 0);
        TX_BRANCH_EN_PRE_EI : bit_vector(4 downto 0);
        TX_BRANCH_EN_MAIN_EI : bit_vector(5 downto 0);
        TX_BRANCH_EN_POST_EI : bit_vector(4 downto 0);
        TX_TAIL_CASCODE_EI : bit_vector(2 downto 0);
        TX_DC_ENABLE_EI : bit_vector(6 downto 0);
        TX_DC_OFFSET_EI : bit_vector(4 downto 0);
        TX_CM_RAISE_EI : bit_vector(4 downto 0);
        TX_CM_THRESHOLD_0_EI : bit_vector(4 downto 0);
        TX_CM_THRESHOLD_1_EI : bit_vector(4 downto 0);
        TX_SEL_PRE_RXDET : bit_vector(4 downto 0);
        TX_SEL_POST_RXDET : bit_vector(4 downto 0);
        TX_AMP_RXDET : bit_vector(4 downto 0);
        TX_BRANCH_EN_PRE_RXDET : bit_vector(4 downto 0);
        TX_BRANCH_EN_MAIN_RXDET : bit_vector(5 downto 0);
        TX_BRANCH_EN_POST_RXDET : bit_vector(4 downto 0);
        TX_TAIL_CASCODE_RXDET : bit_vector(2 downto 0);
        TX_DC_ENABLE_RXDET : bit_vector(6 downto 0);
        TX_DC_OFFSET_RXDET : bit_vector(4 downto 0);
        TX_CM_RAISE_RXDET : bit_vector(4 downto 0);
        TX_CM_THRESHOLD_0_RXDET : bit_vector(4 downto 0);
        TX_CM_THRESHOLD_1_RXDET : bit_vector(4 downto 0);
        TX_CALIB_EN : bit_vector(0 downto 0);
        TX_CALIB_OVR : bit_vector(0 downto 0);
        TX_CALIB_VAL : bit_vector(3 downto 0);
        TX_CM_REG_KI : bit_vector(7 downto 0);
        TX_CM_SAR_EN : bit_vector(0 downto 0);
        TX_CM_REG_EN : bit_vector(0 downto 0);
        TX_PMA_RESET_TIME : bit_vector(4 downto 0);
        TX_PCS_RESET_TIME : bit_vector(4 downto 0);
        TX_PCS_RESET_OVR : bit_vector(0 downto 0);
        TX_PCS_RESET : bit_vector(0 downto 0);
        TX_PMA_RESET_OVR : bit_vector(0 downto 0);
        TX_PMA_RESET : bit_vector(0 downto 0);
        TX_RESET_OVR : bit_vector(0 downto 0);
        TX_RESET : bit_vector(0 downto 0);
        TX_PMA_LOOPBACK : bit_vector(1 downto 0);
        TX_PCS_LOOPBACK : bit_vector(0 downto 0);
        TX_DATAPATH_SEL : bit_vector(1 downto 0);
        TX_PRBS_OVR : bit_vector(0 downto 0);
        TX_PRBS_SEL : bit_vector(2 downto 0);
        TX_PRBS_FORCE_ERR : bit_vector(0 downto 0);
        TX_LOOPBACK_OVR : bit_vector(0 downto 0);
        TX_POWER_DOWN_OVR : bit_vector(0 downto 0);
        TX_POWER_DOWN_N : bit_vector(0 downto 0);
        TX_ELEC_IDLE_OVR : bit_vector(0 downto 0);
        TX_ELEC_IDLE : bit_vector(0 downto 0);
        TX_DETECT_RX_OVR : bit_vector(0 downto 0);
        TX_DETECT_RX : bit_vector(0 downto 0);
        TX_POLARITY_OVR : bit_vector(0 downto 0);
        TX_POLARITY : bit_vector(0 downto 0);
        TX_8B10B_EN_OVR : bit_vector(0 downto 0);
        TX_8B10B_EN : bit_vector(0 downto 0);
        TX_DATA_OVR : bit_vector(0 downto 0);
        TX_DATA_CNT : bit_vector(2 downto 0);
        TX_DATA_VALID : bit_vector(0 downto 0);
        PLL_EN_ADPLL_CTRL : bit_vector(0 downto 0);
        PLL_CONFIG_SEL : bit_vector(0 downto 0);
        PLL_SET_OP_LOCK : bit_vector(0 downto 0);
        PLL_ENFORCE_LOCK : bit_vector(0 downto 0);
        PLL_DISABLE_LOCK : bit_vector(0 downto 0);
        PLL_LOCK_WINDOW : bit_vector(0 downto 0);
        PLL_FAST_LOCK : bit_vector(0 downto 0);
        PLL_SYNC_BYPASS : bit_vector(0 downto 0);
        PLL_PFD_SELECT : bit_vector(0 downto 0);
        PLL_REF_BYPASS : bit_vector(0 downto 0);
        PLL_REF_SEL : bit_vector(0 downto 0);
        PLL_REF_RTERM : bit_vector(0 downto 0);
        PLL_FCNTRL : bit_vector(5 downto 0);
        PLL_MAIN_DIVSEL : bit_vector(5 downto 0);
        PLL_OUT_DIVSEL : bit_vector(1 downto 0);
        PLL_CI : bit_vector(4 downto 0);
        PLL_CP : bit_vector(9 downto 0);
        PLL_AO : bit_vector(3 downto 0);
        PLL_SCAP : bit_vector(2 downto 0);
        PLL_FILTER_SHIFT : bit_vector(1 downto 0);
        PLL_SAR_LIMIT : bit_vector(2 downto 0);
        PLL_FT : bit_vector(10 downto 0);
        PLL_OPEN_LOOP : bit_vector(0 downto 0);
        PLL_SCAP_AUTO_CAL : bit_vector(0 downto 0);
        PLL_BISC_MODE : bit_vector(2 downto 0);
        PLL_BISC_TIMER_MAX : bit_vector(3 downto 0);
        PLL_BISC_OPT_DET_IND : bit_vector(0 downto 0);
        PLL_BISC_PFD_SEL : bit_vector(0 downto 0);
        PLL_BISC_DLY_DIR : bit_vector(0 downto 0);
        PLL_BISC_COR_DLY : bit_vector(2 downto 0);
        PLL_BISC_CAL_SIGN : bit_vector(0 downto 0);
        PLL_BISC_CAL_AUTO : bit_vector(0 downto 0);
        PLL_BISC_CP_MIN : bit_vector(4 downto 0);
        PLL_BISC_CP_MAX : bit_vector(4 downto 0);
        PLL_BISC_CP_START : bit_vector(4 downto 0);
        PLL_BISC_DLY_PFD_MON_REF : bit_vector(4 downto 0);
        PLL_BISC_DLY_PFD_MON_DIV : bit_vector(4 downto 0);
        SERDES_ENABLE : bit_vector(0 downto 0);
        SERDES_AUTO_INIT : bit_vector(0 downto 0);
        SERDES_TESTMODE : bit_vector(0 downto 0)
    );
    port (
        TX_DATA_I : in std_logic_vector(63 downto 0);
        TX_RESET_I : in std_logic;
        TX_PCS_RESET_I : in std_logic;
        TX_PMA_RESET_I : in std_logic;
        PLL_RESET_I : in std_logic;
        TX_POWER_DOWN_N_I : in std_logic;
        TX_POLARITY_I : in std_logic;
        TX_PRBS_SEL_I : in std_logic_vector(2 downto 0);
        TX_PRBS_FORCE_ERR_I : in std_logic;
        TX_8B10B_EN_I : in std_logic;
        TX_8B10B_BYPASS_I : in std_logic_vector(7 downto 0);
        TX_CHAR_IS_K_I : in std_logic_vector(7 downto 0);
        TX_CHAR_DISPMODE_I : in std_logic_vector(7 downto 0);
        TX_CHAR_DISPVAL_I : in std_logic_vector(7 downto 0);
        TX_ELEC_IDLE_I : in std_logic;
        TX_DETECT_RX_I : in std_logic;
        LOOPBACK_I : in std_logic_vector(2 downto 0);
        TX_CLK_I : in std_logic;
        RX_CLK_I : in std_logic;
        RX_RESET_I : in std_logic;
        RX_PMA_RESET_I : in std_logic;
        RX_EQA_RESET_I : in std_logic;
        RX_CDR_RESET_I : in std_logic;
        RX_PCS_RESET_I : in std_logic;
        RX_BUF_RESET_I : in std_logic;
        RX_POWER_DOWN_N_I : in std_logic;
        RX_POLARITY_I : in std_logic;
        RX_PRBS_SEL_I : in std_logic_vector(2 downto 0);
        RX_PRBS_CNT_RESET_I : in std_logic;
        RX_8B10B_EN_I : in std_logic;
        RX_8B10B_BYPASS_I : in std_logic_vector(7 downto 0);
        RX_EN_EI_DETECTOR_I : in std_logic;
        RX_COMMA_DETECT_EN_I : in std_logic;
        RX_SLIDE_I : in std_logic;
        RX_MCOMMA_ALIGN_I : in std_logic;
        RX_PCOMMA_ALIGN_I : in std_logic;
        REGFILE_CLK_I : in std_logic;
        REGFILE_WE_I : in std_logic;
        REGFILE_EN_I : in std_logic;
        REGFILE_ADDR_I : in std_logic_vector(7 downto 0);
        REGFILE_DI_I : in std_logic_vector(15 downto 0);
        REGFILE_MASK_I : in std_logic_vector(15 downto 0);
        RX_DATA_O : out std_logic_vector(63 downto 0);
        RX_NOT_IN_TABLE_O : out std_logic_vector(7 downto 0);
        RX_CHAR_IS_COMMA_O : out std_logic_vector(7 downto 0);
        RX_CHAR_IS_K_O : out std_logic_vector(7 downto 0);
        RX_DISP_ERR_O : out std_logic_vector(7 downto 0);
        TX_DETECT_RX_DONE_O : out std_logic;
        TX_DETECT_RX_PRESENT_O : out std_logic;
        TX_BUF_ERR_O : out std_logic;
        TX_RESET_DONE_O : out std_logic;
        RX_PRBS_ERR_O : out std_logic;
        RX_BUF_ERR_O : out std_logic;
        RX_BYTE_IS_ALIGNED_O : out std_logic;
        RX_BYTE_REALIGN_O : out std_logic;
        RX_RESET_DONE_O : out std_logic;
        RX_EI_EN_O : out std_logic;
        RX_CLK_O : out std_logic;
        PLL_CLK_O : out std_logic;
        REGFILE_DO_O : out std_logic_vector(15 downto 0);
        REGFILE_RDY_O : out std_logic
    );
    end component;

    signal trx_rst_i : std_logic;
    signal pll_rst_i : std_logic;
    signal tx_data : std_logic_vector(63 downto 0);
    signal TX_DETECT_RX_DONE_O: std_logic;
    signal TX_DETECT_RX_PRESENT_O: std_logic;
    signal TX_BUF_ERR_O : std_logic;
    signal RX_BUF_ERR_O : std_logic;
    signal TX_RESET_DONE_O : std_logic;
    signal RX_RESET_DONE_O : std_logic;

begin

    i_cc_serdes: CC_SERDES
    generic map (
        RX_BUF_RESET_TIME => 5X"3",
        RX_PCS_RESET_TIME => 5X"3",
        RX_RESET_TIMER_PRESC => 5X"0",
        RX_RESET_DONE_GATE => 1X"0",
        RX_CDR_RESET_TIME => 5X"3",
        RX_EQA_RESET_TIME => 5X"3",
        RX_PMA_RESET_TIME => 5X"3",
        RX_WAIT_CDR_LOCK => 1X"0",
        RX_CALIB_EN => 1X"0",
        RX_CALIB_OVR => 1X"0",
        RX_CALIB_VAL => 4X"0",
        RX_RTERM_VCMSEL => 3X"4",
        RX_RTERM_PD => 1X"0",
        RX_EQA_CKP_LF => 8X"A3",
        RX_EQA_CKP_HF => 8X"A3",
        RX_EQA_CKP_OFFSET => 8X"1",
        RX_EN_EQA => 1X"0",
        RX_EQA_LOCK_CFG => 4X"0",
        RX_TH_MON1 => 5X"8",
        RX_EN_EQA_EXT_VALUE => 4X"0",
        RX_TH_MON2 => 5X"8",
        RX_TAPW => 5X"8",
        RX_AFE_OFFSET => 5X"8",
        RX_EQA_CONFIG => 16X"1C0",
        RX_AFE_PEAK => 5X"F",
        RX_AFE_GAIN => 4X"8",
        RX_AFE_VCMSEL => 3X"4",
        RX_CDR_CKP => 8X"F8",
        RX_CDR_CKI => 8X"0",
        RX_CDR_TRANS_TH => 9X"80",
        RX_CDR_LOCK_CFG => 6X"B",
        RX_CDR_FREQ_ACC => 15X"0",
        RX_CDR_PHASE_ACC => 16X"0",
        RX_CDR_SET_ACC_CONFIG => 2X"0",
        RX_CDR_FORCE_LOCK => 1X"0",
        RX_ALIGN_MCOMMA_VALUE => 10X"283",
        RX_MCOMMA_ALIGN_OVR => 1X"0",
        RX_MCOMMA_ALIGN => 1X"0",
        RX_ALIGN_PCOMMA_VALUE => 10X"17C",
        RX_PCOMMA_ALIGN_OVR => 1X"0",
        RX_PCOMMA_ALIGN => 1X"0",
        RX_ALIGN_COMMA_WORD => 2X"3",
        RX_ALIGN_COMMA_ENABLE => 10X"3FF",
        RX_SLIDE_MODE => 2X"0",
        RX_COMMA_DETECT_EN_OVR => 1X"0",
        RX_COMMA_DETECT_EN => 1X"0",
        RX_SLIDE => 2X"0",
        RX_EYE_MEAS_EN => 1X"0",
        RX_EYE_MEAS_CFG => 15X"0",
        RX_MON_PH_OFFSET => 6X"0",
        RX_EI_BIAS => 4X"4",
        RX_EI_BW_SEL => 4X"4",
        RX_EN_EI_DETECTOR_OVR => 1X"0",
        RX_EN_EI_DETECTOR => 1X"0",
        RX_DATA_SEL => 1X"0",
        RX_BUF_BYPASS => 1X"0",
        RX_CLKCOR_USE => 1X"0",
        RX_CLKCOR_MIN_LAT => 6X"20",
        RX_CLKCOR_MAX_LAT => 6X"27",
        RX_CLKCOR_SEQ_1_0 => 10X"1F7",
        RX_CLKCOR_SEQ_1_1 => 10X"1F7",
        RX_CLKCOR_SEQ_1_2 => 10X"1F7",
        RX_CLKCOR_SEQ_1_3 => 10X"1F7",
        RX_PMA_LOOPBACK => 1X"0",
        RX_PCS_LOOPBACK => 1X"0",
        RX_DATAPATH_SEL => DATAPATH_SEL,
        RX_PRBS_OVR => 1X"0",
        RX_PRBS_SEL => 3X"0",
        RX_LOOPBACK_OVR => 1X"0",
        RX_PRBS_CNT_RESET => 1X"0",
        RX_POWER_DOWN_OVR => 1X"0",
        RX_POWER_DOWN_N => 1X"0",
        RX_RESET_OVR => 1X"0",
        RX_RESET => 1X"0",
        RX_PMA_RESET_OVR => 1X"0",
        RX_PMA_RESET => 1X"0",
        RX_EQA_RESET_OVR => 1X"0",
        RX_EQA_RESET => 1X"0",
        RX_CDR_RESET_OVR => 1X"0",
        RX_CDR_RESET => 1X"0",
        RX_PCS_RESET_OVR => 1X"0",
        RX_PCS_RESET => 1X"0",
        RX_BUF_RESET_OVR => 1X"0",
        RX_BUF_RESET => 1X"0",
        RX_POLARITY_OVR => 1X"0",
        RX_POLARITY => 1X"0",
        RX_8B10B_EN_OVR => 1X"0",
        RX_8B10B_EN => 1X"0",
        RX_8B10B_BYPASS => 8X"0",
        RX_BYTE_REALIGN => 1X"0",
        TX_SEL_PRE => 5X"0",
        TX_SEL_POST => 5X"0",
        TX_AMP => 5X"F",
        TX_BRANCH_EN_PRE => 5X"0",
        TX_BRANCH_EN_MAIN => 6X"3F",
        TX_BRANCH_EN_POST => 5X"0",
        TX_TAIL_CASCODE => 3X"4",
        TX_DC_ENABLE => 7X"3F",
        TX_DC_OFFSET => 5X"8",
        TX_CM_RAISE => 5X"0",
        TX_CM_THRESHOLD_0 => 5X"E",
        TX_CM_THRESHOLD_1 => 5X"10",
        TX_SEL_PRE_EI => 5X"0",
        TX_SEL_POST_EI => 5X"0",
        TX_AMP_EI => 5X"F",
        TX_BRANCH_EN_PRE_EI => 5X"0",
        TX_BRANCH_EN_MAIN_EI => 6X"3F",
        TX_BRANCH_EN_POST_EI => 5X"0",
        TX_TAIL_CASCODE_EI => 3X"4",
        TX_DC_ENABLE_EI => 7X"3F",
        TX_DC_OFFSET_EI => 5X"0",
        TX_CM_RAISE_EI => 5X"0",
        TX_CM_THRESHOLD_0_EI => 5X"E",
        TX_CM_THRESHOLD_1_EI => 5X"10",
        TX_SEL_PRE_RXDET => 5X"0",
        TX_SEL_POST_RXDET => 5X"0",
        TX_AMP_RXDET => 5X"F",
        TX_BRANCH_EN_PRE_RXDET => 5X"0",
        TX_BRANCH_EN_MAIN_RXDET => 6X"3F",
        TX_BRANCH_EN_POST_RXDET => 5X"0",
        TX_TAIL_CASCODE_RXDET => 3X"4",
        TX_DC_ENABLE_RXDET => 7X"3F",
        TX_DC_OFFSET_RXDET => 5X"0",
        TX_CM_RAISE_RXDET => 5X"0",
        TX_CM_THRESHOLD_0_RXDET => 5X"E",
        TX_CM_THRESHOLD_1_RXDET => 5X"10",
        TX_CALIB_EN => 1X"0",
        TX_CALIB_OVR => 1X"0",
        TX_CALIB_VAL => 4X"0",
        TX_CM_REG_KI => 8X"80",
        TX_CM_SAR_EN => 1X"0",
        TX_CM_REG_EN => 1X"1",
        TX_PMA_RESET_TIME => 5X"3",
        TX_PCS_RESET_TIME => 5X"3",
        TX_PCS_RESET_OVR => 1X"0",
        TX_PCS_RESET => 1X"0",
        TX_PMA_RESET_OVR => 1X"0",
        TX_PMA_RESET => 1X"0",
        TX_RESET_OVR => 1X"0",
        TX_RESET => 1X"0",
        TX_PMA_LOOPBACK => TX_PMA_LOOPBACK,
        TX_PCS_LOOPBACK => 1X"0",
        TX_DATAPATH_SEL => DATAPATH_SEL,
        TX_PRBS_OVR => 1X"0",
        TX_PRBS_SEL => 3X"0",
        TX_PRBS_FORCE_ERR => 1X"0",
        TX_LOOPBACK_OVR => 1X"0",
        TX_POWER_DOWN_OVR => 1X"0",
        TX_POWER_DOWN_N => 1X"1",
        TX_ELEC_IDLE_OVR => 1X"0",
        TX_ELEC_IDLE => 1X"0",
        TX_DETECT_RX_OVR => 1X"0",
        TX_DETECT_RX => 1X"0",
        TX_POLARITY_OVR => 1X"0",
        TX_POLARITY => 1X"0",
        TX_8B10B_EN_OVR => 1X"0",
        TX_8B10B_EN => 1X"0",
        TX_DATA_OVR => 1X"0",
        TX_DATA_CNT => 3X"0",
        TX_DATA_VALID => 1X"0",
        PLL_EN_ADPLL_CTRL => 1X"1",
        PLL_CONFIG_SEL => 1X"1",
        PLL_SET_OP_LOCK => 1X"0",
        PLL_ENFORCE_LOCK => 1X"0",
        PLL_DISABLE_LOCK => 1X"0",
        PLL_LOCK_WINDOW => 1X"1",
        PLL_FAST_LOCK => 1X"1",
        PLL_SYNC_BYPASS => 1X"0",
        PLL_PFD_SELECT => 1X"0",
        PLL_REF_BYPASS => 1X"0",
        PLL_REF_SEL => 1X"1",
        PLL_REF_RTERM => 1X"1",
        PLL_FCNTRL => PLL_FCNTRL,
        PLL_MAIN_DIVSEL => PLL_MAIN_DIVSEL,
        PLL_OUT_DIVSEL => PLL_OUT_DIVSEL,
        PLL_CI => 5X"3",
        PLL_CP => 10X"50",
        PLL_AO => 4X"0",
        PLL_SCAP => 3X"0",
        PLL_FILTER_SHIFT => 2X"2",
        PLL_SAR_LIMIT => 3X"2",
        PLL_FT => 11X"200",
        PLL_OPEN_LOOP => 1X"0",
        PLL_SCAP_AUTO_CAL => 1X"1",
        PLL_BISC_MODE => 3X"4",
        PLL_BISC_TIMER_MAX => 4X"F",
        PLL_BISC_OPT_DET_IND => 1X"0",
        PLL_BISC_PFD_SEL => 1X"0",
        PLL_BISC_DLY_DIR => 1X"0",
        PLL_BISC_COR_DLY => 3X"1",
        PLL_BISC_CAL_SIGN => 1X"0",
        PLL_BISC_CAL_AUTO => 1X"1",
        PLL_BISC_CP_MIN => 5X"4",
        PLL_BISC_CP_MAX => 5X"12",
        PLL_BISC_CP_START => 5X"C",
        PLL_BISC_DLY_PFD_MON_REF => 5X"0",
        PLL_BISC_DLY_PFD_MON_DIV => 5X"2",
        SERDES_ENABLE => 1X"1",
        SERDES_AUTO_INIT => 1X"0",
        SERDES_TESTMODE => 1X"0"
    )
    port map (
        TX_DATA_I => tx_data,
        TX_RESET_I => trx_rst_i,
        TX_PCS_RESET_I => '0',
        TX_PMA_RESET_I => '0',
        PLL_RESET_I => pll_rst_i,
        TX_POWER_DOWN_N_I => '1',
        TX_POLARITY_I => '0',
        TX_PRBS_SEL_I => (others => '0'),
        TX_PRBS_FORCE_ERR_I => '0',
        TX_8B10B_EN_I => ENABLE_8B10B,
        TX_8B10B_BYPASS_I => (others => '0'),
        TX_CHAR_IS_K_I => 8X"1",
        TX_CHAR_DISPMODE_I => (others => '0'),
        TX_CHAR_DISPVAL_I => (others => '0'),
        TX_ELEC_IDLE_I => '0',
        TX_DETECT_RX_I => '1',
        LOOPBACK_I => LOOPBACK_SEL,
        TX_CLK_I => CLK_CORE_PLL_O,
        RX_CLK_I => CLK_CORE_RX_O,
        RX_RESET_I => trx_rst_i,
        RX_PMA_RESET_I => '0',
        RX_EQA_RESET_I => '0',
        RX_CDR_RESET_I => '0',
        RX_PCS_RESET_I => '0',
        RX_BUF_RESET_I => '0',
        RX_POWER_DOWN_N_I => '1',
        RX_POLARITY_I => '0',
        RX_PRBS_SEL_I => (others => '0'),
        RX_PRBS_CNT_RESET_I => '0',
        RX_8B10B_EN_I => ENABLE_8B10B,
        RX_8B10B_BYPASS_I => (others => '0'),
        RX_EN_EI_DETECTOR_I => '0',
        RX_COMMA_DETECT_EN_I => '1',
        RX_SLIDE_I => '0',
        RX_MCOMMA_ALIGN_I => '1',
        RX_PCOMMA_ALIGN_I => '1',
        REGFILE_CLK_I => '0',
        REGFILE_WE_I => '0',
        REGFILE_EN_I => '0',
        REGFILE_ADDR_I => (others => '0'),
        REGFILE_DI_I => (others => '0'),
        REGFILE_MASK_I => (others => '0'),
        RX_DATA_O => RX_DATA_O,
        RX_NOT_IN_TABLE_O => open,
        RX_CHAR_IS_COMMA_O => open,
        RX_CHAR_IS_K_O => open,
        RX_DISP_ERR_O => open,
        TX_DETECT_RX_DONE_O => TX_DETECT_RX_DONE_O,
        TX_DETECT_RX_PRESENT_O => TX_DETECT_RX_PRESENT_O,
        TX_BUF_ERR_O => TX_BUF_ERR_O,
        TX_RESET_DONE_O => TX_RESET_DONE_O,
        RX_PRBS_ERR_O => open,
        RX_BUF_ERR_O => RX_BUF_ERR_O,
        RX_BYTE_IS_ALIGNED_O => open,
        RX_BYTE_REALIGN_O => open,
        RX_RESET_DONE_O => RX_RESET_DONE_O,
        RX_EI_EN_O => open,
        RX_CLK_O => CLK_CORE_RX_O,
        PLL_CLK_O => CLK_CORE_PLL_O,
        REGFILE_DO_O => open,
        REGFILE_RDY_O => open
    );

    trx_rst_i <= not trx_rstn_i;
    pll_rst_i <= not pll_rstn_i;
    tx_data <= X"0000000000" & X"CAFE" & X"BC";
    TX_DETECT_RX_DONE_O_N <= not TX_DETECT_RX_DONE_O;
    TX_DETECT_RX_PRESENT_O_N <= not TX_DETECT_RX_PRESENT_O;
    TX_BUF_ERR_O_N <= not TX_BUF_ERR_O;
    RX_BUF_ERR_O_N <= not RX_BUF_ERR_O;
    TX_RESET_DONE_O_N <= not TX_RESET_DONE_O;
    RX_RESET_DONE_O_N <= not RX_RESET_DONE_O;

end architecture;
