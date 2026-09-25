-- Included libraries
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Entity Name: Mini Router
-- Description: Contains logic to determine next byte into XTEA block
entity minirouter is
    Port (clk:              IN  STD_LOGIC;
          reset_n:          IN  STD_LOGIC;
          
          -- IP Enc data and request
          data1:            IN  STD_LOGIC_VECTOR(9 downto 0);
          req1:             IN  STD_LOGIC;
          
          -- IP Dec data and request
          data2:            IN  STD_LOGIC_VECTOR(9 downto 0);
          req2:             IN  STD_LOGIC;
          
          -- Grant signals for IP Enc and Dec
          grant1:           OUT STD_LOGIC;
          grant2:           OUT STD_LOGIC;
          
          -- Data out (1 enc/dec select bit and 8 bits of data)
          data_out:         OUT STD_LOGIC_VECTOR (8 downto 0);   
          
          -- Data out valid flag 
          valid:            OUT STD_LOGIC          
          );
end minirouter;

architecture Behavioral of minirouter is

    -- Round-robin select
    -- '0' when link 1 wins the next equal priority conflict
    -- '1' when link 2 wins the next equal priority conflict
    signal rr_select:           STD_LOGIC := '0';
    
begin
    process (clk) 
    
    -- Set variables to assign priority bits from data1 and data2
    variable priority1:     unsigned(1 downto 0);
    variable priority2:     unsigned(1 downto 0);  
    
    begin
        if rising_edge(clk) then 
        
            -- Active-low synchronous reset
            if reset_n = '0' then
                -- Reset values
                data_out        <= (others => '0');
                valid           <= '0';
                grant1          <= '0';
                grant2          <= '0';
                rr_select       <= '0';
                
            elsif reset_n = '1' then
            
                -- Default values
                data_out        <= (others => '0');
                valid           <= '0';
                grant1          <= '0';
                grant2          <= '0';
                
                -- Assign priority variables upper 2 bits from data
                priority1       := unsigned(data1(9 downto 8));
                priority2       := unsigned(data2(9 downto 8));
                
                -- Logic to assign data out depending on priority
                -- If only one link is requesting, grant immediately
                -- If both links request but one has higher priority, grant to higher priority
                -- If both links request and have the same priority, execute round robin to determine grant
                -- If none are requesting, send no grant and make valid low
                -- '0' in data_out indicates value came from data 1, '1' indicates it came from data2
                
                -- Only link 1 is requesting
                if req1 = '1' and req2 = '0' then
                    data_out        <= '0' & data1(7 downto 0);
                    valid           <= '1';
                    grant1          <= '1';
                    
                -- Only link 2 is requesting
                elsif req1 = '0' and req2 = '1' then
                    data_out        <= '1' & data2(7 downto 0);
                    valid           <= '1';
                    grant2          <= '1';
                    
                 -- Both links are requesting
                 elsif req1 = '1' and req2 = '1' then
                    
                    -- Link 1 has higher priority
                    if priority1 > priority2 then
                        data_out    <= '0' & data1(7 downto 0);
                        valid       <= '1';
                        grant1      <= '1';
                    
                    -- Link 2 has higher priority    
                    elsif priority1 < priority2 then
                        data_out    <= '1' & data2(7 downto 0);
                        valid       <= '1';
                        grant2      <= '1';
                        
                    -- Equal priority, round-robin to resolve conflict
                    else
                        if rr_select = '0' then
                            data_out        <= '0' & data1(7 downto 0);
                            valid           <= '1';
                            grant1          <= '1';
                            rr_select       <= '1';
                            
                        else
                            data_out        <= '1' & data2(7 downto 0);
                            valid           <= '1';
                            grant2          <= '1';
                            rr_select       <= '0';
                            
                        end if;
                    end if;
                end if;
            end if;
       end if;
    
    end process;

end Behavioral;
