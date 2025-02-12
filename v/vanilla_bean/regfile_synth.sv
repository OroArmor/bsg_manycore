/**
 *    regfile_synth.v
 *
 *    synthesized register file
 *
 *    @author tommy
 */

`include "bsg_defines.sv"

module regfile_synth
  #(`BSG_INV_PARAM(width_p)
    , `BSG_INV_PARAM(els_p)
    , `BSG_INV_PARAM(num_rs_p)
    , `BSG_INV_PARAM(num_ws_p)
    , `BSG_INV_PARAM(x0_tied_to_zero_p)

    , localparam addr_width_lp=`BSG_SAFE_CLOG2(els_p)
  )
  (
    input clk_i
    , input reset_i

    , input [num_ws_p-1:0] w_v_i
    , input [num_ws_p-1:0][addr_width_lp-1:0] w_addr_i
    , input [num_ws_p-1:0][width_p-1:0] w_data_i
    
    , input [num_rs_p-1:0] r_v_i
    , input [num_rs_p-1:0][addr_width_lp-1:0] r_addr_i
    , output logic [num_rs_p-1:0][width_p-1:0] r_data_o
  );

  wire unused = reset_i;
  
  logic [num_rs_p-1:0][addr_width_lp-1:0] r_addr_r;


  always_ff @ (posedge clk_i)
    for (integer i = 0; i < num_rs_p; i++)
      if (r_v_i[i]) r_addr_r[i] <= r_addr_i[i];



  if (x0_tied_to_zero_p) begin: xz
    // x0 is tied to zero.
    logic [width_p-1:0] mem_r [els_p-1:1];
    
    for (genvar i = 0; i < num_rs_p; i++)
      assign r_data_o[i] = (r_addr_r[i] == '0)? '0 : mem_r[r_addr_r[i]];

    always_ff @ (posedge clk_i)
      for (integer i = 0; i < num_ws_p; i++)
        if (w_v_i[i] & (w_addr_i[i] != '0))
            mem_r[w_addr_i[i]] <= w_data_i[i];


  end
  else begin: xnz
    // x0 is not tied to zero.
    logic [width_p-1:0] mem_r [els_p-1:0];
   
    for (genvar i = 0; i < num_rs_p; i++)
      assign r_data_o[i] = mem_r[r_addr_r[i]];

    always_ff @ (posedge clk_i)
      for (integer i = 0; i < num_ws_p; i++)
        if (w_v_i[i])
          mem_r[w_addr_i[i]] <= w_data_i[i];
    
  end


endmodule

`BSG_ABSTRACT_MODULE(regfile_synth)
