#!/usr/bin/env python3
#
#  serdestool -- GateMate FPGA SerDes Toolkit
#
#  Permission to use, copy, modify, and/or distribute this software for any
#  purpose with or without fee is hereby granted, provided that the above
#  copyright notice and this permission notice appear in all copies.
#
#  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
#  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
#  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
#  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
#  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
#  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
#  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#
#  Visit https://colognechip.com for more information.
#
#  Copyright (C) 2022, 2023, 2024 Cologne Chip AG <support@colognechip.com>
#  Authors: Patrick Urban
#

import re
import sys
import argparse
import datetime

from time import sleep

from pyftdi.ftdi import Ftdi
from pyftdi.jtag import JtagEngine
from pyftdi.usbtools import UsbTools
from pyftdi.bits import BitSequence

Boards_e = ['auto', 'pgm', 'evb']
ArgEpilog = 'example usage: python3 serdestool.py'

class bcolors:
    OK    = '\033[92m' # GREEN
    WARN  = '\033[93m' # YELLOW
    FAIL  = '\033[91m' # RED
    DATA  = '\033[94m' # DATA
    RESET = '\033[0m'  # RESET COLOR

def ArgHzRegex(value, pat=re.compile(r"^[0-9]+[kM]")):
    if not pat.match(value):
        raise argparse.ArgumentTypeError
    return value

def ArgHzParse(value) -> int:
    freq = 0
    if value.endswith('k'):
        freq = int(value[:-1]) * 1e3
    elif value.endswith('M'):
        freq = int(value[:-1]) * 1e6
    else:
        freq = int(value)
    return freq

def FindAndFormatFtdiAddr(idx=0) -> str:
    ftdiname = {
        0x6010: '2232h',
        0x6014: '232h'
    }
    usb = UsbTools()
    vps_lst = list()
    vps_lst.append((0x0403, 0x6010)) # evb: FT2232H
    vps_lst.append((0x0403, 0x6014)) # pgm: FT232H
    d = usb.find_all(vps=vps_lst)
    if not d:
        raise Exception('Error: No FTDI device found.')
    d = d[idx][0]
    return f'ftdi://ftdi:{ftdiname[d[1]]}/1'

class JtagTool:
    CMD_JTAG_ID                = '000000' # 0x00
    CMD_JTAG_BYPASS            = '111111' # 0x3F
    CMD_JTAG_CONFIGURE         = '000110' # 0x06
    CMD_JTAG_WR_SERDES_REGFILE = '100101' # 0x25
    CMD_JTAG_RD_SERDES_REGFILE = '100110' # 0x26

    chain_idx = 0
    taps_before = 0

    def __init__(self, engine):
        self._engine = engine

    def write_ir(self, instruction) -> None:
        byp_before = BitSequence('1'*6*self.taps_before, msb=True)
        byp_after = BitSequence('1'*6*self.chain_idx, msb=True)
        self._engine.write_ir(byp_before+instruction+byp_after)

    def write_dr(self, data) -> None:
        byp_before = BitSequence('0'*self.taps_before, msb=True)
        byp_after = BitSequence('0'*self.chain_idx, msb=True)
        self._engine.write_dr(byp_after+data+byp_before)

    def read_dr(self, length: int) -> BitSequence:
        word = self._engine.read_dr(length+self.taps_before)
        if self.chain_idx > 0:
            return word[self.taps_before:-self.chain_idx]
        else:
            return word[self.taps_before:]

    def get_chunk(self, data, start, length):
        return (data >> start) & ((1 << length) - 1)

    # Read the IDCODE right after JTAG reset
    def idcode(self) -> int:
        idcodes = self._engine.read_dr(128)
        self._engine.go_idle()
        chain_len = 0
        for i in range(0, 128, 32):
            chunk_data = self.get_chunk(int(idcodes), i, 32)
            if chunk_data != 0:
                chain_len += 1
        print(f'Found {chain_len} device{"s" if chain_len > 1 else ""} in JTAG chain.')
        self.taps_before = chain_len - self.chain_idx - 1
        return chain_len

    # Read the IDCODE using CMD_JTAG_ID
    def idcode_seq(self) -> int:
        self.write_ir(BitSequence(self.CMD_JTAG_ID, msb=True))
        status = self.read_dr(32)
        self._engine.go_idle()
        return int(status)

    # Configure FPGA using CMD_JTAG_CONFIGURE
    def wr_cfg(self, cfg_data) -> None:
        a = []
        b = bytearray(cfg_data)

        for i in range(len(b)):
            a.append(int(b[i]))

        seq = BitSequence(bytes_=a[:-1], msb=False, msby=True)

        self.write_ir(BitSequence(self.CMD_JTAG_CONFIGURE, msb=True))
        self.write_dr(seq)
        self._engine.go_idle()

    def wr_serdes_regfile(self, addr, data, mask, wren):
        self.write_ir(BitSequence(self.CMD_JTAG_WR_SERDES_REGFILE, msb=True))
        cmd  = BitSequence(value=addr, length=8,  msb=False, msby=True)
        cmd += BitSequence(value=data, length=16, msb=False, msby=True)
        cmd += BitSequence(value=mask, length=16, msb=False, msby=True)
        cmd += BitSequence(value=wren, length=1, msb=False, msby=True)
        self.write_dr(cmd)
        self._engine.go_idle()

    def rd_serdes_regfile(self):
        self.write_ir(BitSequence(self.CMD_JTAG_RD_SERDES_REGFILE, msb=True))
        word = self.read_dr(16)
        self._engine.go_idle()
        return word

class SerdesRegfile:
    def __init__(self, initial_fields):
        self.fields = initial_fields

