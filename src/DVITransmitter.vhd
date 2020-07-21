--------------------------------------------------------------------------------
--
--  File:
--      DVITransmitter.vhd
--
--  Module:
--      DVITransmitter
--
--  Author:
--      Elod Gyorgy
--
--  Date:
--      04/06/2011
--
--  Description:
--      DVITransmitter takes 24-bit RGB video data with proper sync
--      signals and transmits them on a DVI or HDMI port. The encoding and serialization
--      is done according to the Digital Visual Interface (DVI) specifications Rev 1.0.
--
--  Copyright notice:
--      Copyright (C) 2014 Digilent Inc.
--
--  License:
--      This program is free software; distributed under the terms of 
--      BSD 3-clause license ("Revised BSD License", "New BSD License", or "Modified BSD License")
--
--      Redistribution and use in source and binary forms, with or without modification,
--      are permitted provided that the following conditions are met:
--
--      1.    Redistributions of source code must retain the above copyright notice, this
--             list of conditions and the following disclaimer.
--      2.    Redistributions in binary form must reproduce the above copyright notice,
--             this list of conditions and the following disclaimer in the documentation
--             and/or other materials provided with the distribution.
--      3.    Neither the name(s) of the above-listed copyright holder(s) nor the names
--             of its contributors may be used to endorse or promote products derived
--             from this software without specific prior written permission.
--
--      THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
--      ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
--      WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
--      IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
--      INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
--      BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
--      DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
--      LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
--      OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
--      OF THE POSSIBILITY OF SUCH DAMAGE.
--
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

--library digilent;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity DVITransmitter is
	Port ( RED_I : in STD_LOGIC_VECTOR (7 downto 0);
		GREEN_I : in STD_LOGIC_VECTOR (7 downto 0);
		BLUE_I : in STD_LOGIC_VECTOR (7 downto 0);
		CTL_I : in STD_LOGIC_VECTOR(3 downto 0);
		VGUARD_I : in STD_LOGIC;
		DGUARD_I : in STD_LOGIC;
		DIEN_I : in STD_LOGIC;
		DIH_I : in STD_LOGIC;
		HS_I : in STD_LOGIC;
		VS_I : in STD_LOGIC;
		VDE_I : in STD_LOGIC;
		RST_I : in STD_LOGIC;
		PCLK_I : in STD_LOGIC;
		PCLK_X5_I : in STD_LOGIC;
		TMDS_TX_CLK_P : out STD_LOGIC;
		TMDS_TX_CLK_N : out STD_LOGIC;
		TMDS_TX_2_P : out STD_LOGIC;
		TMDS_TX_2_N : out STD_LOGIC;
		TMDS_TX_1_P : out STD_LOGIC;
		TMDS_TX_1_N : out STD_LOGIC;
		TMDS_TX_0_P : out STD_LOGIC;
		TMDS_TX_0_N : out STD_LOGIC);
end DVITransmitter;

architecture Behavioral of DVITransmitter is
signal intTmdsRed, intTmdsGreen, intTmdsBlue : std_logic_vector(9 downto 0);
signal intTmdsRed_d, intTmdsGreen_d, intTmdsBlue_d : std_logic_vector(9 downto 0);
signal tmds_p, tmds_n : std_logic_vector(3 downto 0);
signal int_rst, SerClk : std_logic;

constant CLKIN_PERIOD : REAL := 13.468; --ns = 74.25MHz (maximum supported pixel clock)
constant N : NATURAL := 10; --serialization factor
constant PLLO0 : NATURAL := 1; -- SERCLK = PCLK * N
constant PLLO2 : NATURAL := PLLO0 * N; -- PCLK = PCLK * N / N
constant PLLO3 : NATURAL := PLLO0 * N / 2; -- PCLK_X2 = PLCK * N / (N/2)
signal intfb, intfb_buf, intpllout_x2, pllout_xs, pllout_x1, pllout_x2: std_logic;
signal PClk, PllLckd, PllRst, intRst, BufPllLckd: std_logic;
signal vguard_d, vguard_dd, vguard_ddd : std_logic;
signal dguard_d, dguard_dd, dguard_ddd : std_logic;
signal dien_d, dien_dd, dien_ddd : std_logic;
signal dih_d, dih_dd, dih_ddd : std_logic;

component SerializerN_1 is
	Generic ( N : NATURAL := 10);
	Port ( DP_I : in STD_LOGIC_VECTOR (N-1 downto 0);
		CLKDIV_I : in STD_LOGIC; --parallel slow clock
		SERCLK_I : in STD_LOGIC; --serial fast clock (CLK_I = CLKDIV_I x N / 2)
		RST_I : in STD_LOGIC; --async reset
		DSP_O : out STD_LOGIC;
		DSN_O : out STD_LOGIC);
end component;

component TMDSEncoder is
	Port ( D_I : in STD_LOGIC_VECTOR (7 downto 0);
		C0_I : in STD_LOGIC;
		C1_I : in STD_LOGIC;
		DE_I : in STD_LOGIC;
		CLK_I: in STD_LOGIC;
		RST_I: in STD_LOGIC;
		D_O : out STD_LOGIC_VECTOR (9 downto 0));
