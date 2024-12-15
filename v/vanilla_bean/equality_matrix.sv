/**
 *    equality_matrix.sv
 *
 *    @author tommy
 */

`include "bsg_defines.sv"

module equality_matrix
  #(`BSG_INV_PARAM(width_p)
    , `BSG_INV_PARAM(num_col_p)
    , `BSG_INV_PARAM(num_row_p)
  )
  (
    input [num_col_p-1:0][width_p-1:0] col_i
    , input [num_row_p-1:0][width_p-1:0] row_i
    
    , output logic [num_col_p-1:0][num_row_p-1:0] eq_o
  );

  for (genvar i = 0; i < num_col_p; i++)
    for (genvar j = 0; j < num_row_p; j++)
      assign eq_o[i][j] = col_i[i] == row_i[j];

endmodule

`BSG_ABSTRACT_MODULE(equality_matrix)
