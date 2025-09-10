// IEEE 802.3-2022 82.2.8
// 40GBASE-R alignment marker decoder
// Calculates BIP, compares with received value,
// and removes alignment markers from datastream


module alignment_extractor #(
  parameter LANE_NUMBER=0
)(
  input  logic        clk,
  input  logic        reset,

  input  logic [65:0] block_in,
  output logic        marker_detect,
  output logic        bip_valid
);

  logic [7:0]  BIP, BIP_mux;
  logic [65:0] XB;

  assign XB = block_in;
  assign BIP_mux = marker_detect ? '0 : BIP;
  assign bip_valid = ({block_in[65:58],block_in[33:26]} == {~BIP,BIP});

  // marker detection
  case (LANE_NUMBER)
    0: assign marker_detect = ({block_in[57:34],block_in[25:0]} == {24'hB8896F,24'h477690,2'b01});
    1: assign marker_detect = ({block_in[57:34],block_in[25:0]} == {24'h193B0F,24'hE6C4F0,2'b01});
    2: assign marker_detect = ({block_in[57:34],block_in[25:0]} == {24'h649A3A,24'h9B65C5,2'b01});
    3: assign marker_detect = ({block_in[57:34],block_in[25:0]} == {24'hC2865D,24'h3D79A2,2'b01});
  endcase

  // BIP calculation
  always_ff @(posedge clk, posedge reset) begin
    if (reset) begin
      BIP <= 0;
    end else begin
      BIP[0] <= ^{BIP_mux[0],XB[2],XB[10],XB[18],XB[26],XB[34],XB[42],XB[50],XB[58]};
      BIP[1] <= ^{BIP_mux[1],XB[3],XB[11],XB[19],XB[27],XB[35],XB[43],XB[51],XB[59]};
      BIP[2] <= ^{BIP_mux[2],XB[4],XB[12],XB[20],XB[28],XB[36],XB[44],XB[52],XB[60]};
      BIP[3] <= ^{BIP_mux[3],XB[0],XB[5],XB[13],XB[21],XB[29],XB[37],XB[45],XB[53],XB[61]};
      BIP[4] <= ^{BIP_mux[4],XB[1],XB[6],XB[14],XB[22],XB[30],XB[38],XB[46],XB[54],XB[62]};
      BIP[5] <= ^{BIP_mux[5],XB[7],XB[15],XB[23],XB[31],XB[39],XB[47],XB[55],XB[63]};
      BIP[6] <= ^{BIP_mux[6],XB[8],XB[16],XB[24],XB[32],XB[40],XB[48],XB[56],XB[64]};
      BIP[7] <= ^{BIP_mux[7],XB[9],XB[17],XB[25],XB[33],XB[41],XB[49],XB[57],XB[65]};
    end
  end

endmodule : alignment_extractor
