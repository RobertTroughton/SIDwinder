// png_converter.cpp - PNG to C64 Bitmap Converter for SIDwinder
// Converts 320x200 PNG images to C64 multicolor bitmap format

#include <cstdint>
#include <vector>
#include <string>
#include <cmath>
#include <set>
#include <map>

// C64 Palette Structure
struct C64Palette {
    const char* name;
    uint32_t colors[16]; // RGB values as 0xRRGGBB
};

// Available C64 Palettes - Easy to copy/paste new ones here
// Put your preferred palette first as it will be the default
static const C64Palette AVAILABLE_PALETTES[] = {
    {"PEPTOette_a",                     0x000000,0xffffff,0x753d3d,0x7bb4b4,0x7d4488,0x5c985c,0x343383,0xcbcc7c,0x7c552f,0x523e00,0xa76f6f,0x4e4e4e,0x767676,0x9fdb9f,0x6d6cbc,0xa3a3a3},
    {"VICE3_6_Pepto_PAL",               0x000000,0xffffff,0x68372b,0x70a4b2,0x6f3d86,0x588d43,0x352879,0xb8c76f,0x6f4f25,0x433900,0x9a6759,0x444444,0x6c6c6c,0x9ad284,0x6c5eb5,0x959595},
    {"VICE3_6_Pixcen",                  0x000000,0xffffff,0x894036,0x7abfc7,0x8a46ae,0x68a941,0x3e31a2,0xd0dc71,0x905f25,0x5c4700,0xbb776d,0x555555,0x808080,0xacea88,0x7c70da,0xababab},
    {"UnknownPal01",                    0x000000,0xffffff,0x924a40,0x84c5cc,0x9351b6,0x72b14b,0x483aaa,0xd5df7c,0x99692d,0x675200,0xc18178,0x606060,0x8a8a8a,0xb3ec91,0x867ade,0xb3b3b3},
    {"VICE3_6_VICE_Internal",           0x000000,0xffffff,0xb56148,0x99e6f9,0xc161c9,0x79d570,0x6049ed,0xf7ff6c,0xba8620,0x837000,0xe79a84,0x7a7a7a,0xa8a8a8,0xc0ffb9,0xa28fff,0xd2d2d2},
    {"UnknownPal02",                    0x000000,0xffffff,0x6f4b46,0x93b5b9,0x79578c,0x799a66,0x403a74,0xced4a0,0x7c6347,0x504512,0xa3817c,0x555555,0x808080,0xbcdbab,0x7e78ae,0xababab},
    {"UnknownPal03",                    0x000000,0xffffff,0xbb6a51,0xa9f3ff,0xbf6efb,0x98e551,0x6953f5,0xffff7b,0xc69232,0x8d7900,0xf5ab96,0x818181,0xb6b6b6,0xdbff9e,0xb19eff,0xe0e0e0},
    {"UnknownPal32",                    0x000000,0xffffff,0x67372d,0x73a3b1,0x6e3e83,0x5b8d48,0x362976,0xb7c576,0x6c4f2a,0x423908,0x98675b,0x444444,0x6c6c6c,0x9dd28a,0x6d5fb0,0x959595},
    {"VICE3_6_Ptoing",                  0x000000,0xffffff,0x8c3e34,0x7abfc7,0x8d47b3,0x68a941,0x3e31a2,0xd0dc71,0x905f25,0x574200,0xbb776d,0x545454,0x808080,0xacea88,0x7c70da,0xababab},
    {"Lemon64",                         0x000000,0xffffff,0x8b3e42,0x7cd3cd,0x9746a0,0x5cb254,0x3c39a9,0xe3e76e,0x945731,0x593c07,0xcd777c,0x505050,0x838383,0xaff8a6,0x7f7df4,0xbababa},
    {"VICE3_6_Pepto_PAL_CRT",           0x000000,0xffffff,0x9f5541,0x93d9ec,0xa45bc4,0x7ac559,0x5841bb,0xeafd88,0xa47631,0x6e5d00,0xd5907c,0x6b6b6b,0x9a9a9a,0xc4ffa5,0x9a86fa,0xc7c7c7},
    {"UnknownPal04",                    0x000000,0xffffff,0xa34742,0x84e1e6,0x875bb2,0x89b55f,0x253f9b,0xffffa5,0xb56439,0x7b4100,0xe78a85,0x5c5c5c,0x939393,0xe4ffb9,0x738de8,0xcbcbcb},
    {"PIXCEN_Colodore",                 0x000000,0xffffff,0x813338,0x75cec8,0x8e3c97,0x56ac4d,0x2e2c9b,0xedf171,0x8e5029,0x553800,0xc46c71,0x4a4a4a,0x7b7b7b,0xa9ff9f,0x706deb,0xb2b2b2},
    {"UnknownPal05",                    0x000000,0xffffff,0xbd516c,0x91f5dc,0xb855f6,0x77dc46,0x3e51f0,0xffff5c,0xc4792d,0x8a6700,0xf08fa6,0x777777,0xa5a5a5,0xc3ff99,0x8898ff,0xd5d5d5},
    {"UnknownPal06",                    0x000000,0xffffff,0x924a40,0x84c5cc,0x9351b6,0x72b14b,0x483aa4,0xd5df7c,0x99692d,0x675201,0xc08178,0x606060,0x8a8a8a,0xb2ec91,0x867ade,0xaeaeae},
    {"UnknownCCC",                      0x000000,0xffffff,0xbc5241,0x8feffb,0xb956eb,0x7edb40,0x553fe4,0xffff77,0xc17b1d,0x826300,0xf49486,0x727272,0xa4a4a4,0xcdff98,0x9e8dff,0xd5d5d5},
    {"UnknownPal07",                    0x000000,0xffffff,0x682f20,0x6ca9ba,0x70358a,0x53903a,0x2d1f7d,0xc0d069,0x704a19,0x3d3200,0xa06454,0x3e3e3e,0x696969,0x9cde82,0x6959bf,0x999999},
    {"PETSCIIEditor - FromJmin",        0x000000,0xffffff,0x813338,0x75cec8,0x8e3c97,0x56ac4d,0x2e2c9b,0xedf171,0x8e5029,0x553800,0xc46c71,0x4a4a4a,0x7b7b7b,0xa9ff9f,0x706deb,0xb2b2b2},
    {"UsedBySande",                     0x000000,0xffffff,0xb06154,0xa1e6ee,0xb268d6,0x8ed161,0x5746be,0xf7ff99,0xb7853e,0x7e6a00,0xe29f93,0x7a7a7a,0xa9a9a9,0xd4ffb0,0xbadbad,0xd4d4d4},
    {"VICE3_7_1_PEPTO",                 0x000000,0xffffff,0x883c25,0x7fc4d6,0x8d42ac,0x65ae43,0x3e25a2,0xd6e876,0x8d5f13,0x544300,0xbf7b66,0x525252,0x848484,0xb0f693,0x8470e2,0xb2b2b2},
    {"VICE3_6_Deekay",                  0x000000,0xffffff,0x882000,0x68d0a8,0xa838a0,0x50b818,0x181090,0xf0e858,0xa04800,0x472b1b,0xc87870,0x484848,0x808080,0x98ff98,0x5090d0,0xb8b8b8},
    {"UnknownPal08",                    0x000000,0xffffff,0x7e352b,0x6eb7c1,0x7f3ba6,0x5ca035,0x332799,0xcbd765,0x85531c,0x503c00,0xb46b61,0x4a4a4a,0x757575,0xa3e77c,0x7064d6,0xa3a3a3},
    {"UnknownPal09",                    0x000000,0xffffff,0xc83535,0x83f0dc,0xcc59c6,0x59cd36,0x4137cd,0xf7ee59,0xd17f30,0x915f33,0xf99b97,0x5b5b5b,0x8e8e8e,0x9dff9d,0x75a1ec,0xc1c1c1},
    {"UnknownPal10",                    0x000000,0xffffff,0xbb6a51,0xa9f3ff,0xcd6fd4,0x89e581,0x6953f5,0xffff7b,0xc69232,0x8d7900,0xf5ab96,0x818181,0xb6b6b6,0xcdffc6,0xb19eff,0xe0e0e0},
    {"VICE3_6_Pepto_PAL_Old",           0x000000,0xffffff,0x58291d,0x91c6d5,0x915ca8,0x588d43,0x352879,0xb8c76f,0x916f43,0x433900,0x9a6759,0x353535,0x747474,0x9ad284,0x7466be,0xb8b8b8},
    {"VICE3_6_Colodore",                0x000000,0xffffff,0x96282e,0x5bd6ce,0x9f2dad,0x41b936,0x2724c4,0xeff347,0x9f4815,0x5e3500,0xda5f66,0x474747,0x787878,0x91ff84,0x6864ff,0xaeaeae},
    {"UnknownPal11",                    0x000000,0xffffff,0xae593f,0x9ce9fc,0xaf5bec,0x88d63e,0x553ee5,0xfeff75,0xb68119,0x7a6600,0xe79a84,0x727272,0xa4a4a4,0xd5ff97,0x9f8bff,0xd5d5d5},
    {"VICE3_6_C64S",                    0x000000,0xfcfcfc,0xa80000,0x54fcfc,0xa800a8,0x00a800,0x0000a8,0xfcfc00,0xa85400,0x802c00,0xfc5454,0x545454,0x808080,0x54fc54,0x5454fc,0xa8a8a8},
    {"UnknownPal12",                    0x000000,0xffffff,0x8b1f00,0x6fdfb7,0xa73b9f,0x4fb317,0x0f0097,0xf3eb5b,0xa34700,0x472b1b,0xcb7b6f,0x454444,0x838383,0x97ff97,0x4f93d3,0xbbbbbb},
    {"VICE3_6_VICE",                    0x000000,0xfdfefc,0xbe1a24,0x30e6c6,0xb41ae2,0x1fd21e,0x211bae,0xdff60a,0xb84104,0x6a3304,0xfe4a57,0x424540,0x70746f,0x59fe59,0x5f53fe,0xa4a7a2},
    {"UnknownPal13",                    0x000000,0xffffff,0x9d4b32,0x82cddf,0x9d4ad7,0x72be28,0x4a32d4,0xddee56,0xa36f05,0x6d5a00,0xce846f,0x646464,0x8f8f8f,0xb6fb78,0x8a76ff,0xbababa},
    {"VICE3_6_PALette",                 0x000000,0xd5d5d5,0x72352c,0x659fa6,0x733a91,0x568d35,0x2e237d,0xaeb75e,0x774f1e,0x4b3c00,0x9c635a,0x474747,0x6b6b6b,0x8fc271,0x675db6,0x8f8f8f},
    {"UnknownPal14",                    0x000000,0xffffff,0x7a5550,0x9cbcc0,0x836295,0x83a371,0x4b447e,0xd3d8a8,0x866e52,0x5a4f18,0xab8a86,0x606060,0x8a8a8a,0xc2dfb2,0x8882b5,0xb3b3b3},
    {"UnknownPal15",                    0x000000,0xffffff,0x884f3e,0x8dc0cc,0x8d53b5,0x79ae4a,0x4939ab,0xd4df7a,0x916d2b,0x615300,0xb88577,0x606060,0x8a8a8a,0xb9e990,0x8679df,0xb3b3b3},
    {"VICE3_6_Pepto_NTSC_Sony",         0x000000,0xffffff,0x7c352b,0x5aa6b1,0x694185,0x5d8643,0x212e78,0xcfbe6f,0x894a26,0x5b3300,0xaf6459,0x434343,0x6b6b6b,0xa0cb84,0x5665b3,0x959595},
    {"UnknownPal16",                    0x000000,0xffffff,0x8c4231,0x7bbdc6,0x8c42ad,0x6bad42,0x3931a5,0xd6de73,0x945a21,0x5a4200,0xbd736b,0x525252,0x848484,0xadef8c,0x7b73de,0xadadad},
    {"UnknownPal17",                    0x000000,0xffffff,0x894133,0x7bbec7,0x8a45af,0x68a941,0x3c32a2,0xd2db72,0x905f25,0x5b4700,0xbc776e,0x555555,0x808080,0xaaeb85,0x7d70da,0xababab},
    {"UnknownPal18",                    0x191d19,0xfcf9fc,0x933a4c,0xb6fafa,0xd27ded,0x6acf6f,0x4f44d8,0xfbfb8b,0xd89c5b,0x7f5307,0xef839f,0x575753,0xa3a7a7,0xb7fbbf,0xa397ff,0xefe9e7},
    {"UnknownPal19",                    0x000000,0xffffff,0x9b485e,0x95ddcb,0x9b51ca,0x77c153,0x3343bd,0xeff679,0xa46a34,0x6e5300,0xd08798,0x656565,0x959595,0xc2ffa4,0x7f8bf7,0xc6c6c6},
    {"VICE3_6_Ptoing_CRT",              0x000000,0xffffff,0xcb5c4b,0x9bf6ff,0xc864f8,0x8be34f,0x624ced,0xffff86,0xcc8829,0x886900,0xfaa192,0x7e7e7e,0xb0b0b0,0xd5ffa5,0xab9aff,0xdddddd},
    {"UnknownPal20",                    0x010101,0xfdf5ff,0x893f1d,0x7fd9c5,0x8947a5,0x71b30f,0x2115b3,0xdbd961,0xa75b1f,0x5b370b,0xdb9187,0x414141,0x818181,0xabff8d,0x7189e1,0xb9b9b9},
    {"UnknownPal21",                    0x000000,0xfcf4ff,0x883e1d,0x7ed8c4,0x8946a5,0x71b20e,0x2014b2,0xdad961,0xa65b1e,0x41270a,0xd59886,0x404040,0x808080,0xabff8d,0x7089e0,0xb0b0b0},
    {"UnknownPal22",                    0x000000,0xffffff,0x794032,0x7cb7c8,0x8146b0,0x6ba63c,0x3c2fa4,0xccdb63,0x865f24,0x544700,0xb37869,0x4f4f4f,0x7e7e7e,0xabe77a,0x7b6de5,0xa8a8a8},
    {"UnknownPal23",                    0x000000,0xffffff,0x742e32,0x69b8b3,0x7f3588,0x4d9a45,0x29278b,0xd5d765,0x7f4825,0x4c3200,0xaf6165,0x424242,0x6e6e6e,0x98ef8f,0x6462d3,0x9f9f9f},
    {"UnknownPal24",                    0x000000,0xf4f4f4,0x8c4d3b,0x87bfcd,0x9153be,0x78b143,0x4b3ab6,0xcedb69,0x966e26,0x665700,0xbd8575,0x5f5f5f,0x8d8d8d,0xb0e582,0x897be9,0xb0b0b0},
    {"UnknownPal25",                    0x000000,0xffffff,0xb35f46,0x98e4f7,0xc05fc7,0x77d46e,0x5e47eb,0xf5ff6b,0xb9841e,0x826e00,0xe59983,0x787878,0xa6a6a6,0xbfffb8,0xa18dff,0xd1d1d1},
    {"UnknownPal26",                    0x000000,0xf4f4f4,0x984235,0x7ec1c8,0x974bbc,0x6db040,0x4434af,0xced970,0x9a671e,0x624a00,0xc07e73,0x5d5d5d,0x888888,0xace589,0x8377de,0xafafaf},
    {"UnknownPal27",                    0x000000,0xffffff,0x8a1f00,0x65cfaa,0xa53a9f,0x4fb015,0x1a0f90,0xf0ea50,0xa04500,0x3f1f00,0xca7a5f,0x454545,0x808080,0x95ff95,0x4f90d0,0xbababa},
    {"VICE3_6_CCS64",                   0x101010,0xffffff,0xe04040,0x60ffff,0xe060e0,0x40e040,0x4040e0,0xffff40,0xe0a040,0x9c7448,0xffa0a0,0x545454,0x888888,0xa0ffa0,0xa0a0ff,0xc0c0c0},
    {"UnknownPal28",                    0x000000,0xffffff,0x8d2f34,0x6ad4cd,0x9835a4,0x4cb442,0x2c29b1,0xf0f45d,0x984e20,0x5b3800,0xd1676d,0x4a4a4a,0x7b7b7b,0x9fff93,0x6d6aff,0xb2b2b2},
    {"UnknownPal29",                    0x000000,0xffffff,0x663333,0x77aaaa,0x774488,0x558844,0x332277,0xbbcc77,0x775522,0x443300,0x996655,0x444444,0x666666,0x99cc88,0x6666bb,0x999999},
    {"VICE3_6_CommunityColours",        0x000000,0xffffff,0xaf2a29,0x62d8cc,0xb03fb6,0x4ac64a,0x3739c4,0xe4ed4e,0xb6591c,0x683808,0xea746c,0x4d4d4d,0x848484,0xa6fa9e,0x707ce6,0xb6b6b5},
    {"VICE3_8_Pepto_PAL",               0x000000,0xffffff,0x8d412e,0x81d2e7,0x9445b7,0x65b845,0x422ead,0xe6fe74,0x94621f,0x584900,0xcc7d67,0x555555,0x878787,0xb7ff95,0x8772f9,0xbababa},
    {"UnknownPal30",                    0x000000,0xfdfdfd,0x7f2417,0x64b8c2,0x7f2aab,0x51a11e,0x2412a0,0xcad755,0x864900,0x4b3000,0xb76358,0x404040,0x707070,0x9de871,0x6b5cde,0xa0a0a0},
    {"UnknownPal31",                    0x000000,0xffffff,0xd74612,0x6ff7ff,0xcc35ff,0x67f200,0x5125ff,0xffff00,0xd67c00,0x906f00,0xff8a62,0x727272,0xa4a4a4,0xb9ff3f,0x9b79ff,0xd5d5d5},
    {"VICE3_8_VICE_Internal",           0x000000,0xffffff,0xaf3c58,0x7ef3d6,0xaa40f5,0x62d532,0x2c3dec,0xffff46,0xb7631e,0x775300,0xee7b95,0x626262,0x949494,0xb7ff86,0x7385ff,0xcdcdcd},
    {"VICE3_6_Pepto_NTSC_CRT",          0x000000,0xffffff,0x9e5541,0x93d8ea,0xa45bc4,0x7ac358,0x5541bb,0xe9fc87,0xa47531,0x6c5c00,0xd48f7c,0x6a6a6a,0x999999,0xc4ffa4,0x9886fa,0xc7c7c7},
    {"VICE3_6_Colodore_CRT",            0x000000,0xffffff,0xdb3a45,0x6cffff,0xe23bf3,0x50f83c,0x3f3aff,0xffff3c,0xe26909,0x935500,0xff808a,0x6f6f6f,0xa6a6a6,0xb1ff9f,0x918bff,0xe1e1e1},
    {"VICE3_6_Pepto_PAL_OldCRT",        0x000000,0xffffff,0x8d422c,0xb8fcff,0xca80e7,0x7ac559,0x5841bb,0xeafd88,0xca9b59,0x6e5d00,0xd5907c,0x585858,0xa3a3a3,0xc4ffa5,0xa28fff,0xebebeb},
    {"UnknownPal33",                    0x000000,0xf5f5f5,0x8b392d,0x73bbc4,0x8b3fb1,0x62a834,0x3928a8,0xcbd666,0x915b13,0x5c4400,0xbb7268,0x535353,0x7e7e7e,0xa5e47e,0x796cdb,0xa8a8a8},
    {"VICE3_6_Pixcen_CRT",              0x000000,0xffffff,0xc85e4f,0x9bf6ff,0xc462f2,0x8be34f,0x624ced,0xffff86,0xcc8829,0x8e6f00,0xfaa192,0x808080,0xb0b0b0,0xd5ffa5,0xab9aff,0xdddddd},
    {"VICE3_6_Pepto_NTSC",              0x000000,0xffffff,0x67372b,0x70a3b1,0x6f3d86,0x588c42,0x342879,0xb7c66e,0x6f4e25,0x423800,0x996659,0x434343,0x6b6b6b,0x9ad183,0x6b5eb5,0x959595},
    {"UnknownPal34",                    0x000000,0xffffff,0x7b4336,0x75b0c0,0x7d4697,0x629f4b,0x40328d,0xc3d571,0x825e30,0x5a4f0f,0xaa7060,0x545454,0x797979,0x9fde87,0x7363c4,0x9e9e9e},
    {"UnknownPal35",                    0x000000,0xffffff,0x8c4d3b,0x87bfcd,0x9153be,0x78b143,0x4b3ab6,0xcedb69,0x966e26,0x665700,0xbd8575,0x5f5f5f,0x8d8d8d,0xb0e582,0x897be9,0xb0b0b0},
    {"UnknownPal_Misc",                 0x000000,0xffffff,0x943a32,0x62c1c9,0x9441b4,0x50ab2b,0x4130a8,0xcddc5e,0x985c12,0x604600,0xc6736a,0x555555,0x808080,0x99ec7b,0x7f6fe1,0xababab},
    {"VICE3_6_CommunityColours_CRT",    0x000000,0xffffff,0xf93b38,0x76ffff,0xf355fa,0x5bff5b,0x5458ff,0xffff4b,0xfa7d12,0xa05800,0xff998e,0x767676,0xb5b5b5,0xcbffc0,0x98a9ff,0xe9e9e7},
    {"VICE3_6_PC64",                    0x212121,0xffffff,0xb52121,0x73ffff,0xb521b5,0x21b521,0x2121b5,0xffff21,0xb57321,0x944221,0xff7373,0x737373,0x949494,0x73ff73,0x7373ff,0xb5b5b5},
    {"VICE3_6_Frodo_CRT",               0x000000,0xffffff,0xff0000,0x00ffff,0xff00ff,0x00ff00,0x0000ff,0xffff00,0xffb200,0xc76600,0xffafaf,0x6b6b6b,0xb9b9b9,0xa5ffa5,0xb5b5ff,0xfefefe},
    {"VICE3_6_Godot",                   0x000000,0xffffff,0x880000,0xaaffee,0xcc44cc,0x00cc55,0x0000aa,0xeeee77,0xdd8855,0x664400,0xfe7777,0x333333,0x777777,0xaaff66,0x0088ff,0xbbbbbb},
    {"VICE3_6_C64HQ",                   0x0a0a0a,0xfff8ff,0x851f02,0x65cda8,0xa73b9f,0x4dab19,0x1a0c92,0xebe353,0xa94b02,0x441e00,0xd28074,0x464646,0x8b8b8b,0x8ef68e,0x4d91d1,0xbababa},
    {"UnknownPal36",                    0x000000,0xffffff,0x8b392d,0x73bbc4,0x8b3fb1,0x62a834,0x3928a8,0xcbd666,0x915b13,0x5c4400,0xbb7268,0x535353,0x7e7e7e,0xa5e47e,0x796cdb,0xa8a8a8},
    {"UnknownPal37",                    0x010101,0xfdf5ff,0x8a1f00,0x65cfaa,0xa53a9f,0x4fb015,0x1a0f90,0xf0ea50,0xa04500,0x3f1f00,0xca7a5f,0x454545,0x808080,0x95ff95,0x4f90d0,0xbababa},
    {"UnknownPal38",                    0x000000,0xffffff,0x813339,0x74cec8,0x8e3c97,0x56ac4e,0x2e2c9b,0xedf171,0x8e5029,0x553800,0xc46c71,0x4a4a4a,0x9a9a9a,0xa9ff9f,0x706deb,0xb1b1b1},
    {"PALette_C64_v1r",                 0x000000,0xffffff,0x8c323d,0x66bfb3,0x8e36a1,0x4aa648,0x322dab,0xcdd256,0x8f501a,0x533d00,0xbd636e,0x4e4e4e,0x767676,0x8ce98b,0x6b66e4,0xa3a3a3},
    {"VICE3_6_C64HQ_CRT",               0x171717,0xffffff,0xc92f00,0x7dffd9,0xea51e0,0x66e900,0x2f12e1,0xffff54,0xee6e00,0x743400,0xffaa99,0x6e6e6e,0xbcbcbc,0xaeffae,0x65c6ff,0xededed},
    {"VICE3_6_C64S_CRT",                0x000000,0xffffff,0xf80000,0x59ffff,0xf300f3,0x00ec00,0x0000ff,0xffff00,0xec7a00,0xc04400,0xff6f6f,0x7e7e7e,0xb0b0b0,0x60ff60,0x7979ff,0xdadada},
    {"VICE3_6_CCS64_CRT",               0x222222,0xffffff,0xff5757,0x6bffff,0xff7cff,0x46ff46,0x6060ff,0xffff2a,0xffcf42,0xd6a160,0xffcaca,0x7e7e7e,0xb9b9b9,0xc4ffc4,0xcfcfff,0xf3f3f3},
    {"VICE3_6_ChristopherJam",          0x000000,0xffffff,0x7d202c,0x4fb3a5,0x84258c,0x339840,0x2a1b9d,0xbfd04a,0x7f410d,0x4c2e00,0xb44f5c,0x3c3c3c,0x646464,0x7ce587,0x6351db,0x939393},
    {"VICE3_6_ChristopherJam_CRT",      0x000000,0xffffff,0xbd2f45,0x62eddb,0xc334cd,0x3fd457,0x462ceb,0xf2ff4d,0xbc6200,0x7c4d00,0xf86f82,0x606060,0x919191,0x9affa9,0x8f74ff,0xc5c5c5},
    {"VICE3_6_Deekay_CRT",              0x000000,0xffffff,0xcd3100,0x81ffd8,0xeb4ce1,0x69f700,0x2a19dd,0xffff5b,0xe46a00,0x75482a,0xffa196,0x707070,0xb0b0b0,0xb9ffb9,0x69c4ff,0xebebeb},
    {"VICE3_6_Frodo",                   0x000000,0xffffff,0xcc0000,0x00ffcc,0xff00ff,0x00cc00,0x0000cc,0xffff00,0xff8800,0x884400,0xff8888,0x444444,0x888888,0x88ff88,0x8888ff,0xcccccc},
    {"VICE3_6_Godot_CRT",               0x000000,0xffffff,0xd10000,0xcdffff,0xff59ff,0x00ff71,0x0000ff,0xffff88,0xffb46a,0x9b6a00,0xff9a9a,0x555555,0xa6a6a6,0xd1ff72,0x00bfff,0xeeeeee},
    {"VICE3_6_PALette_CRT",             0x000000,0xffffff,0xac5142,0x86d5dd,0xaa55d2,0x77c542,0x4d3ac1,0xe1ed72,0xaf7622,0x796100,0xd88a7d,0x6f6f6f,0x999999,0xb9fb8f,0x9384fc,0xc0c0c0},
    {"VICE3_6_PC64_CRT",                0x3c3c3c,0xffffff,0xff2a2a,0x86ffff,0xfd24fd,0x19f719,0x3535ff,0xffff00,0xf59f15,0xd56127,0xff9696,0xa2a2a2,0xc6c6c6,0x8aff8a,0x9e9eff,0xe8e8e8},
    {"VICE3_6_Pepto_NTSC_SonyCRT",      0x000000,0xffffff,0xb9503f,0x75ddec,0x9c61c3,0x82bb5b,0x354cba,0xfff188,0xc76e31,0x905300,0xef8a7a,0x6a6a6a,0x999999,0xccffa6,0x7b90f8,0xc7c7c7},
    {"VICE3_6_RGB",                     0x000000,0xffffff,0xff0000,0x00ffff,0xff00ff,0x00ff00,0x0000ff,0xffff00,0xff8000,0x804000,0xff8080,0x404040,0x808080,0x80ff80,0x8080ff,0xc0c0c0},
    {"VICE3_6_RGB_CRT",                 0x000000,0xffffff,0xff0000,0x00ffff,0xff00ff,0x00ff00,0x0000ff,0xffff00,0xffaa00,0xbe6200,0xffa5a5,0x666666,0xb0b0b0,0x9bff9b,0xacacff,0xf3f3f3},
    {"VICE3_6_VICE_CRT",                0x000000,0xffffff,0xff1d31,0x24ffff,0xfc14ff,0x0bff09,0x372cff,0xffff00,0xff5d00,0xa35100,0xff6175,0x676c65,0x9ea39c,0x66ff66,0x8876ff,0xd5d9d3},
    {"VICE3_8_C64HQ",                   0x0d0d0d,0xffffff,0xbe1e00,0x69ffd2,0xe53cd8,0x51e400,0x1f09db,0xffff3f,0xeb5800,0x5e2300,0xff9986,0x585858,0xaeaeae,0x9fff9f,0x4fb9ff,0xe9e9e9},
    {"VICE3_8_C64S",                    0x000000,0xffffff,0xf60000,0x45ffff,0xf100f1,0x00e700,0x0000ff,0xffff00,0xe76400,0xb43100,0xff5959,0x696969,0xa0a0a0,0x4aff4a,0x6363ff,0xd2d2d2},
    {"VICE3_8_CCS64",                   0x141414,0xffffff,0xff4141,0x55ffff,0xff68ff,0x32ff32,0x4b4bff,0xffff1c,0xffc630,0xcd8f4a,0xffbfbf,0x696969,0xaaaaaa,0xb7ffb7,0xc4c4ff,0xf0f0f0},
    {"VICE3_8_ChristopherJam",          0x000000,0xffffff,0xb01f32,0x4eead3,0xb722c3,0x2dcb41,0x331ce7,0xf0ff3a,0xae4e00,0x683800,0xf6596d,0x4b4b4b,0x7d7d7d,0x87ff99,0x7b5fff,0xb8b8b8},
    {"VICE3_8_Colodore",                0x000000,0xffffff,0xd32831,0x58ffff,0xdb29f1,0x3cf82b,0x2c27ff,0xffff29,0xdc5404,0x814000,0xff6c76,0x595959,0x969696,0xa1ff8d,0x7d77ff,0xdadada},
    {"VICE3_8_CommunityColours",        0x000000,0xffffff,0xf82827,0x62ffff,0xf040fa,0x46ff46,0x4042ff,0xffff36,0xfa6909,0x8f4400,0xff8679,0x606060,0xa5a5a5,0xc1ffb4,0x8699ff,0xe4e4e2},
    {"VICE3_8_Deekay",                  0x000000,0xffffff,0xc21f00,0x6dffd1,0xe738db,0x53f500,0x1c0fd7,0xffff45,0xdd5400,0x5f331a,0xff8f82,0x5a5a5a,0xa0a0a0,0xabffab,0x54b8ff,0xe6e6e6},
    {"VICE3_8_Frodo",                   0x000000,0xffffff,0xff0000,0x00ffff,0xff00ff,0x00ff00,0x0000ff,0xffff00,0xffa400,0xbc5100,0xff9f9f,0x555555,0xaaaaaa,0x94ff94,0xa6a6ff,0xfefefe},
    {"VICE3_8_Godot",                   0x000000,0xffffff,0xc80000,0xc3ffff,0xff44ff,0x00ff5d,0x0000ff,0xffff74,0xffa454,0x8a5400,0xff8888,0x404040,0x959595,0xc7ff5d,0x00b3ff,0xeaeaea},
    {"VICE3_8_PALette",                 0x000000,0xffffff,0x9c3d2e,0x72ccd7,0x9a40c8,0x63b930,0x3828b4,0xdbe95e,0x9f6014,0x634c00,0xd07769,0x595959,0x868686,0xaafa7c,0x8071fb,0xb3b3b3},
    {"VICE3_8_PALette_6569R1",          0x000000,0xffffff,0xae1e3b,0x95ffff,0xf062ff,0x4adc4e,0x452dfb,0xfaff49,0xec8d33,0x6f4c00,0xff728f,0x4c4c4c,0xa0a0a0,0x9effa1,0x9981ff,0xf3f3f3},
    {"VICE3_8_PALette_6569R5",          0x000000,0xffffff,0xc43350,0x6df9dc,0xc436dc,0x4adc4e,0x452dfb,0xfaff49,0xc16208,0x6f4c00,0xff728f,0x626262,0x949494,0x9effa1,0x8c74ff,0xcccccc},
    {"VICE3_8_PALette_8565R2",          0x000000,0xffffff,0xc1383c,0x6cf6ef,0xbf37e0,0x4cdc46,0x3338f4,0xffff4b,0xc1600e,0x714c00,0xfe767b,0x626262,0x949494,0xa0ff9a,0x7b80ff,0xcccccc},
    {"VICE3_8_PC64",                    0x292929,0xffffff,0xff1c1c,0x71ffff,0xfe17fe,0x0ef50e,0x2424ff,0xffff00,0xf48c0d,0xcc4c19,0xff8383,0x909090,0xb9b9b9,0x76ff76,0x8b8bff,0xe2e2e2},
    {"VICE3_8_Pepto_NTSC",              0x000000,0xffffff,0x8c412e,0x81d0e6,0x9445b7,0x65b742,0x412ead,0xe5fd73,0x94601f,0x564700,0xcb7c67,0x545454,0x868686,0xb8ff94,0x8672f9,0xbababa},
    {"VICE3_8_Pepto_NTSC_Sony",         0x000000,0xffffff,0xab3c2c,0x5fd6e7,0x8a4bb5,0x6eae45,0x2438ab,0xffef73,0xba581f,0x7c3d00,0xeb7765,0x545454,0x868686,0xc1ff95,0x657df6,0xbababa},
    {"VICE3_8_Pepto_OldPAL",            0x000000,0xffffff,0x79301d,0xa9fdff,0xbe6ce2,0x65b845,0x422ead,0xe6fe74,0xbe8a45,0x584900,0xcc7d67,0x424242,0x919191,0xb7ff95,0x917bff,0xe6e6e6},
    {"VICE3_8_Pixcen",                  0x000000,0xffffff,0xbc4a3a,0x8af5ff,0xb84ef0,0x78dd3b,0x4c38e9,0xffff71,0xc17419,0x7b5900,0xf98f80,0x6a6a6a,0xa0a0a0,0xcdff95,0x9a87ff,0xd6d6d6},
    {"VICE3_8_Ptoing",                  0x000000,0xffffff,0xc14637,0x8af5ff,0xbc4ff8,0x78dd3b,0x4c38e9,0xffff71,0xc17419,0x745300,0xf98f80,0x696969,0xa0a0a0,0xcdff95,0x9a87ff,0xd6d6d6},
    {"VICE3_8_RGB",                     0x000000,0xffffff,0xff0000,0x00ffff,0xff00ff,0x00ff00,0x0000ff,0xffff00,0xff9900,0xb04c00,0xff9494,0x505050,0xa0a0a0,0x88ff88,0x9b9bff,0xf0f0f0},
    {"VICE3_8_VICE_Original",           0x000000,0xffffff,0xff1021,0x15ffff,0xfb0bff,0x06ff04,0x261cff,0xffff00,0xff4900,0x923c00,0xff4b5f,0x53564f,0x8b918a,0x51ff51,0x7360ff,0xcdd1c9},
    {"UnknownPal_Electric",             0x000000,0xffffff,0x813339,0x74cec8,0x8e3c97,0x56ac4e,0x2e2c9b,0xedf171,0x8e5029,0x543800,0xc46c71,0x4a4a4a,0x7b7b7b,0xa9ff9f,0x706deb,0xb1b1b1},
    {"UnknownPal_Facet",                0x000000,0xffffff,0x72372a,0x7cbccb,0x7b3e99,0x5ea145,0x352788,0xd0de7b,0x7b5324,0x453900,0xb1705f,0x464646,0x777777,0xb1e696,0x7765ce,0xababab},
    {"Unknown_FromFacet",               0x000000,0xffffff,0x894036,0x7abfc7,0x8a46ae,0x68a941,0x3e31a2,0xd0dc71,0x905f25,0x5c4700,0xbb776d,0x555555,0x808080,0xababab,0x7c70da,0xababab},
    {"TheSargeSpecial",                 0x000000,0xffffff,0xa52828,0x79e4be,0xff44ff,0x65c331,0x414ed3,0xeee550,0xc86e28,0x864e23,0xf39187,0x636363,0x9f9f9f,0x98ff98,0x5fa2e2,0xc5c5c5},
    {"Weird8ColLoadingScreen",          0x000000,0xffffff,0xbd5341,0x8feffb,0xb957eb,0x7fdb41,0x553fe5,0xffff77,0xbadbad,0xbadbad,0xbadbad,0xbadbad,0xbadbad,0xbadbad,0xbadbad,0xbadbad},
    {"FromFoxsFont",                    0x000000,0xffffff,0x8c4231,0x7bbdc6,0x8c42ad,0x5ca035,0x3931a5,0xd6de73,0x945a21,0x5a4200,0xbd736b,0x4a4a4a,0x848484,0xadadad,0x7b73de,0xadadad},
};