class SerdesTool:
    regfile = SerdesRegfile({
        'RX_BUF_RESET_TIME':        {'addr': 0x00, 'mode': 'R/W', 'hbit':  4, 'lbit':  0, 'val': 3},
        'RX_PCS_RESET_TIME':        {'addr': 0x00, 'mode': 'R/W', 'hbit':  9, 'lbit':  5, 'val': 3},
        'RX_RESET_TIMER_PRESC':     {'addr': 0x00, 'mode': 'R/W', 'hbit': 14, 'lbit': 10, 'val': 0},
        'RX_RESET_DONE_GATE':       {'addr': 0x00, 'mode': 'R/W', 'hbit': 15, 'lbit': 15, 'val': 0},
        'RX_CDR_RESET_TIME':        {'addr': 0x01, 'mode': 'R/W', 'hbit':  4, 'lbit':  0, 'val': 3},
        'RX_EQA_RESET_TIME':        {'addr': 0x01, 'mode': 'R/W', 'hbit':  9, 'lbit':  5, 'val': 3},
        'RX_PMA_RESET_TIME':        {'addr': 0x01, 'mode': 'R/W', 'hbit': 14, 'lbit': 10, 'val': 3},
        'RX_WAIT_CDR_LOCK':         {'addr': 0x01, 'mode': 'R/W', 'hbit': 15, 'lbit': 15, 'val': 0},
        'RX_CALIB_EN':              {'addr': 0x02, 'mode': 'W/C', 'hbit':  0, 'lbit':  0, 'val': 0},
        'RX_CALIB_DONE':            {'addr': 0x02, 'mode': 'R',   'hbit':  1, 'lbit':  1, 'val': 1},
        'RX_CALIB_OVR':             {'addr': 0x02, 'mode': 'R/W', 'hbit':  2, 'lbit':  2, 'val': 0},
        'RX_CALIB_VAL':             {'addr': 0x02, 'mode': 'R/W', 'hbit':  6, 'lbit':  3, 'val': 0},
        'RX_CALIB_CAL':             {'addr': 0x02, 'mode': 'R',   'hbit': 10, 'lbit':  7, 'val': 0},
        'RX_RTERM_VCMSEL':          {'addr': 0x02, 'mode': 'R/W', 'hbit': 13, 'lbit': 11, 'val': 4},
        'RX_RTERM_PD':              {'addr': 0x02, 'mode': 'R/W', 'hbit': 14, 'lbit': 14, 'val': 0},
        'RX_EQA_CKP_LF':            {'addr': 0x03, 'mode': 'R/W', 'hbit':  7, 'lbit':  0, 'val': 0xA3},
        'RX_EQA_CKP_HF':            {'addr': 0x03, 'mode': 'R/W', 'hbit': 15, 'lbit':  8, 'val': 0xA3},
        'RX_EQA_CKP_OFFSET':        {'addr': 0x04, 'mode': 'R/W', 'hbit':  7, 'lbit':  0, 'val': 1},
        'RX_EN_EQA':                {'addr': 0x04, 'mode': 'R/W', 'hbit':  8, 'lbit':  8, 'val': 0},
        'RX_EQA_LOCK_CFG':          {'addr': 0x04, 'mode': 'R/W', 'hbit': 12, 'lbit':  9, 'val': 0},
        'RX_EQA_LOCKED':            {'addr': 0x04, 'mode': 'R',   'hbit': 13, 'lbit': 13, 'val': 0},
        'RX_TH_MON1':               {'addr': 0x05, 'mode': 'R/W', 'hbit':  4, 'lbit':  0, 'val': 8},
        'RX_EN_EQA_EXT_VALUE[0]':   {'addr': 0x05, 'mode': 'R/W', 'hbit':  5, 'lbit':  5, 'val': 0},
        'RX_TH_MON2':               {'addr': 0x05, 'mode': 'R/W', 'hbit': 10, 'lbit':  6, 'val': 8},
        'RX_EN_EQA_EXT_VALUE[1]':   {'addr': 0x05, 'mode': 'R/W', 'hbit': 11, 'lbit': 11, 'val': 0},
        'RX_TAPW':                  {'addr': 0x06, 'mode': 'R/W', 'hbit':  4, 'lbit':  0, 'val': 8},
        'RX_EN_EQA_EXT_VALUE[2]':   {'addr': 0x06, 'mode': 'R/W', 'hbit':  5, 'lbit':  5, 'val': 0},
        'RX_AFE_OFFSET':            {'addr': 0x06, 'mode': 'R/W', 'hbit': 10, 'lbit':  6, 'val': 8},
        'RX_EN_EQA_EXT_VALUE[3]':   {'addr': 0x06, 'mode': 'R/W', 'hbit': 11, 'lbit': 11, 'val': 0},
        'RX_EQA_TAPW':              {'addr': 0x07, 'mode': 'R',   'hbit':  4, 'lbit':  0, 'val': 0},
        'RX_TH_MON':                {'addr': 0x07, 'mode': 'R',   'hbit':  9, 'lbit':  5, 'val': 0},
        'RX_OFFSET':                {'addr': 0x07, 'mode': 'R',   'hbit': 13, 'lbit': 10, 'val': 0},
        'RX_EQA_CONFIG':            {'addr': 0x08, 'mode': 'R/W', 'hbit': 15, 'lbit':  0, 'val': 0x01C0},
        'RX_AFE_PEAK':              {'addr': 0x09, 'mode': 'R/W', 'hbit':  4, 'lbit':  0, 'val': 15},
        'RX_AFE_GAIN':              {'addr': 0x09, 'mode': 'R/W', 'hbit':  8, 'lbit':  5, 'val': 8},
        'RX_AFE_VCMSEL':            {'addr': 0x09, 'mode': 'R/W', 'hbit': 11, 'lbit':  9, 'val': 4},
        'RX_CDR_CKP':               {'addr': 0x0A, 'mode': 'R/W', 'hbit':  7, 'lbit':  0, 'val': 0xF8},
        'RX_CDR_CKI':               {'addr': 0x0A, 'mode': 'R/W', 'hbit': 15, 'lbit':  8, 'val': 0},
        'RX_CDR_TRANS_TH':          {'addr': 0x0B, 'mode': 'R/W', 'hbit':  8, 'lbit':  0, 'val': 128},
        'RX_CDR_LOCK_CFG':          {'addr': 0x0B, 'mode': 'R/W', 'hbit': 14, 'lbit':  9, 'val': 0x0B},
        'RX_CDR_LOCKED':            {'addr': 0x0B, 'mode': 'R',   'hbit': 15, 'lbit': 15, 'val': 0},
        'RX_CDR_FREQ_ACC_VAL':      {'addr': 0x0C, 'mode': 'R',   'hbit': 14, 'lbit':  0, 'val': 0},
        'RX_CDR_PHASE_ACC_VAL':     {'addr': 0x0D, 'mode': 'R',   'hbit': 15, 'lbit':  0, 'val': 0},
        'RX_CDR_FREQ_ACC':          {'addr': 0x0E, 'mode': 'R/W', 'hbit': 14, 'lbit':  0, 'val': 0},
        'RX_CDR_PHASE_ACC':         {'addr': 0x0F, 'mode': 'R/W', 'hbit': 15, 'lbit':  0, 'val': 0},
        'RX_CDR_SET_ACC_CONFIG':    {'addr': 0x10, 'mode': 'R/W', 'hbit':  1, 'lbit':  0, 'val': 0},
        'RX_CDR_FORCE_LOCK':        {'addr': 0x10, 'mode': 'R/W', 'hbit':  2, 'lbit':  2, 'val': 0},
        'RX_ALIGN_MCOMMA_VALUE':    {'addr': 0x11, 'mode': 'R/W', 'hbit':  9, 'lbit':  0, 'val': 0x283},
        'RX_MCOMMA_ALIGN_OVR':      {'addr': 0x11, 'mode': 'R/W', 'hbit': 10, 'lbit': 10, 'val': 0},
        'RX_MCOMMA_ALIGN':          {'addr': 0x11, 'mode': 'R/W', 'hbit': 11, 'lbit': 11, 'val': 0},
        'RX_ALIGN_PCOMMA_VALUE':    {'addr': 0x12, 'mode': 'R/W', 'hbit':  9, 'lbit':  0, 'val': 0x17C},
        'RX_PCOMMA_ALIGN_OVR':      {'addr': 0x12, 'mode': 'R/W', 'hbit': 10, 'lbit': 10, 'val': 0},
        'RX_PCOMMA_ALIGN':          {'addr': 0x12, 'mode': 'R/W', 'hbit': 11, 'lbit': 11, 'val': 0},
        'RX_ALIGN_COMMA_WORD':      {'addr': 0x12, 'mode': 'R/W', 'hbit': 13, 'lbit': 12, 'val': 0},
        'RX_ALIGN_COMMA_ENABLE':    {'addr': 0x13, 'mode': 'R/W', 'hbit':  9, 'lbit':  0, 'val': 0x3FF},
        'RX_SLIDE_MODE':            {'addr': 0x13, 'mode': 'R/W', 'hbit': 11, 'lbit': 10, 'val': 0},
        'RX_COMMA_DETECT_EN_OVR':   {'addr': 0x13, 'mode': 'R/W', 'hbit': 12, 'lbit': 12, 'val': 0},
        'RX_COMMA_DETECT_EN':       {'addr': 0x13, 'mode': 'R/W', 'hbit': 13, 'lbit': 13, 'val': 0},
        'RX_SLIDE[0]':              {'addr': 0x13, 'mode': 'R/W', 'hbit': 14, 'lbit': 14, 'val': 0},
        'RX_SLIDE[1]':              {'addr': 0x13, 'mode': 'W/C', 'hbit': 15, 'lbit': 15, 'val': 0},
        'RX_EYE_MEAS_EN':           {'addr': 0x14, 'mode': 'W/C', 'hbit':  0, 'lbit':  0, 'val': 0},
        'RX_EYE_MEAS_CFG':          {'addr': 0x14, 'mode': 'R/W', 'hbit': 15, 'lbit':  1, 'val': 0},
        'RX_MON_PH_OFFSET':         {'addr': 0x15, 'mode': 'R/W', 'hbit':  5, 'lbit':  0, 'val': 0},
        'RX_EYE_MEAS_CORRECT_11S':  {'addr': 0x16, 'mode': 'R',   'hbit': 15, 'lbit':  0, 'val': 0},
        'RX_EYE_MEAS_WRONG_11S':    {'addr': 0x17, 'mode': 'R',   'hbit': 15, 'lbit':  0, 'val': 0},
        'RX_EYE_MEAS_CORRECT_00S':  {'addr': 0x18, 'mode': 'R',   'hbit': 15, 'lbit':  0, 'val': 0},
        'RX_EYE_MEAS_WRONG_00S':    {'addr': 0x19, 'mode': 'R',   'hbit': 15, 'lbit':  0, 'val': 0},
        'RX_EYE_MEAS_CORRECT_001S': {'addr': 0x1A, 'mode': 'R',   'hbit': 15, 'lbit':  0, 'val': 0},
        'RX_EYE_MEAS_WRONG_001S':   {'addr': 0x1B, 'mode': 'R',   'hbit': 15, 'lbit':  0, 'val': 0},
        'RX_EYE_MEAS_CORRECT_110S': {'addr': 0x1C, 'mode': 'R',   'hbit': 15, 'lbit':  0, 'val': 0},
        'RX_EYE_MEAS_WRONG_110S':   {'addr': 0x1D, 'mode': 'R',   'hbit': 15, 'lbit':  0, 'val': 0},
        'RX_EI_BIAS':               {'addr': 0x1E, 'mode': 'R/W', 'hbit':  3, 'lbit':  0, 'val': 4},
        'RX_EI_BW_SEL':             {'addr': 0x1E, 'mode': 'R/W', 'hbit':  7, 'lbit':  4, 'val': 4},
        'RX_EN_EI_DETECTOR_OVR':    {'addr': 0x1E, 'mode': 'R/W', 'hbit':  8, 'lbit':  8, 'val': 0},
        'RX_EN_EI_DETECTOR':        {'addr': 0x1E, 'mode': 'R/W', 'hbit':  9, 'lbit':  9, 'val': 0},
        'RX_EI_EN':                 {'addr': 0x1E, 'mode': 'R',   'hbit': 10, 'lbit': 10, 'val': 0},
        'RX_PRBS_ERR_CNT':          {'addr': 0x1F, 'mode': 'R',   'hbit': 14, 'lbit':  0, 'val': 0},
        'RX_PRBS_LOCKED':           {'addr': 0x1F, 'mode': 'R',   'hbit': 15, 'lbit': 15, 'val': 0},
        'RX_DATA_SEL':              {'addr': 0x20, 'mode': 'R/W', 'hbit':  0, 'lbit':  0, 'val': 0},
        'RX_DATA[15:0]':            {'addr': 0x20, 'mode': 'R',   'hbit': 15, 'lbit':  0, 'val': 0},
        'RX_DATA[31:16]':           {'addr': 0x21, 'mode': 'R',   'hbit': 15, 'lbit':  0, 'val': 0},
        'RX_DATA[47:32]':           {'addr': 0x22, 'mode': 'R',   'hbit': 15, 'lbit':  0, 'val': 0},
        'RX_DATA[63:48]':           {'addr': 0x23, 'mode': 'R',   'hbit': 15, 'lbit':  0, 'val': 0},
        'RX_DATA[79:64]':           {'addr': 0x24, 'mode': 'R',   'hbit': 15, 'lbit':  0, 'val': 0},
        'RX_BUF_BYPASS':            {'addr': 0x25, 'mode': 'R/W', 'hbit':  0, 'lbit':  0, 'val': 0},
        'RX_CLKCOR_USE':            {'addr': 0x25, 'mode': 'R/W', 'hbit':  1, 'lbit':  1, 'val': 0},
        'RX_CLKCOR_MIN_LAT':        {'addr': 0x25, 'mode': 'R/W', 'hbit':  7, 'lbit':  2, 'val': 32},
        'RX_CLKCOR_MAX_LAT':        {'addr': 0x25, 'mode': 'R/W', 'hbit': 13, 'lbit':  8, 'val': 39},
        'RX_CLKCOR_SEQ_1_0':        {'addr': 0x26, 'mode': 'R/W', 'hbit':  9, 'lbit':  0, 'val': 0x1F7},
        'RX_CLKCOR_SEQ_1_1':        {'addr': 0x27, 'mode': 'R/W', 'hbit':  9, 'lbit':  0, 'val': 0x1F7},
        'RX_CLKCOR_SEQ_1_2':        {'addr': 0x28, 'mode': 'R/W', 'hbit':  9, 'lbit':  0, 'val': 0x1F7},
        'RX_CLKCOR_SEQ_1_3':        {'addr': 0x29, 'mode': 'R/W', 'hbit':  9, 'lbit':  0, 'val': 0x1F7},
        'RX_PMA_LOOPBACK':          {'addr': 0x2A, 'mode': 'R/W', 'hbit':  0, 'lbit':  0, 'val': 0},
        'RX_PCS_LOOPBACK':          {'addr': 0x2A, 'mode': 'R/W', 'hbit':  1, 'lbit':  1, 'val': 0},
        'RX_DATAPATH_SEL':          {'addr': 0x2A, 'mode': 'R/W', 'hbit':  3, 'lbit':  2, 'val': 3},
        'RX_PRBS_OVR':              {'addr': 0x2A, 'mode': 'R/W', 'hbit':  4, 'lbit':  4, 'val': 0},
        'RX_PRBS_SEL':              {'addr': 0x2A, 'mode': 'R/W', 'hbit':  7, 'lbit':  5, 'val': 0},
        'RX_LOOPBACK_OVR':          {'addr': 0x2A, 'mode': 'R/W', 'hbit':  8, 'lbit':  8, 'val': 0},
        'RX_PRBS_CNT_RESET':        {'addr': 0x2A, 'mode': 'W/C', 'hbit':  9, 'lbit':  9, 'val': 0},
        'RX_POWER_DOWN_OVR':        {'addr': 0x2A, 'mode': 'R/W', 'hbit': 10, 'lbit': 10, 'val': 0},
        'RX_POWER_DOWN_N':          {'addr': 0x2A, 'mode': 'R/W', 'hbit': 11, 'lbit': 11, 'val': 0},
        'RX_PRESENT':               {'addr': 0x2A, 'mode': 'R',   'hbit': 12, 'lbit': 12, 'val': 0},
        'RX_DETECT_DONE':           {'addr': 0x2A, 'mode': 'R',   'hbit': 13, 'lbit': 13, 'val': 0},
        'RX_BUF_ERR':               {'addr': 0x2A, 'mode': 'R',   'hbit': 14, 'lbit': 14, 'val': 0},
        'RX_RESET_OVR':             {'addr': 0x2B, 'mode': 'R/W', 'hbit':  0, 'lbit':  0, 'val': 0},
        'RX_RESET':                 {'addr': 0x2B, 'mode': 'W/C', 'hbit':  1, 'lbit':  1, 'val': 0},
        'RX_PMA_RESET_OVR':         {'addr': 0x2B, 'mode': 'R/W', 'hbit':  2, 'lbit':  2, 'val': 0},
        'RX_PMA_RESET':             {'addr': 0x2B, 'mode': 'W/C', 'hbit':  3, 'lbit':  3, 'val': 0},
        'RX_EQA_RESET_OVR':         {'addr': 0x2B, 'mode': 'R/W', 'hbit':  4, 'lbit':  4, 'val': 0},
        'RX_EQA_RESET':             {'addr': 0x2B, 'mode': 'W/C', 'hbit':  5, 'lbit':  5, 'val': 0},
        'RX_CDR_RESET_OVR':         {'addr': 0x2B, 'mode': 'R/W', 'hbit':  6, 'lbit':  6, 'val': 0},
        'RX_CDR_RESET':             {'addr': 0x2B, 'mode': 'W/C', 'hbit':  7, 'lbit':  7, 'val': 0},
        'RX_PCS_RESET_OVR':         {'addr': 0x2B, 'mode': 'R/W', 'hbit':  8, 'lbit':  8, 'val': 0},
        'RX_PCS_RESET':             {'addr': 0x2B, 'mode': 'W/C', 'hbit':  9, 'lbit':  9, 'val': 0},
        'RX_BUF_RESET_OVR':         {'addr': 0x2B, 'mode': 'R/W', 'hbit': 10, 'lbit': 10, 'val': 0},
        'RX_BUF_RESET':             {'addr': 0x2B, 'mode': 'W/C', 'hbit': 11, 'lbit': 11, 'val': 0},
        'RX_POLARITY_OVR':          {'addr': 0x2B, 'mode': 'R/W', 'hbit': 12, 'lbit': 12, 'val': 0},
        'RX_POLARITY':              {'addr': 0x2B, 'mode': 'R/W', 'hbit': 13, 'lbit': 13, 'val': 0},
        'RX_8B10B_EN_OVR':          {'addr': 0x2B, 'mode': 'R/W', 'hbit': 14, 'lbit': 14, 'val': 0},
        'RX_8B10B_EN':              {'addr': 0x2B, 'mode': 'R/W', 'hbit': 15, 'lbit': 15, 'val': 0},
        'RX_8B10B_BYPASS':          {'addr': 0x2C, 'mode': 'R/W', 'hbit':  7, 'lbit':  0, 'val': 0},
        'RX_BYTE_IS_ALIGNED':       {'addr': 0x2C, 'mode': 'R',   'hbit':  8, 'lbit':  8, 'val': 0},
        'RX_BYTE_REALIGN':          {'addr': 0x2C, 'mode': 'R/C', 'hbit':  9, 'lbit':  9, 'val': 0},
        'RX_RESET_DONE':            {'addr': 0x2C, 'mode': 'R',   'hbit': 10, 'lbit': 10, 'val': 0},
        #'RX_DBG_EN':               {'addr': 0x2D, 'mode': 'W/C', 'hbit':  0, 'lbit':  0, 'val': 0},
        #'RX_DBG_SEL':              {'addr': 0x2D, 'mode': 'R/W', 'hbit':  4, 'lbit':  1, 'val': 0},
        #'RX_DBG_MODE':             {'addr': 0x2D, 'mode': 'R/W', 'hbit':  5, 'lbit':  5, 'val': 0},
        #'RX_DBG_SRAM_DELAY':       {'addr': 0x2D, 'mode': 'R/W', 'hbit': 11, 'lbit':  6, 'val': 5},
        #'RX_DBG_ADDR':             {'addr': 0x2E, 'mode': 'R/W', 'hbit':  9, 'lbit':  0, 'val': 0},
        #'RX_DBG_RE':               {'addr': 0x2E, 'mode': 'W/C', 'hbit': 10, 'lbit': 10, 'val': 0},
        #'RX_DBG_WE':               {'addr': 0x2E, 'mode': 'W/C', 'hbit': 11, 'lbit': 11, 'val': 0},
        #'RX_DBG_DATA[3:0]':        {'addr': 0x2E, 'mode': 'R/W', 'hbit': 15, 'lbit': 12, 'val': 0},
        #'RX_DBG_DATA[19:4]':       {'addr': 0x2F, 'mode': 'R/W', 'hbit': 15, 'lbit':  0, 'val': 0},
        'TX_SEL_PRE':               {'addr': 0x30, 'mode': 'R/W', 'hbit':  4, 'lbit':  0, 'val': 0},
        'TX_SEL_POST':              {'addr': 0x30, 'mode': 'R/W', 'hbit':  9, 'lbit':  5, 'val': 0},
        'TX_AMP':                   {'addr': 0x30, 'mode': 'R/W', 'hbit': 14, 'lbit': 10, 'val': 15},
        'TX_BRANCH_EN_PRE':         {'addr': 0x31, 'mode': 'R/W', 'hbit':  4, 'lbit':  0, 'val': 0},
        'TX_BRANCH_EN_MAIN':        {'addr': 0x31, 'mode': 'R/W', 'hbit': 10, 'lbit':  5, 'val': 0x3F},
        'TX_BRANCH_EN_POST':        {'addr': 0x31, 'mode': 'R/W', 'hbit': 15, 'lbit': 11, 'val': 0},
        'TX_TAIL_CASCODE':          {'addr': 0x32, 'mode': 'R/W', 'hbit':  2, 'lbit':  0, 'val': 4},
        'TX_DC_ENABLE':             {'addr': 0x32, 'mode': 'R/W', 'hbit':  9, 'lbit':  3, 'val': 63},
        'TX_DC_OFFSET':             {'addr': 0x32, 'mode': 'R/W', 'hbit': 14, 'lbit': 10, 'val': 8},
        'TX_CM_RAISE':              {'addr': 0x33, 'mode': 'R/W', 'hbit':  4, 'lbit':  0, 'val': 0},
        'TX_CM_THRESHOLD_0':        {'addr': 0x33, 'mode': 'R/W', 'hbit':  9, 'lbit':  5, 'val': 14},
        'TX_CM_THRESHOLD_1':        {'addr': 0x33, 'mode': 'R/W', 'hbit': 14, 'lbit': 10, 'val': 16},
        'TX_SEL_PRE_EI':            {'addr': 0x34, 'mode': 'R/W', 'hbit':  4, 'lbit':  0, 'val': 0},
        'TX_SEL_POST_EI':           {'addr': 0x34, 'mode': 'R/W', 'hbit':  9, 'lbit':  5, 'val': 0},
        'TX_AMP_EI':                {'addr': 0x34, 'mode': 'R/W', 'hbit': 14, 'lbit': 10, 'val': 15},
        'TX_BRANCH_EN_PRE_EI':      {'addr': 0x35, 'mode': 'R/W', 'hbit':  4, 'lbit':  0, 'val': 0},
        'TX_BRANCH_EN_MAIN_EI':     {'addr': 0x35, 'mode': 'R/W', 'hbit': 10, 'lbit':  5, 'val': 0x3F},
        'TX_BRANCH_EN_POST_EI':     {'addr': 0x35, 'mode': 'R/W', 'hbit': 15, 'lbit': 11, 'val': 0},
        'TX_TAIL_CASCODE_EI':       {'addr': 0x36, 'mode': 'R/W', 'hbit':  2, 'lbit':  0, 'val': 4},
        'TX_DC_ENABLE_EI':          {'addr': 0x36, 'mode': 'R/W', 'hbit':  9, 'lbit':  3, 'val': 63},
        'TX_DC_OFFSET_EI':          {'addr': 0x36, 'mode': 'R/W', 'hbit': 14, 'lbit': 10, 'val': 0},
        'TX_CM_RAISE_EI':           {'addr': 0x37, 'mode': 'R/W', 'hbit':  4, 'lbit':  0, 'val': 0},
        'TX_CM_THRESHOLD_0_EI':     {'addr': 0x37, 'mode': 'R/W', 'hbit':  9, 'lbit':  5, 'val': 14},
        'TX_CM_THRESHOLD_1_EI':     {'addr': 0x37, 'mode': 'R/W', 'hbit': 14, 'lbit': 10, 'val': 16},
        'TX_SEL_PRE_RXDET':         {'addr': 0x38, 'mode': 'R/W', 'hbit':  4, 'lbit':  0, 'val': 0},
        'TX_SEL_POST_RXDET':        {'addr': 0x38, 'mode': 'R/W', 'hbit':  9, 'lbit':  5, 'val': 0},
        'TX_AMP_RXDET':             {'addr': 0x38, 'mode': 'R/W', 'hbit': 14, 'lbit': 10, 'val': 15},
        'TX_BRANCH_EN_PRE_RXDET':   {'addr': 0x39, 'mode': 'R/W', 'hbit':  4, 'lbit':  0, 'val': 0},
        'TX_BRANCH_EN_MAIN_RXDET':  {'addr': 0x39, 'mode': 'R/W', 'hbit': 10, 'lbit':  5, 'val': 0x3F},
        'TX_BRANCH_EN_POST_RXDET':  {'addr': 0x39, 'mode': 'R/W', 'hbit': 15, 'lbit': 11, 'val': 0},
        'TX_TAIL_CASCODE_RXDET':    {'addr': 0x3A, 'mode': 'R/W', 'hbit':  2, 'lbit':  0, 'val': 4},
        'TX_DC_ENABLE_RXDET':       {'addr': 0x3A, 'mode': 'R/W', 'hbit':  9, 'lbit':  3, 'val': 63},
        'TX_DC_OFFSET_RXDET':       {'addr': 0x3A, 'mode': 'R/W', 'hbit': 14, 'lbit': 10, 'val': 0},
        'TX_CM_RAISE_RXDET':        {'addr': 0x3B, 'mode': 'R/W', 'hbit':  4, 'lbit':  0, 'val': 0},
        'TX_CM_THRESHOLD_0_RXDET':  {'addr': 0x3B, 'mode': 'R/W', 'hbit':  9, 'lbit':  5, 'val': 14},
        'TX_CM_THRESHOLD_1_RXDET':  {'addr': 0x3B, 'mode': 'R/W', 'hbit': 14, 'lbit': 10, 'val': 16},
        'TX_CALIB_EN':              {'addr': 0x3C, 'mode': 'W/C', 'hbit':  0, 'lbit':  0, 'val': 0},
        'TX_CALIB_DONE':            {'addr': 0x3C, 'mode': 'R',   'hbit':  1, 'lbit':  1, 'val': 1},
        'TX_CALIB_OVR':             {'addr': 0x3C, 'mode': 'R/W', 'hbit':  2, 'lbit':  2, 'val': 0},
        'TX_CALIB_VAL':             {'addr': 0x3C, 'mode': 'R/W', 'hbit':  6, 'lbit':  3, 'val': 0},
        'TX_CALIB_CAL':             {'addr': 0x3C, 'mode': 'R',   'hbit': 10, 'lbit':  7, 'val': 0},
        'TX_CM_REG_KI':             {'addr': 0x3D, 'mode': 'R/W', 'hbit':  7, 'lbit':  0, 'val': 0x80},
        'TX_CM_SAR_EN':             {'addr': 0x3D, 'mode': 'R/W', 'hbit':  8, 'lbit':  8, 'val': 0},
        'TX_CM_REG_EN':             {'addr': 0x3D, 'mode': 'R/W', 'hbit':  9, 'lbit':  9, 'val': 1},
        'TX_CM_SAR_RESULT_0':       {'addr': 0x3E, 'mode': 'R',   'hbit':  4, 'lbit':  0, 'val': 0},
        'TX_CM_SAR_RESULT_1':       {'addr': 0x3E, 'mode': 'R',   'hbit':  9, 'lbit':  5, 'val': 0},
        'TX_PMA_RESET_TIME':        {'addr': 0x3F, 'mode': 'R/W', 'hbit':  4, 'lbit':  0, 'val': 3},
        'TX_PCS_RESET_TIME':        {'addr': 0x3F, 'mode': 'R/W', 'hbit':  9, 'lbit':  5, 'val': 3},
        'TX_PCS_RESET_OVR':         {'addr': 0x3F, 'mode': 'R/W', 'hbit': 10, 'lbit': 10, 'val': 0},
        'TX_PCS_RESET':             {'addr': 0x3F, 'mode': 'W/C', 'hbit': 11, 'lbit': 11, 'val': 0},
        'TX_PMA_RESET_OVR':         {'addr': 0x3F, 'mode': 'R/W', 'hbit': 12, 'lbit': 12, 'val': 0},
        'TX_PMA_RESET':             {'addr': 0x3F, 'mode': 'W/C', 'hbit': 13, 'lbit': 13, 'val': 0},
        'TX_RESET_OVR':             {'addr': 0x3F, 'mode': 'R/W', 'hbit': 14, 'lbit': 14, 'val': 0},
        'TX_RESET':                 {'addr': 0x3F, 'mode': 'W/C', 'hbit': 15, 'lbit': 15, 'val': 0},
        'TX_PMA_LOOPBACK':          {'addr': 0x40, 'mode': 'R/W', 'hbit':  1, 'lbit':  0, 'val': 0},
        'TX_PCS_LOOPBACK':          {'addr': 0x40, 'mode': 'R/W', 'hbit':  2, 'lbit':  2, 'val': 0},
        'TX_DATAPATH_SEL':          {'addr': 0x40, 'mode': 'R/W', 'hbit':  4, 'lbit':  3, 'val': 3},
        'TX_PRBS_OVR':              {'addr': 0x40, 'mode': 'R/W', 'hbit':  5, 'lbit':  5, 'val': 0},
        'TX_PRBS_SEL':              {'addr': 0x40, 'mode': 'R/W', 'hbit':  8, 'lbit':  6, 'val': 0},
        'TX_PRBS_FORCE_ERR':        {'addr': 0x40, 'mode': 'W/C', 'hbit':  9, 'lbit':  9, 'val': 0},
        'TX_LOOPBACK_OVR':          {'addr': 0x40, 'mode': 'R/W', 'hbit': 10, 'lbit': 10, 'val': 0},
        'TX_POWER_DOWN_OVR':        {'addr': 0x40, 'mode': 'R/W', 'hbit': 11, 'lbit': 11, 'val': 0},
        'TX_POWER_DOWN_N':          {'addr': 0x40, 'mode': 'R/W', 'hbit': 12, 'lbit': 12, 'val': 0},
        'TX_ELEC_IDLE_OVR':         {'addr': 0x41, 'mode': 'R/W', 'hbit':  0, 'lbit':  0, 'val': 0},
        'TX_ELEC_IDLE':             {'addr': 0x41, 'mode': 'R/W', 'hbit':  1, 'lbit':  1, 'val': 0},
        'TX_DETECT_RX_OVR':         {'addr': 0x41, 'mode': 'R/W', 'hbit':  2, 'lbit':  2, 'val': 0},
        'TX_DETECT_RX':             {'addr': 0x41, 'mode': 'R/W', 'hbit':  3, 'lbit':  3, 'val': 0},
        'TX_POLARITY_OVR':          {'addr': 0x41, 'mode': 'R/W', 'hbit':  4, 'lbit':  4, 'val': 0},
        'TX_POLARITY':              {'addr': 0x41, 'mode': 'R/W', 'hbit':  5, 'lbit':  5, 'val': 0},
        'TX_8B10B_EN_OVR':          {'addr': 0x41, 'mode': 'R/W', 'hbit':  6, 'lbit':  6, 'val': 0},
        'TX_8B10B_EN':              {'addr': 0x41, 'mode': 'R/W', 'hbit':  7, 'lbit':  7, 'val': 0},
        'TX_DATA_OVR':              {'addr': 0x41, 'mode': 'R/W', 'hbit':  8, 'lbit':  8, 'val': 0},
        'TX_DATA_CNT':              {'addr': 0x41, 'mode': 'R/W', 'hbit': 11, 'lbit':  9, 'val': 0},
        'TX_DATA_VALID':            {'addr': 0x41, 'mode': 'W/C', 'hbit': 12, 'lbit': 12, 'val': 0},
        'TX_BUF_ERR':               {'addr': 0x41, 'mode': 'R',   'hbit': 13, 'lbit': 13, 'val': 0},
        'TX_RESET_DONE':            {'addr': 0x41, 'mode': 'R',   'hbit': 14, 'lbit': 14, 'val': 0},
        'TX_DATA':                  {'addr': 0x42, 'mode': 'R/W', 'hbit': 15, 'lbit':  0, 'val': 0},
        # 0x43..0x4F unused
        'PLL_EN_ADPLL_CTRL':        {'addr': 0x50, 'mode': 'R/W', 'hbit':  0, 'lbit':  0, 'val': 0},
        'PLL_CONFIG_SEL':           {'addr': 0x50, 'mode': 'R/W', 'hbit':  1, 'lbit':  1, 'val': 1},
        'PLL_SET_OP_LOCK':          {'addr': 0x50, 'mode': 'R/W', 'hbit':  2, 'lbit':  2, 'val': 0},
        'PLL_ENFORCE_LOCK':         {'addr': 0x50, 'mode': 'R/W', 'hbit':  3, 'lbit':  3, 'val': 0},
        'PLL_DISABLE_LOCK':         {'addr': 0x50, 'mode': 'R/W', 'hbit':  4, 'lbit':  4, 'val': 0},
        'PLL_LOCK_WINDOW':          {'addr': 0x50, 'mode': 'R/W', 'hbit':  5, 'lbit':  5, 'val': 1},
        'PLL_FAST_LOCK':            {'addr': 0x50, 'mode': 'R/W', 'hbit':  6, 'lbit':  6, 'val': 1},
        'PLL_SYNC_BYPASS':          {'addr': 0x50, 'mode': 'R/W', 'hbit':  7, 'lbit':  7, 'val': 0},
        'PLL_PFD_SELECT':           {'addr': 0x50, 'mode': 'R/W', 'hbit':  8, 'lbit':  8, 'val': 0},
        'PLL_REF_BYPASS':           {'addr': 0x50, 'mode': 'R/W', 'hbit':  9, 'lbit':  9, 'val': 0},
        'PLL_REF_SEL':              {'addr': 0x50, 'mode': 'R/W', 'hbit': 10, 'lbit': 10, 'val': 1},
        'PLL_REF_RTERM':            {'addr': 0x50, 'mode': 'R/W', 'hbit': 11, 'lbit': 11, 'val': 1},
        'PLL_FCNTRL':               {'addr': 0x51, 'mode': 'R/W', 'hbit':  5, 'lbit':  0, 'val': 58},
        'PLL_MAIN_DIVSEL':          {'addr': 0x51, 'mode': 'R/W', 'hbit': 11, 'lbit':  6, 'val': 27},
        'PLL_OUT_DIVSEL':           {'addr': 0x51, 'mode': 'R/W', 'hbit': 13, 'lbit': 12, 'val': 0},
        'PLL_CI':                   {'addr': 0x52, 'mode': 'R/W', 'hbit':  4, 'lbit':  0, 'val': 3},
        'PLL_CP':                   {'addr': 0x52, 'mode': 'R/W', 'hbit': 14, 'lbit':  5, 'val': 80},
        'PLL_AO':                   {'addr': 0x53, 'mode': 'R/W', 'hbit':  3, 'lbit':  0, 'val': 0},
        'PLL_SCAP':                 {'addr': 0x53, 'mode': 'R/W', 'hbit':  6, 'lbit':  4, 'val': 0},
        'PLL_FILTER_SHIFT':         {'addr': 0x53, 'mode': 'R/W', 'hbit':  8, 'lbit':  7, 'val': 2},
        'PLL_SAR_LIMIT':            {'addr': 0x53, 'mode': 'R/W', 'hbit': 11, 'lbit':  9, 'val': 2},
        'PLL_FT':                   {'addr': 0x54, 'mode': 'R/W', 'hbit': 10, 'lbit':  0, 'val': 512},
        'PLL_OPEN_LOOP':            {'addr': 0x54, 'mode': 'R/W', 'hbit': 11, 'lbit': 11, 'val': 0},
        'PLL_SCAP_AUTO_CAL':        {'addr': 0x54, 'mode': 'R/W', 'hbit': 12, 'lbit': 12, 'val': 1},
        'PLL_LOCKED':               {'addr': 0x55, 'mode': 'R',   'hbit':  0, 'lbit':  0, 'val': 0},
        'PLL_CAP_FT_OF':            {'addr': 0x55, 'mode': 'R',   'hbit':  1, 'lbit':  1, 'val': 0},
        'PLL_CAP_FT_UF':            {'addr': 0x55, 'mode': 'R',   'hbit':  2, 'lbit':  2, 'val': 0},
        'PLL_CAP_FT':               {'addr': 0x55, 'mode': 'R',   'hbit': 12, 'lbit':  3, 'val': 0},
        'PLL_CAP_STATE':            {'addr': 0x55, 'mode': 'R',   'hbit': 14, 'lbit': 13, 'val': 0},
        'PLL_SYNC_VALUE':           {'addr': 0x56, 'mode': 'R',   'hbit':  7, 'lbit':  0, 'val': 0},
        'PLL_BISC_MODE':            {'addr': 0x57, 'mode': 'R/W', 'hbit':  2, 'lbit':  0, 'val': 4},
        'PLL_BISC_TIMER_MAX':       {'addr': 0x57, 'mode': 'R/W', 'hbit':  6, 'lbit':  3, 'val': 15},
        'PLL_BISC_OPT_DET_IND':     {'addr': 0x57, 'mode': 'R/W', 'hbit':  7, 'lbit':  7, 'val': 0},
        'PLL_BISC_PFD_SEL':         {'addr': 0x57, 'mode': 'R/W', 'hbit':  8, 'lbit':  8, 'val': 0},
        'PLL_BISC_DLY_DIR':         {'addr': 0x57, 'mode': 'R/W', 'hbit':  9, 'lbit':  9, 'val': 0},
        'PLL_BISC_COR_DLY':         {'addr': 0x57, 'mode': 'R/W', 'hbit': 12, 'lbit': 10, 'val': 1},
        'PLL_BISC_CAL_SIGN':        {'addr': 0x57, 'mode': 'R/W', 'hbit': 13, 'lbit': 13, 'val': 0},
        'PLL_BISC_CAL_AUTO':        {'addr': 0x57, 'mode': 'R/W', 'hbit': 14, 'lbit': 14, 'val': 1},
        'PLL_BISC_CP_MIN':          {'addr': 0x58, 'mode': 'R/W', 'hbit':  4, 'lbit':  0, 'val': 4},
        'PLL_BISC_CP_MAX':          {'addr': 0x58, 'mode': 'R/W', 'hbit':  9, 'lbit':  5, 'val': 18},
        'PLL_BISC_CP_START':        {'addr': 0x58, 'mode': 'R/W', 'hbit': 14, 'lbit': 10, 'val': 12},
        'PLL_BISC_DLY_PFD_MON_REF': {'addr': 0x59, 'mode': 'R/W', 'hbit':  4, 'lbit':  0, 'val': 0},
        'PLL_BISC_DLY_PFD_MON_DIV': {'addr': 0x59, 'mode': 'R/W', 'hbit':  9, 'lbit':  5, 'val': 2},
        'PLL_BISC_TIMER_DONE':      {'addr': 0x5A, 'mode': 'R',   'hbit':  0, 'lbit':  0, 'val': 0},
        'PLL_BISC_CP':              {'addr': 0x5A, 'mode': 'R',   'hbit':  7, 'lbit':  1, 'val': 0}, # BISC_RESULT[15:1]
        'PLL_BISC_CO':              {'addr': 0x5B, 'mode': 'R',   'hbit': 15, 'lbit':  0, 'val': 0},
        'SERDES_ENABLE':            {'addr': 0x5C, 'mode': 'R/W', 'hbit':  0, 'lbit':  0, 'val': 1},
        'SERDES_AUTO_INIT':         {'addr': 0x5C, 'mode': 'R/W', 'hbit':  1, 'lbit':  1, 'val': 0},
        'SERDES_TESTMODE':          {'addr': 0x5C, 'mode': 'R/W', 'hbit':  2, 'lbit':  2, 'val': 0},
    })

    ports = {
        # name: width
        'TX_DATA_I': 64,
        'TX_RESET_I': 1,
        'TX_PCS_RESET_I': 1,
        'TX_PMA_RESET_I': 1,
        'PLL_RESET_I': 1,
        'TX_POWER_DOWN_N_I': 1,
        'TX_POLARITY_I': 1,
        'TX_PRBS_SEL_I': 3,
        'TX_PRBS_FORCE_ERR_I': 1,
        'TX_8B10B_EN_I': 1,
        'TX_8B10B_BYPASS_I': 8,
        'TX_CHAR_IS_K_I': 8,
        'TX_CHAR_DISPMODE_I': 8,
        'TX_CHAR_DISPVAL_I': 8,
        'TX_ELEC_IDLE_I': 1,
        'TX_DETECT_RX_I': 1,
        'LOOPBACK_I': 3,
        'TX_CLK_I': 1,
        'RX_CLK_I': 1,
        'RX_RESET_I': 1,
        'RX_PMA_RESET_I': 1,
        'RX_EQA_RESET_I': 1,
        'RX_CDR_RESET_I': 1,
        'RX_PCS_RESET_I': 1,
        'RX_BUF_RESET_I': 1,
        'RX_POWER_DOWN_N_I': 1,
        'RX_POLARITY_I': 1,
        'RX_PRBS_SEL_I': 3,
        'RX_PRBS_CNT_RESET_I': 1,
        'RX_8B10B_EN_I': 1,
        'RX_8B10B_BYPASS_I': 8,
        'RX_EN_EI_DETECTOR_I': 1,
        'RX_COMMA_DETECT_EN_I': 1,
        'RX_SLIDE_I': 1,
        'RX_MCOMMA_ALIGN_I': 1,
        'RX_PCOMMA_ALIGN_I': 1,
        'REGFILE_CLK_I': 1,
        'REGFILE_WE_I': 1,
        'REGFILE_EN_I': 1,
        'REGFILE_ADDR_I': 8,
        'REGFILE_DI_I': 16,
        'REGFILE_MASK_I': 16,
        'RX_DATA_O': 64,
        'RX_NOT_IN_TABLE_O': 8,
        'RX_CHAR_IS_COMMA_O': 8,
        'RX_CHAR_IS_K_O': 8,
        'RX_DISP_ERR_O': 8,
        'TX_DETECT_RX_DONE_O': 1,
        'TX_DETECT_RX_PRESENT_O': 1,
        'TX_BUF_ERR_O': 1,
        'TX_RESET_DONE_O': 1,
        'RX_PRBS_ERR_O': 1,
        'RX_BUF_ERR_O': 1,
        'RX_BYTE_IS_ALIGNED_O': 1,
        'RX_BYTE_REALIGN_O': 1,
        'RX_RESET_DONE_O': 1,
        'RX_EI_EN_O': 1,
        'RX_CLK_O': 1,
        'PLL_CLK_O': 1,
        'REGFILE_DO_O': 16,
        'REGFILE_RDY_O': 1
    }

    # keywords for conditional coloring
    pos_cond = ["DONE", "PRESENT", "LOCKED", "IS_ALIGNED", "EN_ADPLL_CTRL", "CONFIG_SEL", "SERDES_ENABLE"]
    neg_cond = ["ERR"]

    def __init__(self, args, jtag):
        self._jtag = jtag
        self._board = args.board
        if self._jtag is not None:
            self.configure()

    def configure(self):
        if self._board == Boards_e[0]: # auto
            self._jtag.configure(FindAndFormatFtdiAddr(0))
        elif self._board == Boards_e[1]: # pgm
            self._jtag.configure('ftdi://ftdi:232h/1')
        elif self._board == Boards_e[2]: # evb
            self._jtag.configure('ftdi://ftdi:2232h/1')
        self._jtag.reset()
        self._tool = JtagTool(self._jtag)

    def rd_id(self):
        self._tool.idcode()

    def wr_cfg(self, bitfile):
        self._tool.wr_cfg(bitfile)

    def gen_module_vlog(self, filename):
        print(f'Generate verilog template: {filename}')
        with open(filename, 'w') as file:
            file.write('// CC_SERDES instance generator\n')
            file.write(f'// generated: {datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")}\n')
            file.write('\n')
            file.write('CC_SERDES #(\n')
            for idx, (param, data) in enumerate(self.regfile.fields.items()):
                end = '' if idx == len(self.regfile.fields.items())-1 else ','
                if data['mode'] != 'R':
                    width = data['hbit']-data['lbit']+1
                    file.write(f'    .{param}({width}\'h{data['val']:X}){end}\n')
            file.write(') i_cc_serdes (\n')
            for idx, (port, width) in enumerate(self.ports.items()):
                end = '' if idx == len(self.ports.items())-1 else ','
                if port.endswith('_I'):
                    file.write(f'    .{port}({width}\'h{0:X}){end}\n')
                else: # port.endswith('_O'):
                    file.write(f'    .{port}(){end}\n')
            file.write(');\n')

    def gen_module_vhdl(self, filename):
        print(f'Generate VHDL template: {filename}')
        with open(filename, 'w') as file:
            file.write('-- CC_SERDES instance generator\n')
            file.write(f'-- generated: {datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")}\n')
            file.write('\n')
            file.write('i_cc_serdes: CC_SERDES\n')
            file.write('generic map (\n')
            for idx, (param, data) in enumerate(self.regfile.fields.items()):
                end = '' if (idx == len(self.regfile.fields.items())-1) else ','
                if data['mode'] != 'R':
                    file.write(f'    {param} => X"{data['val']:X}"{end}\n')
            file.write(')\n')
            file.write('port map (\n')
            for idx, (port, width) in enumerate(self.ports.items()):
                end = '' if idx == len(self.ports.items())-1 else ','
                if port.endswith('_I'):
                    file.write(f'    {port} => "{0}"{end}\n')
                else: # port.endswith('_O'):
                    file.write(f'    {port} => open{end}\n')
            file.write(');\n')

    def fprint(self, key, value, line):
        if any(cond in key for cond in self.pos_cond) and int(value) != 0:
            print(bcolors.OK + line + bcolors.RESET)
        elif any(cond in key for cond in self.pos_cond) and int(value) == 0:
            print(bcolors.WARN + line + bcolors.RESET)
        elif any(cond in key for cond in self.neg_cond) and int(value) > 0:
            print(bcolors.FAIL + line + bcolors.RESET)
        else:
            print(line)

    def rd_regfile_rx(self, verbose=0):
        for addr in range(0x00, 0x30):
            self._tool.wr_serdes_regfile(addr=addr, data=0, mask=0, wren=0)
            word = self._tool.rd_serdes_regfile()
            if verbose == 1:
                print(f'{addr:02X}: 0x{int(word):04X}')
            elif verbose == 2:
                filtered_entries = {key: value for key, value in self.regfile.fields.items() if value['addr'] == addr}
                for (key, value) in filtered_entries.items():
                    v = word[value['lbit']:value['hbit']+1]
                    line = f'{key:24} {int(v):4X}\'h {int(v):6}\'d'
                    self.fprint(key, v, line)

    def rd_regfile_rx_data(self, verbose=0):
        rx_data_80bit = 0
        word_idx = 0
        for addr in range(0x20, 0x25):
            self._tool.wr_serdes_regfile(addr=addr, data=0, mask=0, wren=0)
            word = self._tool.rd_serdes_regfile()
            if verbose == 1:
                print(f'{addr:02X}: 0x{int(word):04X}')
            elif verbose == 2:
                rx_fields = {
                    key: field for key, field in self.regfile.fields.items()
                    if field['addr'] == addr and key.startswith('RX_DATA[')
                }
                for field_name, field_info in rx_fields.items():
                    # Extract the relevant bits from the word
                    bit_slice = word[field_info['lbit']:field_info['hbit'] + 1]
                    rx_data_80bit |= int(bit_slice) << (16 * word_idx)
                    word_idx += 1

        print(f'{"RX_DATA[79:0]":24} {rx_data_80bit:020X}\'h')

        # Convert to 64-bit format by packing every 10 bits into bytes
        rx_data_64bit = 0
        byte_position = 0
        for bit_offset in range(0, 80, 10):
            byte_value = (rx_data_80bit >> bit_offset) & 0xFF
            rx_data_64bit |= byte_value << (byte_position * 8)
            byte_position += 1

        print(f'{"RX_DATA[63:0]":24} {rx_data_64bit:016X}\'h')

    def rd_regfile_tx(self, verbose=0):
        for addr in range(0x30, 0x43): # 0x43..0x4F unused
            self._tool.wr_serdes_regfile(addr=addr, data=0, mask=0, wren=0)
            word = self._tool.rd_serdes_regfile()
            if verbose == 1:
                print(f'{addr:02X}: 0x{int(word):04X}')
            elif verbose == 2:
                filtered_entries = {key: value for key, value in self.regfile.fields.items() if value['addr'] == addr}
                for (key, value) in filtered_entries.items():
                    v = word[value['lbit']:value['hbit']+1]
                    line = f'{key:24} {int(v):4X}\'h {int(v):6}\'d'
                    self.fprint(key, v, line)

    def rd_regfile_pll(self, verbose=0):
        for addr in range(0x50, 0x5D):
            self._tool.wr_serdes_regfile(addr=addr, data=0, mask=0, wren=0)
            word = self._tool.rd_serdes_regfile()
            if verbose == 1:
                print(f'{addr:02X}: 0x{int(word):04X}')
            elif verbose == 2:
                filtered_entries = {key: value for key, value in self.regfile.fields.items() if value['addr'] == addr}
                for (key, value) in filtered_entries.items():
                    v = word[value['lbit']:value['hbit']+1]
                    line = f'{key:24} {int(v):4X}\'h {int(v):6}\'d'
                    self.fprint(key, v, line)


