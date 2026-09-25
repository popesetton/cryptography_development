-- Included libraries
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Entity Name: Crypto System Top File
-- Description: Top file with all component instantiations
entity cryptosystem_topfile is
    Port (clk:                      IN  STD_LOGIC;
          reset_n:                  IN  STD_LOGIC;
          data1:                    IN  STD_LOGIC_VECTOR(9 downto 0);
          req1:                     IN  STD_LOGIC;
          data2:                    IN  STD_LOGIC_VECTOR(9 downto 0);
          req2:                     IN  STD_LOGIC;
          grant1:                   OUT STD_LOGIC;
          grant2:                   OUT STD_LOGIC;
          
          -- XTEA outputs
          ciphertext_word_out:      OUT STD_LOGIC_VECTOR(31 downto 0);
          ciphertext_ready:         OUT STD_LOGIC;
          data_word_out:            OUT STD_LOGIC_VECTOR(31 downto 0);
          data_ready:               OUT STD_LOGIC       
          );
end cryptosystem_topfile;

architecture Behavioral of cryptosystem_topfile is
    signal data_out:            STD_LOGIC_VECTOR(8 downto 0);
    signal valid:               STD_LOGIC;
begin

    -- Instantiate mini router
    minirouter: entity work.minirouter
        port map(
            clk         => clk,
            reset_n     => reset_n,
            data1       => data1,
            req1        => req1,
            data2       => data2,
            req2        => req2,
            grant1      => grant1,
            grant2      => grant2,
            data_out    => data_out,
            valid       => valid
            );
            
    -- Instantiate XTEA module with router to XTEA converter
    xtea_module: entity work.XTEA_duplex_topfile
        port map(
            clk                     => clk,
            reset_n                 => reset_n,
            router_data_out         => data_out,
            router_valid            => valid,
            ciphertext_word_out     => ciphertext_word_out,
            ciphertext_ready        => ciphertext_ready,
            data_word_out           => data_word_out,
            data_ready              => data_ready
            );

end Behavioral;