static const size_t NUM_PALETTES = sizeof(AVAILABLE_PALETTES) / sizeof(AVAILABLE_PALETTES[0]);
static const C64Palette* CURRENT_PALETTE = &AVAILABLE_PALETTES[0]; // Default to first palette

// Helper function to extract RGB components
inline void getRGB(uint32_t color, uint8_t& r, uint8_t& g, uint8_t& b) {
    r = (color >> 16) & 0xFF;
    g = (color >> 8) & 0xFF;
    b = color & 0xFF;
}

class PNGToC64Converter {
private:
    uint8_t* imageData;
    int width, height;
    std::vector<uint8_t> mapData;
    std::vector<uint8_t> scrData;
    std::vector<uint8_t> colData;
    uint8_t backgroundColor;

    // Color matching statistics
    int exactMatches;
    int distanceMatches;
    std::map<uint8_t, int> colorUsage;

    // Calculate color distance using Euclidean distance in RGB space
    double colorDistance(uint8_t r1, uint8_t g1, uint8_t b1, uint8_t r2, uint8_t g2, uint8_t b2) {
        double dr = r1 - r2;
        double dg = g1 - g2;
        double db = b1 - b2;
        return sqrt(dr * dr + dg * dg + db * db);
    }

    // Find closest C64 color to RGB value using current palette
    uint8_t findClosestC64Color(uint8_t r, uint8_t g, uint8_t b) {
        // Try exact match first across all available palettes
        for (size_t paletteIdx = 0; paletteIdx < NUM_PALETTES; paletteIdx++) {
            const C64Palette& palette = AVAILABLE_PALETTES[paletteIdx];
            for (int colorIdx = 0; colorIdx < 16; colorIdx++) {
                uint8_t pr, pg, pb;
                getRGB(palette.colors[colorIdx], pr, pg, pb);
                if (pr == r && pg == g && pb == b) {
                    exactMatches++;
                    return colorIdx; // Early exit on exact match
                }
            }
        }

        // No exact match found, use distance matching with current palette
        uint8_t closest = 0;
        uint8_t cr, cg, cb;
        getRGB(CURRENT_PALETTE->colors[0], cr, cg, cb);
        double minDistance = colorDistance(r, g, b, cr, cg, cb);

        for (int i = 1; i < 16; i++) {
            getRGB(CURRENT_PALETTE->colors[i], cr, cg, cb);
            double distance = colorDistance(r, g, b, cr, cg, cb);
            if (distance < minDistance) {
                minDistance = distance;
                closest = i;
            }
        }

        distanceMatches++;
        return closest;
    }

