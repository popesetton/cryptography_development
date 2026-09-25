`timescale 1ns / 1ps

// Module name: Encrypt / Decrypt testbench
// Description: Tests both mini router and XTEA implementation
//              Contains IP Encryption and Decryption generators
module enc_dec_testbench;

    // Clock and reset
    logic           clk;
    logic           reset_n;
    
    // Router inputs
    // Encryption
    logic [9:0]     data1;
    logic           req1;
    
    // Decryption
    logic [9:0]     data2;
    logic           req2;
    
    // Router outputs
    logic           grant1;
    logic           grant2;
    
    // XTEA outputs from cryptosystem topfile
    logic [31:0]    ciphertext_word_out;
    logic           ciphertext_ready;
    logic [31:0]    data_word_out;
    logic           data_ready;
    
    // Router test trackers
    int pass_count;
    int fail_count;
    
    // Expected output for XTEA
    logic [31:0] expected_ciphertext [0:3];
    logic [31:0] expected_plaintext  [0:3];
    
    initial begin
        expected_ciphertext[0] = 32'h7409807B;
        expected_ciphertext[1] = 32'hCC3B0E75;
        expected_ciphertext[2] = 32'h9EFD53A8;
        expected_ciphertext[3] = 32'hAEA16A76;
    
        expected_plaintext[0] = 32'hA5A5A5A5;
        expected_plaintext[1] = 32'h01234567;
        expected_plaintext[2] = 32'hFEDCBA98;
        expected_plaintext[3] = 32'h5A5A5A5A;
    end
    
    // DUT instantiation
    cryptosystem_topfile dut(.clk                   (clk),
                             .reset_n               (reset_n),
                             .data1                 (data1),
                             .req1                  (req1),
                             .data2                 (data2),
                             .req2                  (req2),
                             .grant1                (grant1),
                             .grant2                (grant2),
                             .ciphertext_word_out   (ciphertext_word_out),
                             .ciphertext_ready      (ciphertext_ready),
                             .data_word_out         (data_word_out),
                             .data_ready            (data_ready)
                             );
                   
   // Clock generation (100 MHz clock)
   initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end
    
    // Automatically test router selection agaisnt expected data
    task automatic apply_case (
        input string         case_name,
    
        input logic          enc_req,
        input logic [1:0]    enc_priority,
        input logic [7:0]    enc_data,
    
        input logic          dec_req,
        input logic [1:0]    dec_priority,
        input logic [7:0]    dec_data,
    
        input logic          exp_grant1,
        input logic          exp_grant2
    );
    begin
        @(negedge clk);
    
        req1  = enc_req;
        data1 = {enc_priority, enc_data};
    
        req2  = dec_req;
        data2 = {dec_priority, dec_data};
    
        @(posedge clk);
        #1;
    
        if (grant1 === exp_grant1 && grant2 === exp_grant2) begin
            $display("[PASS] %s", case_name);
            pass_count++;
        end else begin
            $display("[FAIL] %s", case_name);
    
            $display("       Inputs:");
            $display("       req1=%0b data1={priority=%0d,payload=0x%02h}",
                     enc_req, enc_priority, enc_data);
            $display("       req2=%0b data2={priority=%0d,payload=0x%02h}",
                     dec_req, dec_priority, dec_data);
    
            $display("       Expected: grant1=%0b grant2=%0b",
                     exp_grant1, exp_grant2);
            $display("       Got:      grant1=%0b grant2=%0b",
                     grant1, grant2);
    
            fail_count++;
        end
    end
    endtask
                         
    // Automatically send encryption data
    task automatic send_enc_byte(
        input logic [1:0] priority_bits,
        input logic [7:0] payload
    );
    begin
        @(negedge clk);
        data1 = {priority_bits, payload};
        req1  = 1'b1;
        data2 = 10'd0;
        req2  = 1'b0;
    
        @(posedge clk);
        #1;
    
        @(negedge clk);
        req1 = 1'b0;
    end
    endtask
    
    // Automatically send decryption data
    task automatic send_dec_byte(
        input logic [1:0] priority_bits,
        input logic [7:0] payload
    );
    begin
        @(negedge clk);
        data2 = {priority_bits, payload};
        req2  = 1'b1;
        data1 = 10'd0;
        req1  = 1'b0;
    
        @(posedge clk);
        #1;
    
        @(negedge clk);
        req2  = 1'b0;
        data2 = 10'd0;
    end
    endtask
    
    // Automatically test encrypted data
    task automatic check_encryption_output;
        int i;
        int timeout;
    begin
        i = 0;
        timeout = 0;
    
        $display("Checking XTEA encryption output...");
    
        while (i < 4 && timeout < 1000) begin
            @(posedge clk);
            #1;
            timeout++;
    
            if (ciphertext_ready === 1'b1) begin
                if (ciphertext_word_out === expected_ciphertext[i]) begin
                    $display("[PASS] Encryption output word %0d = %08h",
                             i, ciphertext_word_out);
                    pass_count++;
                end else begin
                    $display("[FAIL] Encryption output word %0d", i);
                    $display("       Expected: %08h", expected_ciphertext[i]);
                    $display("       Got:      %08h", ciphertext_word_out);
                    fail_count++;
                end
    
                i++;
            end
        end
    
        if (i < 4) begin
            $display("[FAIL] Encryption timed out. Only received %0d / 4 words.", i);
            fail_count++;
        end
    end
    endtask
    
    // Automatically check decryption module
    task automatic check_decryption_output;
        int i;
        int timeout;
    begin
        i = 0;
        timeout = 0;
    
        $display("Checking XTEA decryption output...");
    
        while (i < 4 && timeout < 1000) begin
            @(posedge clk);
            #1;
            timeout++;
    
            if (data_ready === 1'b1) begin
                if (data_word_out === expected_plaintext[i]) begin
                    $display("[PASS] Decryption output word %0d = %08h",
                             i, data_word_out);
                    pass_count++;
                end else begin
                    $display("[FAIL] Decryption output word %0d", i);
                    $display("       Expected: %08h", expected_plaintext[i]);
                    $display("       Got:      %08h", data_word_out);
                    fail_count++;
                end
    
                i++;
            end
        end
    
        if (i < 4) begin
            $display("[FAIL] Decryption timed out. Only received %0d / 4 words.", i);
            fail_count++;
        end
    end
    endtask
    
    // Main stimulus
    initial begin
        // Pass and fail trackers
        pass_count      = 0;
        fail_count      = 0;
        
        // Initial values
        reset_n         = 1'b0;
        req1            = 1'b0;
        req2            = 1'b0;
        data1           = 10'd0;
        data2           = 10'd0;
        
        // Hold active low reset for a few clock cycles
        repeat (3) @(posedge clk);
        
        // Release reset
        @(negedge clk);
        reset_n = 1'b1;
        
        @(posedge clk);
        #1;
        
        /*
            Mini router test
            Tests priority and round-robin conflict resolution by encrypting one word for encryption and one word for decryption
            Two tests for no requests
        */
        $display("Starting Mini Router Testbench");
        
        // No request
        apply_case(
            "Check 01: No request after reset",
            1'b0, 2'd0, 8'h00,
            1'b0, 2'd0, 8'h00,
            1'b0, 1'b0
        );
        
        // Only enc requests
        apply_case(
            "Check 02: Enc byte 0, Enc only",
            1'b1, 2'd0, 8'hA5,
            1'b0, 2'd0, 8'h74,
            1'b1, 1'b0
        );
        
        // Only dec requests
        apply_case(
            "Check 03: Dec byte 0, Dec only",
            1'b0, 2'd0, 8'hA5,
            1'b1, 2'd0, 8'h74,
            1'b0, 1'b1
        );
        
        // Enc higher priority
        apply_case(
            "Check 04: Enc byte 1, Enc higher priority",
            1'b1, 2'd3, 8'hA5,
            1'b1, 2'd1, 8'h09,
            1'b1, 1'b0
        );
                
        // Dec higher priority
        apply_case(
            "Check 05: Dec byte 1, Dec higher priority",
            1'b1, 2'd1, 8'hA5,
            1'b1, 2'd3, 8'h09,
            1'b0, 1'b1
        );
        
        // Equal priority, enc wins
        apply_case(
            "Check 06: Enc byte 2, equal priority round-robin gives Enc",
            1'b1, 2'd2, 8'hA5,
            1'b1, 2'd2, 8'h80,
            1'b1, 1'b0
        );
 
        // Equal priority, dec wins
        apply_case(
            "Check 07: Dec byte 2, equal priority round-robin gives Dec",
            1'b1, 2'd2, 8'hA5,
            1'b1, 2'd2, 8'h80,
            1'b0, 1'b1
        );
        
        // No request
        apply_case(
            "Check 08: No request between transfers",
            1'b0, 2'd1, 8'h00,
            1'b0, 2'd1, 8'h00,
            1'b0, 1'b0
        );
        
        // Enc higher priority
        apply_case(
            "Check 09: Enc byte 3, Enc higher priority",
            1'b1, 2'd2, 8'hA5,
            1'b1, 2'd0, 8'h7B,
            1'b1, 1'b0
        );
        
        // Dec higher priority
        apply_case(
            "Check 10: Dec byte 3, Dec higher priority",
            1'b1, 2'd0, 8'hA5,
            1'b1, 2'd2, 8'h7B,
            1'b0, 1'b1
        );       
        
        // Display testbench finished on console
        $display("Mini Router Testbench Finished");
        $display("Passed: %0d", pass_count);
        $display("Failed: %0d", fail_count);
        
        if (fail_count == 0) begin
            $display("ALL TESTS PASSED");
        end else begin
            $display("SOME TESTS FAILED");
        end
        
        $display("Begin XTEA Test");
        $display("Loading Rest of Data...");
        
        // Send remaining plaintext words for encryption
        // 01234567 FEDCBA98 5A5A5A5A
        send_enc_byte(2'd1, 8'h01);
        send_enc_byte(2'd1, 8'h23);
        send_enc_byte(2'd1, 8'h45);
        send_enc_byte(2'd1, 8'h67);
        
        send_enc_byte(2'd1, 8'hFE);
        send_enc_byte(2'd1, 8'hDC);
        send_enc_byte(2'd1, 8'hBA);
        send_enc_byte(2'd1, 8'h98);
        
        send_enc_byte(2'd1, 8'h5A);
        send_enc_byte(2'd1, 8'h5A);
        send_enc_byte(2'd1, 8'h5A);
        send_enc_byte(2'd1, 8'h5A);
        
        // Send remaining ciphertext words for decryption
        // CC3B0E75 9EFD53A8 AEA16A76
        send_dec_byte(2'd1, 8'hCC);
        send_dec_byte(2'd1, 8'h3B);
        send_dec_byte(2'd1, 8'h0E);
        send_dec_byte(2'd1, 8'h75);
        
        send_dec_byte(2'd1, 8'h9E);
        send_dec_byte(2'd1, 8'hFD);
        send_dec_byte(2'd1, 8'h53);
        send_dec_byte(2'd1, 8'hA8);
        
        send_dec_byte(2'd1, 8'hAE);
        send_dec_byte(2'd1, 8'hA1);
        send_dec_byte(2'd1, 8'h6A);
        send_dec_byte(2'd1, 8'h76);
        
        @(negedge clk);
        req1    = 1'b0;
        req2    = 1'b0;
        data1   = 10'd0;
        data2   = 10'd0;
        
        // Check XTEA encryption outputs
        check_encryption_output();  
            
        // Check XTEA decryption outputs
        check_decryption_output();
        
        $finish;
     
    end       
endmodule