if __name__ == '__main__':
    try:
        p = argparse.ArgumentParser(prog='serdestool', description='', epilog=ArgEpilog)

        p.add_argument('-l', '--list', dest='listdev', action='store_true', help='list available boards/programmers and exit')
        p.add_argument('-b', dest='board', type=str, metavar=Boards_e, default=Boards_e[0], required=False, help='select board (default: %(default)s)')
        p.add_argument('--index-chain', dest='idx', default=0, required=False, help='device index in JTAG chain (default: %(default)s)')
        p.add_argument('--freq', type=ArgHzRegex, default='10M', metavar="[0 - 30M]", required=False, help='frequency setting; append "k" to the argument for kilohertz or "M" for megahertz (default: %(default)s)')
        p.add_argument('-m', dest='filename', type=str, required=False, help='generate verilog or vhdl module; specify the file format with extension .v or .vhd')
        p.add_argument('--rdregrx', dest='rdregrx', action='store_true', help='read rx regfile')
        p.add_argument('--rdregrxdata', dest='rdregrxdata', action='store_true', help='read rx data')
        p.add_argument('--rdregtx', dest='rdregtx', action='store_true', help='read tx regfile')
        p.add_argument('--rdregpll', dest='rdregpll', action='store_true', help='read pll regfile')

        args = p.parse_args()
        usb  = UsbTools()
        jtag = JtagEngine(frequency=ArgHzParse(args.freq))

        if args.listdev:
            vps_lst = list()
            vps_lst.append((0x0403, 0x6010)) # evb: FT2232H
            vps_lst.append((0x0403, 0x6014)) # pgm: FT232H
            for line in usb.find_all(vps=vps_lst):
                print(*line)
            sys.exit()

        s = SerdesTool(args, jtag)
        s.rd_id()

        if args.filename is not None:
            filename = args.filename.lower()
            if filename.endswith('.v') or filename.endswith('.sv'):
                s.gen_module_vlog(filename)
            elif filename.endswith('.vhd') or filename.endswith('.vhdl'):
                s.gen_module_vhdl(filename)

        if args.rdregrx:
            s.rd_regfile_rx(verbose=2)
        if args.rdregrxdata:
            s.rd_regfile_rx_data(verbose=2)
        if args.rdregtx:
            s.rd_regfile_tx(verbose=2)
        if args.rdregpll:
            s.rd_regfile_pll(verbose=2)

    except Exception as e:
        print(e)