    // Get pixel color index from image data
    uint8_t getPixelColor(int x, int y) {
        if (x >= width || y >= height) return 0;

        int index = (y * width + x) * 4; // Assuming RGBA
        uint8_t r = imageData[index];
        uint8_t g = imageData[index + 1];
        uint8_t b = imageData[index + 2];

        return findClosestC64Color(r, g, b);
    }

    // Analyze 8x8 character cell for colors
    bool analyzeCharCell(int charX, int charY, std::set<uint8_t>& colors) {
        colors.clear();

        // Scan 8x8 pixel area (4x8 in multicolor mode - double-wide pixels)
        for (int y = 0; y < 8; y++) {
            for (int x = 0; x < 8; x += 2) { // Step by 2 for multicolor double pixels
                int pixelX = charX * 8 + x;
                int pixelY = charY * 8 + y;
                uint8_t color1 = getPixelColor(pixelX, pixelY);
                uint8_t color2 = getPixelColor(pixelX + 1, pixelY);
                colors.insert(color1);
            }
        }

        // C64 multicolor mode allows max 4 colors per 8x8 char
        return colors.size() <= 4;
    }

    // Find best background color by testing each possibility
    uint8_t findBestBackgroundColor() {
        std::map<uint8_t, int> colorUsage;

        // Count usage of each color across all character cells
        for (int charY = 0; charY < 25; charY++) {
            for (int charX = 0; charX < 40; charX++) {
                std::set<uint8_t> cellColors;
                if (!analyzeCharCell(charX, charY, cellColors)) {
                    continue; // Skip invalid cells for now
                }

                for (uint8_t color : cellColors) {
                    colorUsage[color]++;
                }
            }
        }

        // Create a list of valid background colors with their scores
        std::vector<std::pair<uint8_t, int>> validBackgrounds;

        // Try each color as background and see if it works for all cells
        for (const auto& candidate : colorUsage) {
            uint8_t bgColor = candidate.first;
            bool canUseAsBg = true;
            int score = candidate.second; // Higher usage = higher score

            // Test if this background color works for all cells
            for (int charY = 0; charY < 25 && canUseAsBg; charY++) {
                for (int charX = 0; charX < 40 && canUseAsBg; charX++) {
                    std::set<uint8_t> cellColors;
                    if (!analyzeCharCell(charX, charY, cellColors)) {
                        canUseAsBg = false;
                        break;
                    }

                    // If this cell doesn't use the background color, 
                    // it can only have 3 other colors
                    if (cellColors.find(bgColor) == cellColors.end()) {
                        if (cellColors.size() > 3) {
                            canUseAsBg = false;
                            break;
                        }
                    }
                    else {
                        // Cell uses background color, can have 3 others
                        if (cellColors.size() > 4) {
                            canUseAsBg = false;
                            break;
                        }
                    }
                }
            }

            if (canUseAsBg) {
                validBackgrounds.push_back({ bgColor, score });
            }
        }

        if (validBackgrounds.empty()) {
            return 0; // Fallback to black
        }

        // Sort by score (usage count) - highest first
        std::sort(validBackgrounds.begin(), validBackgrounds.end(),
            [](const auto& a, const auto& b) { return a.second > b.second; });

        // Return the most used valid background color
        return validBackgrounds[0].first;
    }

