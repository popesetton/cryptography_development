-- Included libraries
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Entity Name: XTEA Duplex Topfile
-- Description: Contains top for duplex XTEA implementation
--              Instantiates internal module blocks contained in other .vhd files within the project
entity XTEA_duplex_topfile is
    Port (clk:                  IN  STD_LOGIC;
          reset_n:              IN  STD_LOGIC;
         
          data_word_in:         IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
          data_valid:           IN  STD_LOGIC;
          
          ciphertext_word_in:   IN  STD_LOGIC_VECTOR(31 downto 0);
          ciphertext_valid:     IN  STD_LOGIC;
          
          key_word_in:          IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
          key_valid:            IN  STD_LOGIC;
          
          key_ready:            OUT STD_LOGIC;
          
          ciphertext_word_out:  OUT STD_LOGIC_VECTOR(31 downto 0);
          ciphertext_ready:     OUT STD_LOGIC;
          
          data_word_out:        OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
          data_ready:           OUT STD_LOGIC      
    );
end XTEA_duplex_topfile;

architecture Behavioral of XTEA_duplex_topfile is   
    -- Key signals
    signal key_0:               unsigned(31 downto 0);
    signal key_1:               unsigned(31 downto 0);
    signal key_2:               unsigned(31 downto 0);
    signal key_3:               unsigned(31 downto 0);
    
    signal key_ready_internal:  STD_LOGIC;   
   
    -- Encryption subkey signals
    signal enc_key_word_out:    unsigned(31 downto 0);
    signal enc_subkey_enable:   STD_LOGIC;
    
    -- Decryption subkey signals
    signal dec_key_word_out:    unsigned(31 downto 0);
    signal dec_subkey_enable:   STD_LOGIC;
    
    -- Encryption output signals
    signal enc_data_word_out:   unsigned(31 downto 0);
    signal enc_data_ready:      STD_LOGIC;
    
    -- Decryption output signals
    signal dec_data_word_out:   unsigned(31 downto 0);
    signal dec_data_ready:      STD_LOGIC;
    
begin
    
    -- Internal key ready signal
    key_ready           <= key_ready_internal;
    
    -- Encryption output maps to ciphertext output ports
    ciphertext_word_out <= std_logic_vector(enc_data_word_out);
    ciphertext_ready    <= enc_data_ready;
    
    -- Decryption output maps to plaintext output ports
    data_word_out       <= std_logic_vector(dec_data_word_out);
    data_ready          <= dec_data_ready;
    
    -- Instanatiate shared key registers
    key_file: entity work.key_file
        port map (
            clk                 => clk,
            reset_n             => reset_n,
            key_word_in         => unsigned(key_word_in),
            key_valid           => key_valid,
            key_0               => key_0,
            key_1               => key_1,
            key_2               => key_2,
            key_3               => key_3,
            key_ready           => key_ready_internal
            );
    
    -- Instantiate subkey calculation module for encryption
    subkey_calc_enc: entity work.subkey_calc_enc
        port map (
            clk                 => clk,
            reset_n             => reset_n,
            key_ready           => key_ready_internal,
            key_0               => key_0,
            key_1               => key_1,
            key_2               => key_2,
            key_3               => key_3,
            enc_subkey_enable   => enc_subkey_enable,
            enc_key_word_out    => enc_key_word_out
            );

    -- Instantiate subkey calculation module for decryption
    subkey_calc_dec: entity work.subkey_calc_dec
        port map (
            clk                 => clk,
            reset_n             => reset_n,
            key_ready           => key_ready_internal,
            key_0               => key_0,
            key_1               => key_1,
            key_2               => key_2,
            key_3               => key_3,
            dec_subkey_enable   => dec_subkey_enable,
            dec_key_word_out    => dec_key_word_out
            );
            
    -- Instantiate XTEA encryption block
    xtea_enc: entity work.xtea_enc
        port map (
            clk                 => clk,
            reset_n             => reset_n,        
            
            key_ready           => key_ready_internal,
            enc_key_word_in     => enc_key_word_out,   
                
            data_valid          => data_valid,
            data_word_in        => unsigned(data_word_in),
            
            enc_subkey_enable   => enc_subkey_enable,
            
            data_ready          => enc_data_ready,
            data_word_out       => enc_data_word_out
            );

    -- Instantiate XTEA decryption block
    xtea_dec: entity work.xtea_dec
        port map (
            clk                 => clk,
            reset_n             => reset_n,     
               
            key_ready           => key_ready_internal,
            dec_key_word_in     => dec_key_word_out,
               
            data_valid          => ciphertext_valid,
            data_word_in        => unsigned(ciphertext_word_in),
            
            dec_subkey_enable   => dec_subkey_enable,
            
            data_ready          => dec_data_ready,
            data_word_out       => dec_data_word_out
            );
end Behavioral;