end component;

begin

PllRst <= RST_I;
PClk <= PCLK_I;
SerClk <= PCLK_X5_I;
intRst <= RST_I;

----------------------------------------------------------------------------------
-- DVI Encoder; DVI 1.0 Specifications
-- This component encodes 24-bit RGB video frames with sync signals into 10-bit
-- TMDS characters.
----------------------------------------------------------------------------------
Inst_TMDSEncoder_red: TMDSEncoder
PORT MAP(
	D_I => RED_I,
	C0_I => CTL_I(2),
	C1_I => CTL_I(3),
	DE_I => VDE_I,
	CLK_I => PClk,
	RST_I => intRst,
	D_O => intTmdsRed
);
Inst_TMDSEncoder_green: TMDSEncoder
PORT MAP(
	D_I => GREEN_I,
	C0_I => CTL_I(0),
	C1_I => CTL_I(1),
	DE_I => VDE_I,
	CLK_I => PClk,
	RST_I => intRst,
	D_O => intTmdsGreen
);
Inst_TMDSEncoder_blue: TMDSEncoder
PORT MAP(
	D_I => BLUE_I,
	C0_I => HS_I,
	C1_I => VS_I,
	DE_I => VDE_I,
	CLK_I => PClk,
	RST_I => intRst,
	D_O => intTmdsBlue
);

----------------------------------------------------------------------------------
--
----------------------------------------------------------------------------------

process(PClk, intRst)
begin
	if (intRst = '1') then
		vguard_d <= '0';
		vguard_dd <= '0';
		vguard_ddd <= '0';
		dguard_d <= '0';
		dguard_dd <= '0';
		dguard_ddd <= '0';
		dien_d <= '0';
		dien_dd <= '0';
		dien_ddd <= '0';
		dih_d <= '0';
		dih_dd <= '0';
		dih_ddd <= '0';
	elsif (rising_edge(PClk)) then
		vguard_d <= VGUARD_I;
		vguard_dd <= vguard_d;
		vguard_ddd <= vguard_dd;
		dguard_d <= DGUARD_I;
		dguard_dd <= dguard_d;
		dguard_ddd <= dguard_dd;
		dien_d <= DIEN_I;
		dien_dd <= dien_d;
		dien_ddd <= dien_dd;
		dih_d <= DIH_I;
		dih_dd <= dih_d;
		dih_ddd <= dih_dd;
	end if;
end process;

process(PClk)
begin
	if (rising_edge(PClk)) then
		if (vguard_ddd = '1') then
			intTmdsBlue_d <= "1011001100";
			intTmdsGreen_d <= "0100110011";
			intTmdsRed_d <= "1011001100";
		elsif (dguard_ddd = '1') then
			intTmdsBlue_d <= "1011000011";
			intTmdsGreen_d <= "0100110011";
			intTmdsRed_d <= "0100110011";
		elsif (dih_ddd = '1') then
			intTmdsBlue_d <= "1011100010";
			intTmdsGreen_d <= "1010011100";
			intTmdsRed_d <= "1010011100";
		elsif (dien_ddd = '1') then
			intTmdsBlue_d <= "1011000110";
			intTmdsGreen_d <= "1010011100";
			intTmdsRed_d <= "1010011100";
		else
			intTmdsBlue_d <= intTmdsBlue;
			intTmdsGreen_d <= intTmdsGreen;
			intTmdsRed_d <= intTmdsRed;
		end if;
	end if;
end process;

----------------------------------------------------------------------------------
-- TMDS serializer; ratio of 10:1; 3 data & 1 clock channel
-- Since the TMDS clock's period is character-long (10-bit periods), the
-- serialization of "1111100000" will result in a 10-bit long clock period.
----------------------------------------------------------------------------------

Inst_clk_serializer_10_1: SerializerN_1 GENERIC MAP (10)
PORT MAP(
	DP_I => "1111100000",
	CLKDIV_I => PClk,
	SERCLK_I => SerClk,
	RST_I => intRst,
	DSP_O => TMDS_TX_CLK_P,
	DSN_O => TMDS_TX_CLK_N
);
Inst_d2_serializer_10_1: SerializerN_1 GENERIC MAP (10)
PORT MAP(
	DP_I => intTmdsRed_d,
	CLKDIV_I => PClk,
	SERCLK_I => SerClk,
	RST_I => intRst,
	DSP_O => TMDS_TX_2_P,
	DSN_O => TMDS_TX_2_N
);
Inst_d1_serializer_10_1: SerializerN_1 GENERIC MAP (10)
PORT MAP(
	DP_I => intTmdsGreen_d,
	CLKDIV_I => PClk,
	SERCLK_I => SerClk,
	RST_I => intRst,
	DSP_O => TMDS_TX_1_P,
	DSN_O => TMDS_TX_1_N
);
Inst_d0_serializer_10_1: SerializerN_1 GENERIC MAP (10)
PORT MAP(
	DP_I => intTmdsBlue_d,
	CLKDIV_I => PClk,
	SERCLK_I => SerClk,
	RST_I => intRst,
	DSP_O => TMDS_TX_0_P,
	DSN_O => TMDS_TX_0_N
);

end Behavioral;