    // Convert 8x8 character cell to bitmap data
    void convertCharCell(int charX, int charY, uint8_t bgColor) {
        std::set<uint8_t> cellColors;
        analyzeCharCell(charX, charY, cellColors);

        // Remove background color from set to get remaining colors
        cellColors.erase(bgColor);

        // Convert set to vector for indexing
        std::vector<uint8_t> colors(cellColors.begin(), cellColors.end());

        // Ensure we have at most 3 non-background colors
        if (colors.size() > 3) {
            colors.resize(3);
        }

        // Pad with background color if needed
        while (colors.size() < 3) {
            colors.push_back(bgColor);
        }

        // Set screen memory (colors for this character)
        int screenIndex = charY * 40 + charX;
        scrData[screenIndex] = (colors[0] << 4) | colors[1]; // Upper nibble: color1, lower: color2
        colData[screenIndex] = colors[2]; // Color memory holds the third color

        // Convert pixel data to bitmap
        for (int y = 0; y < 8; y++) {
            uint8_t bitmapByte = 0;

            for (int x = 0; x < 8; x += 2) {
                int pixelX = charX * 8 + x;
                int pixelY = charY * 8 + y;

                uint8_t pixelColor = getPixelColor(pixelX, pixelY);
                uint8_t colorIndex;

                // Map pixel color to 2-bit value
                if (pixelColor == bgColor) {
                    colorIndex = 0; // Background
                }
                else {
                    // Find in our color list
                    colorIndex = 1; // Default
                    for (size_t i = 0; i < colors.size(); i++) {
                        if (colors[i] == pixelColor) {
                            colorIndex = i + 1;
                            break;
                        }
                    }
                }

                // Each pixel pair uses 2 bits
                bitmapByte |= (colorIndex << (6 - x));
            }

            // Store in map data (bitmap memory)
            int bitmapIndex = (charY * 40 + charX) * 8 + y;
            mapData[bitmapIndex] = bitmapByte;
        }
    }

public:
    PNGToC64Converter() : imageData(nullptr), width(0), height(0), backgroundColor(0), exactMatches(0), distanceMatches(0) {
        mapData.resize(8000);  // 40x25 chars * 8 bytes each
        scrData.resize(1000);  // 40x25 screen memory
        colData.resize(1000);  // 40x25 color memory
    }

