-- Included libraries
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Entity name: Cryptosystem FPGA top file
-- Description: Instantiates all modules, contains FPGA wrapper
entity cryptosystem_FPGA_topfile is
    Port (clk:      IN  STD_LOGIC;
          reset:    IN  STD_LOGIC;
          led:      OUT STD_LOGIC_VECTOR(15 downto 0);
          
          uart_rx:  IN  STD_LOGIC;
          uart_tx:  OUT STD_LOGIC
          );
end cryptosystem_FPGA_topfile;

architecture Behavioral of cryptosystem_FPGA_topfile is
    -- Flying signals
    signal reset_n:                     STD_LOGIC;
    
    -- IP signals
    signal data1:                       STD_LOGIC_VECTOR(9 downto 0);
    signal req1:                        STD_LOGIC;
    signal grant1:                      STD_LOGIC;
    
    signal data2:                       STD_LOGIC_VECTOR(9 downto 0);
    signal req2:                        STD_LOGIC;
    signal grant2:                      STD_LOGIC;
    
    -- Mini router signals
    signal data_out:                    STD_LOGIC_VECTOR(8 downto 0);
    signal valid:                       STD_LOGIC;
    
    -- XTEA module signals
    signal ciphertext_word_out:         STD_LOGIC_VECTOR(31 downto 0);
    signal ciphertext_ready:            STD_LOGIC;
    
    signal data_word_out:               STD_LOGIC_VECTOR(31 downto 0);
    signal data_ready:                  STD_LOGIC;
   
    -- FPGA wrapper FSM
    type state_t is (
        WAIT_RESULTS,
        UART_LOAD_BYTE,
        UART_START_TX,
        UART_WAIT_BUSY,
        UART_WAIT_DONE,
        DONE
        );
        
    -- State register
    signal state_reg:                   state_t;
    
    -- Capture registers for encrypted data
    signal enc_out_0:               STD_LOGIC_VECTOR(31 downto 0);
    signal enc_out_1:               STD_LOGIC_VECTOR(31 downto 0);
    signal enc_out_2:               STD_LOGIC_VECTOR(31 downto 0);
    signal enc_out_3:               STD_LOGIC_VECTOR(31 downto 0);
    
    -- Capture registers for decrypted data
    signal dec_out_0:               STD_LOGIC_VECTOR(31 downto 0);
    signal dec_out_1:               STD_LOGIC_VECTOR(31 downto 0);
    signal dec_out_2:               STD_LOGIC_VECTOR(31 downto 0);
    signal dec_out_3:               STD_LOGIC_VECTOR(31 downto 0);
    
    -- Separate output counters because encryption and decryption may finish at different times
    signal enc_out_count:           unsigned(1 downto 0);
    signal dec_out_count:           unsigned(1 downto 0);
    
    signal enc_done:                STD_LOGIC;
    signal dec_done:                STD_LOGIC;
    
    -- LED register
    signal led_reg:                 STD_LOGIC_VECTOR(15 downto 0);
    constant LED_FLASH:             STD_LOGIC_VECTOR(15 downto 0) := x"FFFF";
    
    -- UART signals
    signal uart_tx_ena:             STD_LOGIC;
    signal uart_tx_data:            STD_LOGIC_VECTOR(7 downto 0);
    signal uart_tx_busy:            STD_LOGIC;
    
    signal uart_rx_busy  : std_logic;
    signal uart_rx_error : std_logic;
    signal uart_rx_data  : std_logic_vector(7 downto 0);

    -- Choose which byte to send over UART, 6 bits for 16 byte XTEA blocks
    signal uart_byte_count : unsigned(5 downto 0);
    
    -- Function that chooses relevant ciphertext or plaintext byte for UART transmission
    function get_uart_byte(
        index : unsigned(5 downto 0);
    
        e0 : std_logic_vector(31 downto 0);
        e1 : std_logic_vector(31 downto 0);
        e2 : std_logic_vector(31 downto 0);
        e3 : std_logic_vector(31 downto 0);
    
        d0 : std_logic_vector(31 downto 0);
        d1 : std_logic_vector(31 downto 0);
        d2 : std_logic_vector(31 downto 0);
        d3 : std_logic_vector(31 downto 0)
    ) return std_logic_vector is
    begin
    
        case to_integer(index) is
    
            -- Encryption output, word 0
            when 0  => return e0(31 downto 24);
            when 1  => return e0(23 downto 16);
            when 2  => return e0(15 downto 8);
            when 3  => return e0(7 downto 0);
    
            -- Encryption output, word 1
            when 4  => return e1(31 downto 24);
            when 5  => return e1(23 downto 16);
            when 6  => return e1(15 downto 8);
            when 7  => return e1(7 downto 0);
    
            -- Encryption output, word 2
            when 8  => return e2(31 downto 24);
            when 9  => return e2(23 downto 16);
            when 10 => return e2(15 downto 8);
            when 11 => return e2(7 downto 0);
    
            -- Encryption output, word 3
            when 12 => return e3(31 downto 24);
            when 13 => return e3(23 downto 16);
            when 14 => return e3(15 downto 8);
            when 15 => return e3(7 downto 0);
    
            -- Decryption output, word 0
            when 16 => return d0(31 downto 24);
            when 17 => return d0(23 downto 16);
            when 18 => return d0(15 downto 8);
            when 19 => return d0(7 downto 0);
    
            -- Decryption output, word 1
            when 20 => return d1(31 downto 24);
            when 21 => return d1(23 downto 16);
            when 22 => return d1(15 downto 8);
            when 23 => return d1(7 downto 0);
    
            -- Decryption output, word 2
            when 24 => return d2(31 downto 24);
            when 25 => return d2(23 downto 16);
            when 26 => return d2(15 downto 8);
            when 27 => return d2(7 downto 0);
    
            -- Decryption output, word 3
            when 28 => return d3(31 downto 24);
            when 29 => return d3(23 downto 16);
            when 30 => return d3(15 downto 8);
            when 31 => return d3(7 downto 0);
    
            when others => return x"00";
    
        end case;
    
    end function;
    
