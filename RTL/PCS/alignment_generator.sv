// IEEE 802.3-2022 82.2.8
// 40GBASE-R alignment marker encoder
// Calculates BIP, generates pipeline stalls, 
// and encodes alignment markers based on PCS lane number


module alignment_generator #(
  parameter LANE_NUMBER=0
)(
  input  logic        clk,
  input  logic        reset,

  input  logic [65:0] block_in,
  output logic [65:0] marker_out,
  output logic        jam_next_cycle
);

  logic [13:0] block_counter;
  logic [7:0]  BIP, BIP_mux;
  logic [65:0] XB;

  assign jam_next_cycle = &block_counter;
  assign XB = |block_counter ? block_in : marker_out;
  assign BIP_mux = |block_counter ? BIP : '0;

  always_ff @(posedge clk, posedge reset) begin
    if (reset) block_counter <= 0;
    else       block_counter <= block_counter + 1;
  end

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

  //0 0x90, 0x76, 0x47, BIP3 , 0x6F, 0x89, 0xB8, BIP 7
  //1 0xF0, 0xC4, 0xE6, BIP3 , 0x0F, 0x3B, 0x19, BIP 7
  //2 0xC5, 0x65, 0x9B, BIP 3 , 0x3A, 0x9A, 0x64, BIP7
  //3 0xA2, 0x79, 0x3D, BIP3, 0x5D, 0x86, 0xC2, BIP 7
  case (LANE_NUMBER)
    0: assign marker_out = {~BIP,24'hB8896F,BIP,24'h477690,2'b01};
    1: assign marker_out = {~BIP,24'h193B0F,BIP,24'hE6C4F0,2'b01};
    2: assign marker_out = {~BIP,24'h649A3A,BIP,24'h9B65C5,2'b01};
    3: assign marker_out = {~BIP,24'hC2865D,BIP,24'h3D79A2,2'b01};
  endcase

endmodule : alignment_generator