    ~PNGToC64Converter() {
        if (imageData) {
            delete[] imageData;
        }
    }

    bool extractWithOffset(uint8_t* data, int offsetX, int offsetY) {
        for (int y = 0; y < 200; y++) {
            for (int x = 0; x < 320; x++) {
                int srcIndex = ((y + offsetY) * 384 + (x + offsetX)) * 4;
                int dstIndex = (y * 320 + x) * 4;
                imageData[dstIndex] = data[srcIndex];
                imageData[dstIndex + 1] = data[srcIndex + 1];
                imageData[dstIndex + 2] = data[srcIndex + 2];
                imageData[dstIndex + 3] = data[srcIndex + 3];
            }
        }

        // Test if this offset works
        if (testConversion()) {
            return true;
        }
        return false;
    }
    
    // Try different offsets for 384x272 VICE screenshots
    bool tryDifferentOffsets(uint8_t* data, int w, int h) {
        for (int offsetY = 0; offsetY < 8; offsetY++) {
            int ypos = offsetY + 35;
            for (int offsetX = 0; offsetX < 8; offsetX++) {
                int xpos = offsetX + 32;
                if (extractWithOffset(data, xpos, ypos)) {
                    return true;
                }
            }
        }
        return false;
    }

    bool testConversion() {
        for (int charY = 0; charY < 25; charY++) {
            for (int charX = 0; charX < 40; charX++) {
                std::set<uint8_t> cellColors;
                if (!analyzeCharCell(charX, charY, cellColors)) {
                    return false;
                }
            }
        }
        return true;
    }