begin
    -- Assert LED
    led     <= led_reg;
    
    -- Invert reset from board
    reset_n <= not reset;
    
    -- Instantiate IP Encryption Data Generator
    ip_enc_generator: entity work.ip_enc_generator
        port map(
            clk             => clk,
            reset_n         => reset_n,
            grant1          => grant1,
            data1           => data1,
            req1            => req1
            );
    
    -- Instantiate IP Decryption Data Generator
    ip_dec_generator: entity work.ip_dec_generator
        port map(
            clk             => clk,
            reset_n         => reset_n,
            grant2          => grant2,
            data2           => data2,
            req2            => req2
            );
    
    -- Instantiate Mini Router
    minirouter: entity work.minirouter
        port map(
            clk             => clk,
            reset_n         => reset_n,
            data1           => data1,
            req1            => req1,
            data2           => data2,
            req2            => req2,
            grant1          => grant1,
            grant2          => grant2,
            data_out        => data_out,
            valid           => valid
            );
            
    -- Instantiate XTEA Module
    XTEA_duplex_topfile: entity work.XTEA_duplex_topfile
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
    
    -- Instantiate UART Module
    uart: entity work.uart
        generic map(
            clk_freq    => 100_000_000,
            baud_rate   => 115_200,
            os_rate     => 16,
            d_width     => 8,
            parity      => 0,
            parity_eo   => '0'
            )
        port map(
            clk             => clk,
            reset_n         => reset_n,
            
            tx_ena          => uart_tx_ena,
            tx_data         => uart_tx_data,
            
            rx              => uart_rx,
            rx_busy         => uart_rx_busy,
            rx_error        => uart_rx_error,
            rx_data         => uart_rx_data,
            
            tx_busy         => uart_tx_busy,
            tx              => uart_tx
            );
            
    -- FPGA wrapper FSM
    process (clk, reset_n) begin
        -- Reset high turned lower for FPGA implementation
        if reset_n = '0' then
        
            state_reg                   <= WAIT_RESULTS;
            
            enc_out_count               <= (others => '0');
            dec_out_count               <= (others => '0');
            
            enc_done        <= '0';
            dec_done        <= '0';

            enc_out_0       <= (others => '0');
            enc_out_1       <= (others => '0');
            enc_out_2       <= (others => '0');
            enc_out_3       <= (others => '0');

            dec_out_0       <= (others => '0');
            dec_out_1       <= (others => '0');
            dec_out_2       <= (others => '0');
            dec_out_3       <= (others => '0');

            led_reg         <= (others => '0');

            uart_tx_ena     <= '0';
            uart_tx_data    <= (others => '0');
            uart_byte_count <= (others => '0');
            
        elsif rising_edge(clk) then
        
            -- Default UART enable pulse low unless explicitly asserted
            uart_tx_ena     <= '0';
            
            case state_reg is
            
                when WAIT_RESULTS =>
                    
                    -- Capture encryption output words independently of decryption
                    if ciphertext_ready = '1' and enc_done = '0' then
                        case enc_out_count is
                            when "00" =>
                                enc_out_0           <= ciphertext_word_out;
                                enc_out_count       <= "01";
                                
                            when "01" =>
                                enc_out_1           <= ciphertext_word_out;
                                enc_out_count       <= "10";
                                
                            when "10" =>
                                enc_out_2           <= ciphertext_word_out;
                                enc_out_count       <= "11";
                                
                            when "11" =>
                                enc_out_3           <= ciphertext_word_out;
                                enc_done            <= '1';
                                
                            when others =>
                                enc_out_count       <= "00";
                            
                        end case;
                    end if;
                    
                    
                    -- Capture decryption output words independently of encryption
                    if data_ready = '1' and dec_done = '0' then
                        case dec_out_count is
                            when "00" =>
                                dec_out_0           <= data_word_out;
                                dec_out_count       <= "01";
                                
                            when "01" =>
                                dec_out_1           <= data_word_out;
                                dec_out_count       <= "10";
                                
                            when "10" =>
                                dec_out_2           <= data_word_out;
                                dec_out_count       <= "11";
                                
                            when "11" =>
                                dec_out_3           <= data_word_out;
                                dec_done            <= '1';
                                
                            when others =>
                                dec_out_count       <= "00";
                            
                        end case;
                    end if;
                    
                    -- Once both results are complete, start UART
                    if enc_done = '1' and dec_done = '1' then
                        led_reg                 <= LED_FLASH;
                        uart_byte_count         <= (others => '0');
                        state_reg               <= UART_LOAD_BYTE;
                        
                    end if;
                    
                -- Load UART byte
                when UART_LOAD_BYTE =>
                    uart_tx_data        <= get_uart_byte( 
                                                uart_byte_count,
                                                enc_out_0,
                                                enc_out_1,
                                                enc_out_2,
                                                enc_out_3,
                                                
                                                dec_out_0,
                                                dec_out_1,
                                                dec_out_2,
                                                dec_out_3
                                                );
                    state_reg           <= UART_START_TX;
                    
                -- Start UART transmission
                when UART_START_TX =>
                    if uart_tx_busy = '0' then
                        uart_tx_ena             <= '1';
                        state_reg               <= UART_WAIT_BUSY;
                    end if;
                    
                
                -- UART wait
                when UART_WAIT_BUSY =>
                    if uart_tx_busy = '1' then
                        state_reg   <= UART_WAIT_DONE;
                    end if;
                    
                -- UART done waiting
                when UART_WAIT_DONE =>
                    if uart_tx_busy = '0' then
                        if uart_byte_count = to_unsigned(31, uart_byte_count'length) then
                            uart_byte_count     <= (others => '0');
                            state_reg           <= DONE;
                        else
                            uart_byte_count     <= uart_byte_count + 1;
                            state_reg           <= UART_LOAD_BYTE;
                        end if;
                    end if;
                    
                when DONE =>
                    state_reg       <= DONE;
                    
                when others =>
                
                    state_reg       <= WAIT_RESULTS;
                    
            end case;
        end if;    
    end process;
        
end Behavioral;
