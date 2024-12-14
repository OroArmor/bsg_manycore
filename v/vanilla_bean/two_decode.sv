`include "bsg_vanilla_defines.svh"


// Module to input two instructions and decode both. Determines
// if the instructions can be issued in parallel.
module two_decode
import bsg_vanilla_pkg::*;
import bsg_manycore_pkg::*;
(
    input instruction_s instruction1_i
    , input instruction_s instruction2_i
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
    4. The second instruction is a branch/jump instruction
    5. RAW, WAW, and WAR dependencies with FP load and FP op
*/
logic two_normal;
logic two_fp;
logic second_branch;
logic raw;
logic war;
logic waw;

assign two_normal = (~decode1_r.is_fp_op) & (~decode2_r.is_fp_op);
assign two_fp = decode1_r.is_fp_op & decode2_r.is_fp_op;
assign second_b_or_jmp = (decode2_r.is_branch_op | decode2_r.is_jal_op | decode2_r.is_jalr_op);

// check if the dst register from a load is the same as any source or dst of an fpop
assign raw = // if the first instr writes to and second instr reads from same register
assign war = // if the first instr reads from and the second instr writes to same register
assign waw = //dst registers match in the case where we have both a fp_load and fp_op
// way to check for raw, 

assign dual_issue_o = ~(two_normal | two_fp | second_b_or_jmp | raw | war | waw);

// logic for decode_o and fp_decode_o outputs 
if (dual_issue_o) begin
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