    // Set image data (supports 320x200 or 384x272 VICE screenshots)
    bool setImageData(uint8_t* data, int w, int h) {
        if (imageData) {
            delete[] imageData;
        }

        width = 320;
        height = 200;
        int dataSize = width * height * 4; // RGBA
        imageData = new uint8_t[dataSize];

        if (w == 320 && h == 200) {
            for (int i = 0; i < dataSize; i++) {
                imageData[i] = data[i];
            }
            return true;
        }
        else if (w == 384 && h == 272) {
            if (!extractWithOffset(data, 32, 35)) {
                if (!tryDifferentOffsets(data, w, h)) {
                    delete[] imageData;
                    imageData = nullptr;
                    return false;
                }
            }
            return true;
        }
        else {
            delete[] imageData;
            return false;
        }
    }

    // Convert PNG to C64 format
    bool convert() {
        if (!imageData) return false;

        // Reset statistics
        exactMatches = 0;
        distanceMatches = 0;

        // First pass: find optimal background color
        backgroundColor = findBestBackgroundColor();

        // Second pass: verify all character cells are valid
        for (int charY = 0; charY < 25; charY++) {
            for (int charX = 0; charX < 40; charX++) {
                std::set<uint8_t> cellColors;
                if (!analyzeCharCell(charX, charY, cellColors)) {
                    return false; // Image has too many colors in a character cell
                }

                // Check if colors work with selected background
                if (cellColors.find(backgroundColor) == cellColors.end()) {
                    if (cellColors.size() > 3) {
                        return false;
                    }
                }
                else {
                    if (cellColors.size() > 4) {
                        return false;
                    }
                }
            }
        }

        // Third pass: convert all character cells
        for (int charY = 0; charY < 25; charY++) {
            for (int charX = 0; charX < 40; charX++) {
                convertCharCell(charX, charY, backgroundColor);
            }
        }

        return true;
    }

