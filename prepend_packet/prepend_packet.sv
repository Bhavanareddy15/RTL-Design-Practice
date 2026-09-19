`timescale 1ns/1ns

// ------------------------------------------------------------------
// Problem statement
// ------------------------------------------------------------------
// Design a module that prepends a fixed, generic packet header to a
// streaming payload.
//
// The payload arrives 8 bytes (64 bits) per clock, one word per
// cycle, framed by start_of_packet_i/end_of_packet_i. byte_count_i
// is only meaningful on the end-of-packet cycle and encodes
// (valid bytes in that final word - 1), so it ranges 0-7.
//
// The header has three fields:
//   DST_ADDR   - 32 bits (4 bytes) - generic destination address
//   SRC_ADDR   - 32 bits (4 bytes) - generic source address
//   TYPE_FIELD - 32 bits (4 bytes) - generic packet-type/length field
// for a total header size of 12 bytes.
//
// Output the header immediately followed by the (unmodified) input
// payload, on the same 64-bit/cycle streaming interface, with
// start_of_packet_o marking the first header word and
// end_of_packet_o/byte_count_o marking the last payload word.
//
// 12 bytes is NOT a multiple of the 8-byte bus width: DST_ADDR and
// SRC_ADDR together exactly fill the first output word (4+4=8), but
// TYPE_FIELD (4 bytes) is left over and must be carried into the
// next word, permanently shifting every later payload word by 4
// bytes (32 bits) relative to its input alignment. That constant
// 32-bit "carry" is combined with each incoming word to produce the
// next output word, and needs one extra "flush" cycle at packet end
// to drain out whatever is still sitting in the carry register
// whenever the final input word doesn't have enough valid bytes to
// absorb it directly (12 mod 8 = 4 != 0).
// ------------------------------------------------------------------

module prepend_packet_header #(
    parameter [31:0] DST_ADDR   = 32'hAABBCCDD,
    parameter [31:0] SRC_ADDR   = 32'h00112233,
    parameter [31:0] TYPE_FIELD = 32'h2A2A2A2A
)(
    input  wire        clk_i,
    input  wire        rst_i,             // synchronous, active-high

    input  wire         start_of_packet_i, // High for one clock cycle when packet starts
    input  wire         end_of_packet_i,   // High for one clock cycle when packet ends
    input  wire [63:0]  data_i,            // Valid data every cycle from start to end of packet
    input  wire [2:0]   byte_count_i,      // Valid only when end_of_packet_i is high. (valid bytes - 1)

    output wire         start_of_packet_o,
    output wire         end_of_packet_o,
    output wire [63:0]  data_o,
    output wire [2:0]   byte_count_o
);

    reg        start_o_r = 1'b0, end_o_r = 1'b0;
    reg [63:0] data_o_r = 64'b0;
    reg [2:0]  byte_count_o_r = 3'b0;

    reg [63:0] data_i_reg = 64'b0;   // data_i delayed by one cycle
    reg [31:0] carry_r = 32'b0;      // 4 pending bytes (from header tail or previous word)

    reg        pending_end = 1'b0;    // end_of_packet_i was seen last cycle, decide output now
    reg        pending_flush = 1'b0;  // an extra drain cycle is required after pending_end
    reg [2:0]  flush_count_r = 3'b0;  // byte_count_o to use on the flush cycle
    reg [3:0]  end_c_r = 4'b0;        // captured valid-byte count (1-8) of the last word
    reg        packet_active = 1'b0;  // a packet is currently in flight (between start and end)

    assign start_of_packet_o = start_o_r;
    assign end_of_packet_o   = end_o_r;
    assign data_o            = data_o_r;
    assign byte_count_o      = byte_count_o_r;

    always @(posedge clk_i) begin
        // defaults each cycle
        start_o_r      <= 1'b0;
        end_o_r        <= 1'b0;
        byte_count_o_r <= 3'b0;

        if (rst_i) begin
            data_o_r      <= 64'b0;
            carry_r       <= 32'b0;
            data_i_reg    <= 64'b0;
            pending_end   <= 1'b0;
            pending_flush <= 1'b0;
            packet_active <= 1'b0;
        end
        else if (start_of_packet_i) begin
            // First output word next cycle = pure header bytes 0-7
            // (DST_ADDR+SRC_ADDR exactly fill one word).
            data_o_r      <= {DST_ADDR, SRC_ADDR};
            start_o_r     <= 1'b1;
            carry_r       <= TYPE_FIELD;   // header bytes 8-11
            data_i_reg    <= data_i;       // stash W0
            pending_end   <= 1'b0;
            pending_flush <= 1'b0;
            packet_active <= 1'b1;
        end
        else if (pending_flush) begin
            // Drain cycle: only the carried bytes are valid, the rest of
            // the word has no new data behind it and must be zero.
            data_o_r       <= {carry_r, 32'b0};
            end_o_r        <= 1'b1;
            byte_count_o_r <= flush_count_r;
            pending_flush  <= 1'b0;
            packet_active  <= 1'b0;
        end
        else if (pending_end) begin
            // Decide whether the word now leaving the pipe is the last
            // one, or whether one more flush cycle will be needed.
            if (end_c_r <= 4'd4) begin
                // Only end_c_r of the 4 extra bytes (data_i_reg[63:32])
                // are valid; zero the rest instead of leaking stale bits.
                case (end_c_r)
                    4'd1:    data_o_r <= {carry_r, data_i_reg[63:56], 24'b0};
                    4'd2:    data_o_r <= {carry_r, data_i_reg[63:48], 16'b0};
                    4'd3:    data_o_r <= {carry_r, data_i_reg[63:40], 8'b0};
                    default: data_o_r <= {carry_r, data_i_reg[63:32]}; // end_c_r==4, fully valid
                endcase
                end_o_r        <= 1'b1;
                byte_count_o_r <= 3'd3 + end_c_r[2:0];  // 4-7 valid bytes
                pending_flush  <= 1'b0;
                packet_active  <= 1'b0;
            end else begin
                data_o_r       <= {carry_r, data_i_reg[63:32]};  // fully valid; flush drains the rest
                end_o_r        <= 1'b0;
                pending_flush  <= 1'b1;
                flush_count_r  <= end_c_r[2:0] - 3'd5;  // (c-4)-1 valid bytes
            end
            carry_r     <= data_i_reg[31:0];
            pending_end <= 1'b0;
        end
        else if (packet_active) begin
            // Normal mid-packet cycle (also the cycle end_of_packet_i arrives on).
            data_o_r   <= {carry_r, data_i_reg[63:32]};
            carry_r    <= data_i_reg[31:0];
            data_i_reg <= data_i;
            if (end_of_packet_i) begin
                pending_end <= 1'b1;
                end_c_r     <= {1'b0, byte_count_i} + 4'd1;  // valid byte count, 1-8
            end
        end
        else begin
            // Truly idle: no packet in flight, output must read as zero.
            data_o_r <= 64'b0;
        end
    end

endmodule
