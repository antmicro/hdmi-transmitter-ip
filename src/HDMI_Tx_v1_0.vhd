library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity HDMI_Tx_v1_0 is
	port (
	PXLCLK_I : in STD_LOGIC;
	PXLCLK_5X_I : in STD_LOGIC;
	LOCKED_I : in STD_LOGIC;

	--VGA
	VGA_HS : in std_logic;
	VGA_VS : in std_logic;
	VGA_DE : in std_logic;

	--VGA Color data
	DATA_I : in std_logic_vector(31 downto 0);

	--CTL
	CTL : in std_logic_vector(3 downto 0);

	--GUARD
	VGUARD : in std_logic;
	DGUARD : in std_logic;

	--DATA ISLAND

	DIEN : in std_logic;
	DIH : in std_logic;

	--HDMI
	HDMI_CLK_P : out  STD_LOGIC;
	HDMI_CLK_N : out  STD_LOGIC;
	HDMI_D2_P : out  STD_LOGIC;
	HDMI_D2_N : out  STD_LOGIC;
	HDMI_D1_P : out  STD_LOGIC;
	HDMI_D1_N : out  STD_LOGIC;
	HDMI_D0_P : out  STD_LOGIC;
	HDMI_D0_N : out  STD_LOGIC
	);
end HDMI_Tx_v1_0;

architecture arch_imp of HDMI_Tx_v1_0 is

component DVITransmitter is
	Port ( RED_I : in  STD_LOGIC_VECTOR (7 downto 0); 
	GREEN_I : in  STD_LOGIC_VECTOR (7 downto 0); 
	BLUE_I : in  STD_LOGIC_VECTOR (7 downto 0); 
	CTL_I : in STD_LOGIC_VECTOR(3 downto 0);
	VGUARD_I : in STD_LOGIC;
	DGUARD_I : in STD_LOGIC;
	DIEN_I : in STD_LOGIC;
	DIH_I : in STD_LOGIC;
	HS_I : in  STD_LOGIC;
	VS_I : in  STD_LOGIC;
	VDE_I : in  STD_LOGIC;
	RST_I : in STD_LOGIC;
	PCLK_I : in  STD_LOGIC;
	PCLK_X5_I : in  STD_LOGIC;
	TMDS_TX_CLK_P : out  STD_LOGIC;
	TMDS_TX_CLK_N : out  STD_LOGIC;
	TMDS_TX_2_P : out  STD_LOGIC;
	TMDS_TX_2_N : out  STD_LOGIC;
	TMDS_TX_1_P : out  STD_LOGIC;
	TMDS_TX_1_N : out  STD_LOGIC;
	TMDS_TX_0_P : out  STD_LOGIC;
	TMDS_TX_0_N : out  STD_LOGIC);
end component;

signal SysRst : std_logic;

signal VGA_R : std_logic_vector(7 downto 0);
signal VGA_G : std_logic_vector(7 downto 0);
signal VGA_B : std_logic_vector(7 downto 0);

begin

	SysRst <= not LOCKED_I;
	VGA_B <= DATA_I(7 downto 0);
	VGA_G <= DATA_I(15 downto 8);
	VGA_R <= DATA_I(23 downto 16);
----------------------------------------------------------------------------------
-- DVI/HDMI Transmitter
----------------------------------------------------------------------------------              
Inst_DVITransmitter: DVITransmitter 
PORT MAP(
	RED_I => VGA_R,
	GREEN_I => VGA_G,
	BLUE_I => VGA_B,
	CTL_I => CTL,
	VGUARD_I => VGUARD,
	DGUARD_I => DGUARD,
	DIEN_I => DIEN,
	DIH_I => DIH,
	HS_I => VGA_HS,
	VS_I => VGA_VS,
	VDE_I => VGA_DE,
	RST_I => SysRst,
	PCLK_I => PXLCLK_I,
	PCLK_X5_I => PXLCLK_5X_I,
	TMDS_TX_CLK_P => HDMI_CLK_P,
	TMDS_TX_CLK_N => HDMI_CLK_N,
	TMDS_TX_2_P => HDMI_D2_P,
	TMDS_TX_2_N => HDMI_D2_N,
	TMDS_TX_1_P => HDMI_D1_P,
	TMDS_TX_1_N => HDMI_D1_N,
	TMDS_TX_0_P => HDMI_D0_P,
	TMDS_TX_0_N => HDMI_D0_N 
);

end arch_imp;