    // Create C64-compatible file data
    std::vector<uint8_t> createC64BitmapFile() {
        std::vector<uint8_t> bitmapData;
        bitmapData.reserve(10003); // Standard C64 bitmap file size

        // Load address (0x6000) - little endian
        bitmapData.push_back(0x00);
        bitmapData.push_back(0x60);

        // Bitmap data (8000 bytes) - starts at offset 2
        bitmapData.insert(bitmapData.end(), mapData.begin(), mapData.end());

        // Screen memory (1000 bytes) - starts at offset 8002  
        bitmapData.insert(bitmapData.end(), scrData.begin(), scrData.end());

        // Color memory (1000 bytes) - starts at offset 9002
        bitmapData.insert(bitmapData.end(), colData.begin(), colData.end());

        // Background color (1 byte) - at offset 10002
        bitmapData.push_back(backgroundColor);

        return bitmapData;
    }

    // Get individual components
    const std::vector<uint8_t>& getMapData() const { return mapData; }
    const std::vector<uint8_t>& getScrData() const { return scrData; }
    const std::vector<uint8_t>& getColData() const { return colData; }
    uint8_t getBackgroundColor() const { return backgroundColor; }

    // Get color matching statistics
    void getColorMatchingStats(int& exact, int& distance) {
        exact = exactMatches;
        distance = distanceMatches;
    }
};

