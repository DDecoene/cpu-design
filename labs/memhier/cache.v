// FILE: memhier/cache.v
// Een direct-mapped cache voor 8-bit adressen: 16 regels van 4 bytes (64 bytes in totaal).
// Adres: [7:6] tag, [5:2] index (regel), [1:0] plaats in de regel. Write-through, geen allocatie bij schrijven.

// Langzaam hoofdgeheugen: elke bewerking duurt LAT klokcycli.
module slowmem #(parameter LAT = 4) (
  input             clk,
  input             start,
  input             we,
  input      [7:0]  addr,
  input      [7:0]  wdata,
  output reg        done,
  output reg [31:0] line      // 4 bytes vanaf het (op 4 uitgelijnde) adres
);
  reg [7:0] mem [0:255];
  reg       busy, we_l;
  reg [7:0] a_l, w_l;
  integer   cnt;
  initial begin busy = 0; done = 0; cnt = 0; end

  always @(posedge clk) begin
    done <= 1'b0;
    if (start) begin
      busy <= 1'b1; cnt <= LAT; we_l <= we; a_l <= addr; w_l <= wdata;
    end else if (busy) begin
      cnt <= cnt - 1;
      if (cnt == 1) begin
        busy <= 1'b0; done <= 1'b1;
        if (we_l) mem[a_l] <= w_l;
        else      line <= {mem[{a_l[7:2], 2'd3}], mem[{a_l[7:2], 2'd2}], mem[{a_l[7:2], 2'd1}], mem[{a_l[7:2], 2'd0}]};
      end
    end
  end
endmodule

module cache #(parameter LAT = 4) (
  input            clk,
  input            rst_n,
  input            req,         // houd req vast tot ready verschijnt
  input            we,
  input      [7:0] addr,
  input      [7:0] wdata,
  output reg [7:0] rdata,
  output reg       ready,       // één klokperiode hoog als de aanvraag klaar is
  output reg [31:0] hits,
  output reg [31:0] misses
);
  localparam IDLE = 2'd0, WAIT_R = 2'd1, WAIT_W = 2'd2;

  reg [31:0] data  [0:15];      // elke regel: 4 bytes
  reg [1:0]  tag   [0:15];
  reg [15:0] valid;
  reg [1:0]  state;
  reg [7:0]  a_l, w_l;          // vastgelegde aanvraag tijdens het wachten
  reg        bm_start, bm_we;
  reg [7:0]  bm_addr, bm_wdata;
  wire       bm_done;
  wire [31:0] bm_line;

  slowmem #(LAT) backing(clk, bm_start, bm_we, bm_addr, bm_wdata, bm_done, bm_line);

  wire [3:0] idx = addr[5:2];
  wire [1:0] off = addr[1:0];
  wire [1:0] tg  = addr[7:6];
  wire       hit = valid[idx] && (tag[idx] == tg);

  function [7:0] pick(input [31:0] l, input [1:0] o);
    pick = l >> (8 * o);
  endfunction

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      state <= IDLE; valid <= 16'h0000; ready <= 0; bm_start <= 0; hits <= 0; misses <= 0; rdata <= 0;
    end else begin
      ready <= 1'b0;
      bm_start <= 1'b0;
      case (state)
        IDLE: if (req && !ready) begin
          a_l <= addr; w_l <= wdata;
          if (we) begin
            // write-through: altijd naar het hoofdgeheugen schrijven
            bm_start <= 1; bm_we <= 1; bm_addr <= addr; bm_wdata <= wdata;
            state <= WAIT_W;
          end else if (hit) begin
            hits <= hits + 1;
            rdata <= pick(data[idx], off);
            ready <= 1'b1;
          end else begin
            misses <= misses + 1;
            bm_start <= 1; bm_we <= 0; bm_addr <= {addr[7:2], 2'b00};
            state <= WAIT_R;
          end
        end
        WAIT_R: if (bm_done) begin
          data[a_l[5:2]] <= bm_line;
          tag[a_l[5:2]]  <= a_l[7:6];
          valid[a_l[5:2]] <= 1'b1;
          rdata <= pick(bm_line, a_l[1:0]);
          ready <= 1'b1;
          state <= IDLE;
        end
        WAIT_W: if (bm_done) begin
          // bij een treffer ook de regel in de cache bijwerken
          if (valid[a_l[5:2]] && tag[a_l[5:2]] == a_l[7:6]) begin
            case (a_l[1:0])
              2'd0: data[a_l[5:2]][7:0]   <= w_l;
              2'd1: data[a_l[5:2]][15:8]  <= w_l;
              2'd2: data[a_l[5:2]][23:16] <= w_l;
              2'd3: data[a_l[5:2]][31:24] <= w_l;
            endcase
          end
          ready <= 1'b1;
          state <= IDLE;
        end
        default: state <= IDLE;
      endcase
    end
endmodule
