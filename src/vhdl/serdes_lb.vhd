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

    -- CC_SERDES instance generator
    -- generated: 2025-01-23 18:43:22

    component CC_SERDES is
    generic (
        RX_BUF_RESET_TIME : bit_vector;
        RX_PCS_RESET_TIME : bit_vector;
        RX_RESET_TIMER_PRESC : bit_vector;
        RX_RESET_DONE_GATE : bit_vector;
        RX_CDR_RESET_TIME : bit_vector;
        RX_EQA_RESET_TIME : bit_vector;
        RX_PMA_RESET_TIME : bit_vector;
        RX_WAIT_CDR_LOCK : bit_vector;
        RX_CALIB_EN : bit_vector;
        RX_CALIB_OVR : bit_vector;
        RX_CALIB_VAL : bit_vector;
        RX_RTERM_VCMSEL : bit_vector;
        RX_RTERM_PD : bit_vector;
        RX_EQA_CKP_LF : bit_vector;
        RX_EQA_CKP_HF : bit_vector;
        RX_EQA_CKP_OFFSET : bit_vector;
        RX_EN_EQA : bit_vector;
        RX_EQA_LOCK_CFG : bit_vector;
        RX_TH_MON1 : bit_vector;
        --RX_EN_EQA_EXT_VALUE[0] : bit_vector;
        RX_TH_MON2 : bit_vector;
        --RX_EN_EQA_EXT_VALUE[1] : bit_vector;
        RX_TAPW : bit_vector;
        --RX_EN_EQA_EXT_VALUE[2] : bit_vector;
        RX_AFE_OFFSET : bit_vector;
        --RX_EN_EQA_EXT_VALUE[3] : bit_vector;
        RX_EQA_CONFIG : bit_vector;
        RX_AFE_PEAK : bit_vector;
        RX_AFE_GAIN : bit_vector;
        RX_AFE_VCMSEL : bit_vector;
        RX_CDR_CKP : bit_vector;
        RX_CDR_CKI : bit_vector;
        RX_CDR_TRANS_TH : bit_vector;
        RX_CDR_LOCK_CFG : bit_vector;
        RX_CDR_FREQ_ACC : bit_vector;
        RX_CDR_PHASE_ACC : bit_vector;
        RX_CDR_SET_ACC_CONFIG : bit_vector;
        RX_CDR_FORCE_LOCK : bit_vector;
        RX_ALIGN_MCOMMA_VALUE : bit_vector;
        RX_MCOMMA_ALIGN_OVR : bit_vector;
        RX_MCOMMA_ALIGN : bit_vector;
        RX_ALIGN_PCOMMA_VALUE : bit_vector;
        RX_PCOMMA_ALIGN_OVR : bit_vector;
        RX_PCOMMA_ALIGN : bit_vector;
        RX_ALIGN_COMMA_WORD : bit_vector;
        RX_ALIGN_COMMA_ENABLE : bit_vector;
        RX_SLIDE_MODE : bit_vector;
        RX_COMMA_DETECT_EN_OVR : bit_vector;
        RX_COMMA_DETECT_EN : bit_vector;
        --RX_SLIDE[0] : bit_vector;
        --RX_SLIDE[1] : bit_vector;
        RX_EYE_MEAS_EN : bit_vector;
        RX_EYE_MEAS_CFG : bit_vector;
        RX_MON_PH_OFFSET : bit_vector;
        RX_EI_BIAS : bit_vector;
        RX_EI_BW_SEL : bit_vector;
        RX_EN_EI_DETECTOR_OVR : bit_vector;
        RX_EN_EI_DETECTOR : bit_vector;
        RX_DATA_SEL : bit_vector;
        RX_BUF_BYPASS : bit_vector;
        RX_CLKCOR_USE : bit_vector;
        RX_CLKCOR_MIN_LAT : bit_vector;
        RX_CLKCOR_MAX_LAT : bit_vector;
        RX_CLKCOR_SEQ_1_0 : bit_vector;
        RX_CLKCOR_SEQ_1_1 : bit_vector;
        RX_CLKCOR_SEQ_1_2 : bit_vector;
        RX_CLKCOR_SEQ_1_3 : bit_vector;
        RX_PMA_LOOPBACK : bit_vector;
        RX_PCS_LOOPBACK : bit_vector;
        RX_DATAPATH_SEL : bit_vector;
        RX_PRBS_OVR : bit_vector;
        RX_PRBS_SEL : bit_vector;
        RX_LOOPBACK_OVR : bit_vector;
        RX_PRBS_CNT_RESET : bit_vector;
        RX_POWER_DOWN_OVR : bit_vector;
        RX_POWER_DOWN_N : bit_vector;
        RX_RESET_OVR : bit_vector;
        RX_RESET : bit_vector;
        RX_PMA_RESET_OVR : bit_vector;
        RX_PMA_RESET : bit_vector;
        RX_EQA_RESET_OVR : bit_vector;
        RX_EQA_RESET : bit_vector;
        RX_CDR_RESET_OVR : bit_vector;
        RX_CDR_RESET : bit_vector;
        RX_PCS_RESET_OVR : bit_vector;
        RX_PCS_RESET : bit_vector;
        RX_BUF_RESET_OVR : bit_vector;
        RX_BUF_RESET : bit_vector;
        RX_POLARITY_OVR : bit_vector;
        RX_POLARITY : bit_vector;
        RX_8B10B_EN_OVR : bit_vector;
        RX_8B10B_EN : bit_vector;
        RX_8B10B_BYPASS : bit_vector;
        RX_BYTE_REALIGN : bit_vector;
        TX_SEL_PRE : bit_vector;
        TX_SEL_POST : bit_vector;
        TX_AMP : bit_vector;
        TX_BRANCH_EN_PRE : bit_vector;
        TX_BRANCH_EN_MAIN : bit_vector;
        TX_BRANCH_EN_POST : bit_vector;
        TX_TAIL_CASCODE : bit_vector;
        TX_DC_ENABLE : bit_vector;
        TX_DC_OFFSET : bit_vector;
        TX_CM_RAISE : bit_vector;
        TX_CM_THRESHOLD_0 : bit_vector;
        TX_CM_THRESHOLD_1 : bit_vector;
        TX_SEL_PRE_EI : bit_vector;
        TX_SEL_POST_EI : bit_vector;
        TX_AMP_EI : bit_vector;
        TX_BRANCH_EN_PRE_EI : bit_vector;
        TX_BRANCH_EN_MAIN_EI : bit_vector;
        TX_BRANCH_EN_POST_EI : bit_vector;
        TX_TAIL_CASCODE_EI : bit_vector;
        TX_DC_ENABLE_EI : bit_vector;
        TX_DC_OFFSET_EI : bit_vector;
        TX_CM_RAISE_EI : bit_vector;
        TX_CM_THRESHOLD_0_EI : bit_vector;
        TX_CM_THRESHOLD_1_EI : bit_vector;
        TX_SEL_PRE_RXDET : bit_vector;
        TX_SEL_POST_RXDET : bit_vector;
        TX_AMP_RXDET : bit_vector;
        TX_BRANCH_EN_PRE_RXDET : bit_vector;
        TX_BRANCH_EN_MAIN_RXDET : bit_vector;
        TX_BRANCH_EN_POST_RXDET : bit_vector;
        TX_TAIL_CASCODE_RXDET : bit_vector;
        TX_DC_ENABLE_RXDET : bit_vector;
        TX_DC_OFFSET_RXDET : bit_vector;
        TX_CM_RAISE_RXDET : bit_vector;
        TX_CM_THRESHOLD_0_RXDET : bit_vector;
        TX_CM_THRESHOLD_1_RXDET : bit_vector;
        TX_CALIB_EN : bit_vector;
        TX_CALIB_OVR : bit_vector;
        TX_CALIB_VAL : bit_vector;
        TX_CM_REG_KI : bit_vector;
        TX_CM_SAR_EN : bit_vector;
        TX_CM_REG_EN : bit_vector;
        TX_PMA_RESET_TIME : bit_vector;
        TX_PCS_RESET_TIME : bit_vector;
        TX_PCS_RESET_OVR : bit_vector;
        TX_PCS_RESET : bit_vector;
        TX_PMA_RESET_OVR : bit_vector;
        TX_PMA_RESET : bit_vector;
        TX_RESET_OVR : bit_vector;
        TX_RESET : bit_vector;
        TX_PMA_LOOPBACK : bit_vector;
        TX_PCS_LOOPBACK : bit_vector;
        TX_DATAPATH_SEL : bit_vector;
        TX_PRBS_OVR : bit_vector;
        TX_PRBS_SEL : bit_vector;
        TX_PRBS_FORCE_ERR : bit_vector;
        TX_LOOPBACK_OVR : bit_vector;
        TX_POWER_DOWN_OVR : bit_vector;
        TX_POWER_DOWN_N : bit_vector;
        TX_ELEC_IDLE_OVR : bit_vector;
        TX_ELEC_IDLE : bit_vector;
        TX_DETECT_RX_OVR : bit_vector;
        TX_DETECT_RX : bit_vector;
        TX_POLARITY_OVR : bit_vector;
        TX_POLARITY : bit_vector;
        TX_8B10B_EN_OVR : bit_vector;
        TX_8B10B_EN : bit_vector;
        TX_DATA_OVR : bit_vector;
        TX_DATA_CNT : bit_vector;
        TX_DATA_VALID : bit_vector;
        PLL_EN_ADPLL_CTRL : bit_vector;
        PLL_CONFIG_SEL : bit_vector;
        PLL_SET_OP_LOCK : bit_vector;
        PLL_ENFORCE_LOCK : bit_vector;
        PLL_DISABLE_LOCK : bit_vector;
        PLL_LOCK_WINDOW : bit_vector;
        PLL_FAST_LOCK : bit_vector;
        PLL_SYNC_BYPASS : bit_vector;
        PLL_PFD_SELECT : bit_vector;
        PLL_REF_BYPASS : bit_vector;
        PLL_REF_SEL : bit_vector;
        PLL_REF_RTERM : bit_vector;
        PLL_FCNTRL : bit_vector;
        PLL_MAIN_DIVSEL : bit_vector;
        PLL_OUT_DIVSEL : bit_vector;
        PLL_CI : bit_vector;
        PLL_CP : bit_vector;
        PLL_AO : bit_vector;
        PLL_SCAP : bit_vector;
        PLL_FILTER_SHIFT : bit_vector;
        PLL_SAR_LIMIT : bit_vector;
        PLL_FT : bit_vector;
        PLL_OPEN_LOOP : bit_vector;
        PLL_SCAP_AUTO_CAL : bit_vector;
        PLL_BISC_MODE : bit_vector;
        PLL_BISC_TIMER_MAX : bit_vector;
        PLL_BISC_OPT_DET_IND : bit_vector;
        PLL_BISC_PFD_SEL : bit_vector;
        PLL_BISC_DLY_DIR : bit_vector;
        PLL_BISC_COR_DLY : bit_vector;
        PLL_BISC_CAL_SIGN : bit_vector;
        PLL_BISC_CAL_AUTO : bit_vector;
        PLL_BISC_CP_MIN : bit_vector;
        PLL_BISC_CP_MAX : bit_vector;
        PLL_BISC_CP_START : bit_vector;
        PLL_BISC_DLY_PFD_MON_REF : bit_vector;
        PLL_BISC_DLY_PFD_MON_DIV : bit_vector;
        SERDES_ENABLE : bit_vector;
        SERDES_AUTO_INIT : bit_vector;
        SERDES_TESTMODE : bit_vector
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
        RX_BUF_RESET_TIME => X"3",
        RX_PCS_RESET_TIME => X"3",
        RX_RESET_TIMER_PRESC => X"0",
        RX_RESET_DONE_GATE => X"0",
        RX_CDR_RESET_TIME => X"3",
        RX_EQA_RESET_TIME => X"3",
        RX_PMA_RESET_TIME => X"3",
        RX_WAIT_CDR_LOCK => X"0",
        RX_CALIB_EN => X"0",
        RX_CALIB_OVR => X"0",
        RX_CALIB_VAL => X"0",
        RX_RTERM_VCMSEL => X"4",
        RX_RTERM_PD => X"0",
        RX_EQA_CKP_LF => X"A3",
        RX_EQA_CKP_HF => X"A3",
        RX_EQA_CKP_OFFSET => X"1",
        RX_EN_EQA => X"0",
        RX_EQA_LOCK_CFG => X"0",
        RX_TH_MON1 => X"8",
        --RX_EN_EQA_EXT_VALUE[0] => X"0",
        RX_TH_MON2 => X"8",
        --RX_EN_EQA_EXT_VALUE[1] => X"0",
        RX_TAPW => X"8",
        --RX_EN_EQA_EXT_VALUE[2] => X"0",
        RX_AFE_OFFSET => X"8",
        --RX_EN_EQA_EXT_VALUE[3] => X"0",
        RX_EQA_CONFIG => X"1C0",
        RX_AFE_PEAK => X"F",
        RX_AFE_GAIN => X"8",
        RX_AFE_VCMSEL => X"4",
        RX_CDR_CKP => X"F8",
        RX_CDR_CKI => X"0",
        RX_CDR_TRANS_TH => X"80",
        RX_CDR_LOCK_CFG => X"B",
        RX_CDR_FREQ_ACC => X"0",
        RX_CDR_PHASE_ACC => X"0",
        RX_CDR_SET_ACC_CONFIG => X"0",
        RX_CDR_FORCE_LOCK => X"0",
        RX_ALIGN_MCOMMA_VALUE => X"283",
        RX_MCOMMA_ALIGN_OVR => X"0",
        RX_MCOMMA_ALIGN => X"0",
        RX_ALIGN_PCOMMA_VALUE => X"17C",
        RX_PCOMMA_ALIGN_OVR => X"0",
        RX_PCOMMA_ALIGN => X"0",
        RX_ALIGN_COMMA_WORD => X"0",
        RX_ALIGN_COMMA_ENABLE => X"3FF",
        RX_SLIDE_MODE => X"0",
        RX_COMMA_DETECT_EN_OVR => X"0",
        RX_COMMA_DETECT_EN => X"0",
        --RX_SLIDE[0] => X"0",
        --RX_SLIDE[1] => X"0",
        RX_EYE_MEAS_EN => X"0",
        RX_EYE_MEAS_CFG => X"0",
        RX_MON_PH_OFFSET => X"0",
        RX_EI_BIAS => X"4",
        RX_EI_BW_SEL => X"4",
        RX_EN_EI_DETECTOR_OVR => X"0",
        RX_EN_EI_DETECTOR => X"0",
        RX_DATA_SEL => X"0",
        RX_BUF_BYPASS => X"0",
        RX_CLKCOR_USE => X"0",
        RX_CLKCOR_MIN_LAT => X"20",
        RX_CLKCOR_MAX_LAT => X"27",
        RX_CLKCOR_SEQ_1_0 => X"1F7",
        RX_CLKCOR_SEQ_1_1 => X"1F7",
        RX_CLKCOR_SEQ_1_2 => X"1F7",
        RX_CLKCOR_SEQ_1_3 => X"1F7",
        RX_PMA_LOOPBACK => X"0",
        RX_PCS_LOOPBACK => X"0",
        RX_DATAPATH_SEL => X"3",
        RX_PRBS_OVR => X"0",
        RX_PRBS_SEL => X"0",
        RX_LOOPBACK_OVR => X"0",
        RX_PRBS_CNT_RESET => X"0",
        RX_POWER_DOWN_OVR => X"0",
        RX_POWER_DOWN_N => X"0",
        RX_RESET_OVR => X"0",
        RX_RESET => X"0",
        RX_PMA_RESET_OVR => X"0",
        RX_PMA_RESET => X"0",
        RX_EQA_RESET_OVR => X"0",
        RX_EQA_RESET => X"0",
        RX_CDR_RESET_OVR => X"0",
        RX_CDR_RESET => X"0",
        RX_PCS_RESET_OVR => X"0",
        RX_PCS_RESET => X"0",
        RX_BUF_RESET_OVR => X"0",
        RX_BUF_RESET => X"0",
        RX_POLARITY_OVR => X"0",
        RX_POLARITY => X"0",
        RX_8B10B_EN_OVR => X"0",
        RX_8B10B_EN => X"0",
        RX_8B10B_BYPASS => X"0",
        RX_BYTE_REALIGN => X"0",
        TX_SEL_PRE => X"0",
        TX_SEL_POST => X"0",
        TX_AMP => X"F",
        TX_BRANCH_EN_PRE => X"0",
        TX_BRANCH_EN_MAIN => X"3F",
        TX_BRANCH_EN_POST => X"0",
        TX_TAIL_CASCODE => X"4",
        TX_DC_ENABLE => X"3F",
        TX_DC_OFFSET => X"8",
        TX_CM_RAISE => X"0",
        TX_CM_THRESHOLD_0 => X"E",
        TX_CM_THRESHOLD_1 => X"10",
        TX_SEL_PRE_EI => X"0",
        TX_SEL_POST_EI => X"0",
        TX_AMP_EI => X"F",
        TX_BRANCH_EN_PRE_EI => X"0",
        TX_BRANCH_EN_MAIN_EI => X"3F",
        TX_BRANCH_EN_POST_EI => X"0",
        TX_TAIL_CASCODE_EI => X"4",
        TX_DC_ENABLE_EI => X"3F",
        TX_DC_OFFSET_EI => X"0",
        TX_CM_RAISE_EI => X"0",
        TX_CM_THRESHOLD_0_EI => X"E",
        TX_CM_THRESHOLD_1_EI => X"10",
        TX_SEL_PRE_RXDET => X"0",
        TX_SEL_POST_RXDET => X"0",
        TX_AMP_RXDET => X"F",
        TX_BRANCH_EN_PRE_RXDET => X"0",
        TX_BRANCH_EN_MAIN_RXDET => X"3F",
        TX_BRANCH_EN_POST_RXDET => X"0",
        TX_TAIL_CASCODE_RXDET => X"4",
        TX_DC_ENABLE_RXDET => X"3F",
        TX_DC_OFFSET_RXDET => X"0",
        TX_CM_RAISE_RXDET => X"0",
        TX_CM_THRESHOLD_0_RXDET => X"E",
        TX_CM_THRESHOLD_1_RXDET => X"10",
        TX_CALIB_EN => X"0",
        TX_CALIB_OVR => X"0",
        TX_CALIB_VAL => X"0",
        TX_CM_REG_KI => X"80",
        TX_CM_SAR_EN => X"0",
        TX_CM_REG_EN => X"1",
        TX_PMA_RESET_TIME => X"3",
        TX_PCS_RESET_TIME => X"3",
        TX_PCS_RESET_OVR => X"0",
        TX_PCS_RESET => X"0",
        TX_PMA_RESET_OVR => X"0",
        TX_PMA_RESET => X"0",
        TX_RESET_OVR => X"0",
        TX_RESET => X"0",
        TX_PMA_LOOPBACK => X"0",
        TX_PCS_LOOPBACK => X"0",
        TX_DATAPATH_SEL => X"3",
        TX_PRBS_OVR => X"0",
        TX_PRBS_SEL => X"0",
        TX_PRBS_FORCE_ERR => X"0",
        TX_LOOPBACK_OVR => X"0",
        TX_POWER_DOWN_OVR => X"0",
        TX_POWER_DOWN_N => X"0",
        TX_ELEC_IDLE_OVR => X"0",
        TX_ELEC_IDLE => X"0",
        TX_DETECT_RX_OVR => X"0",
        TX_DETECT_RX => X"0",
        TX_POLARITY_OVR => X"0",
        TX_POLARITY => X"0",
        TX_8B10B_EN_OVR => X"0",
        TX_8B10B_EN => X"0",
        TX_DATA_OVR => X"0",
        TX_DATA_CNT => X"0",
        TX_DATA_VALID => X"0",
        PLL_EN_ADPLL_CTRL => X"0",
        PLL_CONFIG_SEL => X"1",
        PLL_SET_OP_LOCK => X"0",
        PLL_ENFORCE_LOCK => X"0",
        PLL_DISABLE_LOCK => X"0",
        PLL_LOCK_WINDOW => X"1",
        PLL_FAST_LOCK => X"1",
        PLL_SYNC_BYPASS => X"0",
        PLL_PFD_SELECT => X"0",
        PLL_REF_BYPASS => X"0",
        PLL_REF_SEL => X"1",
        PLL_REF_RTERM => X"1",
        PLL_FCNTRL => X"3A",
        PLL_MAIN_DIVSEL => X"1B",
        PLL_OUT_DIVSEL => X"0",
        PLL_CI => X"3",
        PLL_CP => X"50",
        PLL_AO => X"0",
        PLL_SCAP => X"0",
        PLL_FILTER_SHIFT => X"2",
        PLL_SAR_LIMIT => X"2",
        PLL_FT => X"200",
        PLL_OPEN_LOOP => X"0",
        PLL_SCAP_AUTO_CAL => X"1",
        PLL_BISC_MODE => X"4",
        PLL_BISC_TIMER_MAX => X"F",
        PLL_BISC_OPT_DET_IND => X"0",
        PLL_BISC_PFD_SEL => X"0",
        PLL_BISC_DLY_DIR => X"0",
        PLL_BISC_COR_DLY => X"1",
        PLL_BISC_CAL_SIGN => X"0",
        PLL_BISC_CAL_AUTO => X"1",
        PLL_BISC_CP_MIN => X"4",
        PLL_BISC_CP_MAX => X"12",
        PLL_BISC_CP_START => X"C",
        PLL_BISC_DLY_PFD_MON_REF => X"0",
        PLL_BISC_DLY_PFD_MON_DIV => X"2",
        SERDES_ENABLE => X"1",
        SERDES_AUTO_INIT => X"0",
        SERDES_TESTMODE => X"0"
    )
    port map (
        TX_DATA_I => tx_data,
        TX_RESET_I => trx_rst_i,
        TX_PCS_RESET_I => '0',
        TX_PMA_RESET_I => '0',
        PLL_RESET_I => pll_rst_i,
        TX_POWER_DOWN_N_I => '0',
        TX_POLARITY_I => '0',
        TX_PRBS_SEL_I => (others => '0'),
        TX_PRBS_FORCE_ERR_I => '0',
        TX_8B10B_EN_I => '0',
        TX_8B10B_BYPASS_I => (others => '0'),
        TX_CHAR_IS_K_I => (others => '0'),
        TX_CHAR_DISPMODE_I => (others => '0'),
        TX_CHAR_DISPVAL_I => (others => '0'),
        TX_ELEC_IDLE_I => '0',
        TX_DETECT_RX_I => '1',
        LOOPBACK_I => (others => '0'),
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
        RX_8B10B_EN_I => '0',
        RX_8B10B_BYPASS_I => (others => '0'),
        RX_EN_EI_DETECTOR_I => '0',
        RX_COMMA_DETECT_EN_I => '0',
        RX_SLIDE_I => '0',
        RX_MCOMMA_ALIGN_I => '0',
        RX_PCOMMA_ALIGN_I => '0',
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
