`include "bsg_vanilla_defines.svh"


// Module to input two instructions and decode both. Determines
// if the instructions can be issued in parallel.
module two_decode
import bsg_vanilla_pkg::*;
import bsg_manycore_pkg::*;
(
    input instruction_s instruction1_i
    , input instruction_s instruction2_i
    , input instruction2_i_v
    , output instruction_s instruction
    , output instruction_s instruction_f
    , output decode_s decode_o
    , output fp_decode_s fp_decode_o
    , output logic dual_issue_o
);

decode_s decode1_r;
decode_s decode2_r;
fp_decode_s fp_decode1_r;
fp_decode_s fp_decode2_r;

cl_decode decode0 (
    .instruction_i(instruction1_i)
    ,.decode_o(decode1_r)
    ,.fp_decode_o(fp_decode1_r)
);

cl_decode decode1 (
    .instruction_i(instruction2_i)
    ,.decode_o(decode2_r)
    ,.fp_decode_o(fp_decode2_r)
);

/* Determine if dual-issue is possible. Cases in which dual_issue
should be 0 (single-issue execution):
    1. Two normal (int like) instructions
    2. Two floating point instructions
    3. Fp load and store at same time (Should be already handled in case 1)
    4. The first instruction is a branch/jump instruction
    5. RAW, WAW, and WAR dependencies with FP load and FP op
*/
logic two_normal;
logic two_fp;
logic second_branch;
logic raw;
logic raw_f;
logic war;
logic war_f;
logic waw;

assign two_normal = (~decode1_r.is_fp_op) & (~decode2_r.is_fp_op);
assign two_fp = decode1_r.is_fp_op & decode2_r.is_fp_op;
assign first_b_or_jmp = (decode1_r.is_branch_op | decode1_r.is_jal_op | decode1_r.is_jalr_op);

// fp only reads integers from rs1
// note that fp loads are considered int operations
// note that fp comparisons write to an int register

// if first instr writes to int, and second instr reads from same int reg (only case possible is first instruction is an int op, second instruction is a fp load (or fp store?))
// (another possible case, first instruction is a fp comparison, second instruction is a fp load)
// case 1: fp op is writing to int reg (fp comparisons), then int op is reading from that same reg
// case 2: int op is writing to int reg, then fp op (fp load) is reading from that same reg (only can read from rs1)
assign raw = (decode1_r.write_rd_f & (((instruction1_i.rd == instruction2_i.rs1) & decode2_r.read_rs1) | ((instruction1_i.rd == instruction2_i.rs2) & decode2_r.read_rs2)))
             | (decode1_r.write_rd & (instruction1_i.rd == instruction2_i.rs1) & decode2_r.read_rs1_f);

// if first instr writes to fp, and second instr reads from same fp reg
// case 1: fp op is writing to fp reg, then int op is reading from that same reg (Only case is fp store, which reads from frs2)
// case 2: int op is writing to fp reg (only fp load) then fp op is reading from that same reg
assign raw_f = (decode1_r.write_frd & ((instruction1_i.rd == instruction2_i.rs2) & decode2_r.read_frs2_s))  // first instruction is fp op write, second instruction (fp store) rs2 matches rd OR
                | (decode1_r.write_frd_l & (((instruction1_i.rd == instruction2_i.rs1) & decode2_r.read_frs1) | ((instruction1_i.rd == instruction2_i.rs2) & decode2_r.read_frs2) | ((instruction1_i.rd == instruction2_i[31:27]) & decode2_r.read_frs3)));

// if the first instr reads from and the second instr writes to same int register
// case 1: fp op reads from int register (only rs1), then int op writes to int register
// csae 2: int op reads from int register, then fp op writes to int register (fp comparison)
assign war = (decode1_r.read_rs1_f & ((instruction1_i.rs1 == instruction2_i.rd) & decode2_r.write_rd)) //fp op reads from rs1 and then int op writes to same int register OR
             | (decode1_r.read_rs1 & ((instruction1_i.rs1 == instruction2_i.rd) & decode2_r.write_rd_f)) // int op reads from rs1 and then fp op writes to same int register OR
             | (decode1_r.read_rs2 & ((instruction1_i.rs2 == instruction2_i.rd) & decode2_r.write_rd_f)); // int op reads from rs2 and then fp op writes to same int register

// if the first instr reads from and the second instr writes to the same fp register
// case 1: fp op reads from fp register, then int op writes to same fp register (only fp load)
// case 2: int op reads from fp register (only fp store from frs2), then fp op writes to same fp register
assign war_f = (decode2_r.write_frd_l & (((instruction2_i.rd == instruction1_i.rs1) & decode1_r.read_frs1) | ((instruction2_i.rd == instruction1_i.rs2) & decode1_r.read_frs2) | ((instruction2_i.rd == instruction1_i[31:27]) & decode1_r.read_frs3)))
               | (decode1_r.read_frs2_s & (instruction2_i.rd == instruction1_i.rs2) & decode2_r.write_frd); // int op reads from frs2 and fp op writes to same fp reg


// dst registers match in the case where both instructions are writing to the fp regfile
assign waw = (instruction1_i.rd == instruction2_i.rd) // rd matches AND
             & (((decode1_r.write_frd | decode1_r.write_frd_l) & (decode2_r.write_frd | decode2_r.write_frd_l)) // both instructions are trying to write to fp reg OR
             | ((decode1_r.write_rd | decode1_r.write_rd_f) & (decode2_r.write_rd | decode2_r.write_rd_f))); // both instructions are trying to write to int reg

assign dual_issue_o = ~(two_normal | two_fp | first_b_or_jmp | raw | raw_f | war | war_f | waw);

always_comb begin
  // logic for decode_o and fp_decode_o outputs 
  if (dual_issue_o && instruction2_i_v) begin
      instruction = decode1_r.is_fp_op ? instruction2_i : instruction1_i;
      instruction_f = decode1_r.is_fp_op ? instruction1_i : instruction2_i;
      decode_o = decode1_r | decode2_r; // combine the decode control signals of the two instructions
      //decode_o = decode1_r.is_fp_op ? decode2_r : decode1_r;
      fp_decode_o = decode1_r.is_fp_op ? fp_decode1_r : fp_decode2_r; 
  end
  else begin
      instruction = instruction1_i;
      instruction_f = instruction1_i;
      decode_o = decode1_r;
      fp_decode_o = fp_decode1_r;
  end
end

endmodule
