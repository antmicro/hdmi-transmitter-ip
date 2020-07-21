--------------------------------------------------------------------------------
--
--  File:
--      SerializerN_1.vhd
--
--  Module:
--      SerializerN_1
--
--  Author:
--      Elod Gyorgy
--
--  Date:
--      10/27/2010
--
--  Description:
--      This module serializes N:1 data LSB-first using cascaded OSERDES
--      primitives.
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity SerializerN_1 is
	Generic ( N : NATURAL := 10);
	Port ( DP_I : in STD_LOGIC_VECTOR (N-1 downto 0);
		CLKDIV_I : in STD_LOGIC; --parallel slow clock
		SERCLK_I : in STD_LOGIC; --serial fast clock (CLK_I = CLKDIV_I x N / 2)
		RST_I : in STD_LOGIC; --async reset
		DSP_O : out STD_LOGIC;
		DSN_O : out STD_LOGIC);
end SerializerN_1;

architecture Behavioral of SerializerN_1 is
signal intDSOut: std_logic;
signal intDPIn : std_logic_vector(N/2-1 downto 0) ;
signal padDPIn : std_logic_vector(13 downto 0) ;
signal cascade_do, cascade_di, cascade_to, cascade_ti : std_logic;
signal gear, gear_s : std_logic := '0';
signal int_rst : std_logic;
begin

----------------------------------------------------------------------------------
-- Instantiate Output Buffer
----------------------------------------------------------------------------------
io_datax_out : obufds port map (
	O => DSP_O,
	OB => DSN_O,
	I => intDSOut
);

----------------------------------------------------------------------------------
-- Reset should be asserted asynchronously an de-asserted synchronously
----------------------------------------------------------------------------------
process(RST_I, CLKDIV_I)
begin
	if (RST_I = '1') then
		int_rst <= '1';
	elsif Rising_Edge(CLKDIV_I) then
		int_rst <= '0';
	end if;
end process;

padDPIn(13 downto N) <= (others => '0');
padDPIn(N-1 downto 0) <= DP_I;
----------------------------------------------------------------------------------
-- Cascaded OSERDES for 10:1 ratio (DDR)
----------------------------------------------------------------------------------
oserdese2_master : OSERDESE2
	generic map (
		DATA_RATE_OQ => "DDR",
		DATA_RATE_TQ => "SDR",
		DATA_WIDTH => N,
		TRISTATE_WIDTH => 1,
		SERDES_MODE => "MASTER")
	port map (
		D1 => padDPIn(0),
		D2 => padDPIn(1),
		D3 => padDPIn(2),
		D4 => padDPIn(3),
		D5 => padDPIn(4),
		D6 => padDPIn(5),
		D7 => padDPIn(6),
		D8 => padDPIn(7),
		T1 => '0',
		T2 => '0',
		T3 => '0',
		T4 => '0',
		SHIFTIN1 => cascade_di,
		SHIFTIN2 => cascade_ti,
		SHIFTOUT1 => open,
		SHIFTOUT2 => open,
		OCE => '1',
		CLK => SERCLK_I,
		CLKDIV => CLKDIV_I,
		OQ => intDsOut,
		TQ => open,
		OFB => open,
		TBYTEIN => '0',
		TBYTEOUT => open,
		TFB => open,
		TCE => '0',
		RST => int_rst);

oserdese2_slave : OSERDESE2
	generic map (
		DATA_RATE_OQ => "DDR",
		DATA_RATE_TQ => "SDR",
		DATA_WIDTH => N,
		TRISTATE_WIDTH => 1,
		SERDES_MODE => "SLAVE")
	port map (
		D1 => '0', 
		D2 => '0',
		D3 => padDPIn(8),
		D4 => padDPIn(9),
		D5 => padDPIn(10),
		D6 => padDPIn(11),
		D7 => padDPIn(12),
		D8 => padDPIn(13),
		T1 => '0',
		T2 => '0',
		T3 => '0',
		T4 => '0',
		SHIFTOUT1 => cascade_di,
		SHIFTOUT2 => cascade_ti,
		SHIFTIN1 => '0',
		SHIFTIN2 => '0',
		OCE => '1',
		CLK => SERCLK_I,
		CLKDIV => CLKDIV_I,
		OQ => open,
		TQ => open,
		OFB => open,
		TFB => open,
		TBYTEIN => '0',
		TBYTEOUT => open,
		TCE => '0',
		RST => int_rst);

end Behavioral;