// WASM interface functions
extern "C" {
    static PNGToC64Converter* converter = nullptr;

    // Initialize converter
    int png_converter_init() {
        if (converter) {
            delete converter;
        }
        converter = new PNGToC64Converter();
        return 1;
    }

    // Set image data
    int png_converter_set_image(uint8_t* data, int width, int height) {
        if (!converter) return 0;
        return converter->setImageData(data, width, height) ? 1 : 0;
    }

    // Convert image
    int png_converter_convert() {
        if (!converter) return 0;
        return converter->convert() ? 1 : 0;
    }

    // Create c64 bitmap file
    int png_converter_create_c64_bitmap(uint8_t* output) {
        if (!converter) return 0;

        auto c64BitmapData = converter->createC64BitmapFile();
        for (size_t i = 0; i < c64BitmapData.size(); i++) {
            output[i] = c64BitmapData[i];
        }
        return c64BitmapData.size();
    }

    // Get background color that was selected
    int png_converter_get_background_color() {
        if (!converter) return 0;
        return converter->getBackgroundColor();
    }

    // Get component data
    int png_converter_get_map_data(uint8_t* output) {
        if (!converter) return 0;
        const auto& data = converter->getMapData();
        for (size_t i = 0; i < data.size(); i++) {
            output[i] = data[i];
        }
        return data.size();
    }

    int png_converter_get_scr_data(uint8_t* output) {
        if (!converter) return 0;
        const auto& data = converter->getScrData();
        for (size_t i = 0; i < data.size(); i++) {
            output[i] = data[i];
        }
        return data.size();
    }

    int png_converter_get_col_data(uint8_t* output) {
        if (!converter) return 0;
        const auto& data = converter->getColData();
        for (size_t i = 0; i < data.size(); i++) {
            output[i] = data[i];
        }
        return data.size();
    }

    // Get color matching statistics
    int png_converter_get_color_stats(int* exactMatches, int* distanceMatches) {
        if (!converter) {
            *exactMatches = 0;
            *distanceMatches = 0;
            return 0;
        }
        converter->getColorMatchingStats(*exactMatches, *distanceMatches);
        return 1;
    }

    // Set palette by index
    int png_converter_set_palette(int paletteIndex) {
        if (paletteIndex < 0 || paletteIndex >= (int)NUM_PALETTES) {
            return 0; // Invalid palette index
        }
        CURRENT_PALETTE = &AVAILABLE_PALETTES[paletteIndex];
        return 1;
    }

    // Get number of available palettes
    int png_converter_get_palette_count() {
        return (int)NUM_PALETTES;
    }

    // Get palette name by index
    const char* png_converter_get_palette_name(int paletteIndex) {
        if (paletteIndex < 0 || paletteIndex >= (int)NUM_PALETTES) {
            return nullptr;
        }
        return AVAILABLE_PALETTES[paletteIndex].name;
    }

    // Get current palette index
    int png_converter_get_current_palette() {
        for (size_t i = 0; i < NUM_PALETTES; i++) {
            if (CURRENT_PALETTE == &AVAILABLE_PALETTES[i]) {
                return (int)i;
            }
        }
        return 0; // Fallback to first palette
    }

    // Get color RGB value from current palette
    int png_converter_get_palette_color(int colorIndex, int* r, int* g, int* b) {
        if (colorIndex < 0 || colorIndex >= 16) {
            return 0;
        }
        uint8_t cr, cg, cb;
        getRGB(CURRENT_PALETTE->colors[colorIndex], cr, cg, cb);
        *r = cr;
        *g = cg;
        *b = cb;
        return 1;
    }

    // Cleanup
    void png_converter_cleanup() {
        if (converter) {
            delete converter;
            converter = nullptr;
        }
    }
}