//
//  CHelpers.swift
//  TheQuantizer
//
//  Created by Simon Rodriguez on 18/01/2019.
//  Copyright © 2019 Simon Rodriguez. All rights reserved.
//

import Foundation
import Cocoa


class InvalidFileError : NSError {
	
	init() {
		super.init(domain: "ApplicationDomain", code: 1, userInfo: [:])
		//self.localizedDescription = "Unable to open file."
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
}

extension NSImage {
	
	func rgbaRepresentation() -> UnsafeMutablePointer<UInt8> {
		//let baseImage = self.cgImage(forProposedRect: nil, context: nil, hints: [:])!
		
		
		let width = Int(self.size.width)
		let height = Int(self.size.height)
		
		let space = CGColorSpaceCreateDeviceRGB()
		let rawData = UnsafeMutablePointer<UInt8>.allocate(capacity: 4 * height * width * MemoryLayout<UInt8>.size)
		
		let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 4*width, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGImageByteOrderInfo.order32Big.rawValue)!
		let nsctx = NSGraphicsContext(cgContext: ctx, flipped: false)
		NSGraphicsContext.current = nsctx
		self.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
		
		let dataPtr = ctx.data!.bindMemory(to: UInt32.self, capacity: width*height)
		
		for y in 0..<height {
			for x in 0..<width {
				let rawCol = dataPtr[y*width+x]
				let alpha = Float((rawCol & 0xff000000) >> 24)/255.0
				if alpha > 0 {
					rawData[4*(y*width+x) + 0] = UInt8(Float((rawCol & 0x000000ff) >> 0 ) / alpha)
					rawData[4*(y*width+x) + 1] = UInt8(Float((rawCol & 0x0000ff00) >> 8 ) / alpha)
					rawData[4*(y*width+x) + 2] = UInt8(Float((rawCol & 0x00ff0000) >> 16) / alpha)
					rawData[4*(y*width+x) + 3] = UInt8(alpha*255)
				} else {
					rawData[4*(y*width+x) + 0] = 0
					rawData[4*(y*width+x) + 1] = 0
					rawData[4*(y*width+x) + 2] = 0
					rawData[4*(y*width+x) + 3] = 0
				}
				
			}
		}
		
		// De-alpha-premultiply.
//		for i in 0..<height {
//			for j in 0..<width {
//				let baseIndex = 4*(width*i+j)
//				let alpha = Float(rawData[baseIndex + 3])/255.0
//				if alpha > 0 {
//					rawData[baseIndex + 0] = UInt8(Float(rawData[baseIndex + 0]) / alpha)
//					rawData[baseIndex + 1] = UInt8(Float(rawData[baseIndex + 1]) / alpha)
//					rawData[baseIndex + 2] = UInt8(Float(rawData[baseIndex + 2]) / alpha)
//				}
//			}
//		}
		return rawData
	}
}

extension Double {
	func string(fractionDigits:Int) -> String {
		let formatter = NumberFormatter()
		formatter.minimumFractionDigits = 0
		formatter.minimumIntegerDigits = 1
		formatter.maximumFractionDigits = fractionDigits
		return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
	}
}

func populatePalette(palette: liq_palette) -> [liq_color] {
	var palcol : [liq_color] = Array<liq_color>(repeating: liq_color(r: 0, g: 0, b: 0, a: 0), count: 256)
	palcol[0] = palette.entries.0
	palcol[1] = palette.entries.1
	palcol[2] = palette.entries.2
	palcol[3] = palette.entries.3
	palcol[4] = palette.entries.4
	palcol[5] = palette.entries.5
	palcol[6] = palette.entries.6
	palcol[7] = palette.entries.7
	palcol[8] = palette.entries.8
	palcol[9] = palette.entries.9
	palcol[10] = palette.entries.10
	palcol[11] = palette.entries.11
	palcol[12] = palette.entries.12
	palcol[13] = palette.entries.13
	palcol[14] = palette.entries.14
	palcol[15] = palette.entries.15
	palcol[16] = palette.entries.16
	palcol[17] = palette.entries.17
	palcol[18] = palette.entries.18
	palcol[19] = palette.entries.19
	palcol[20] = palette.entries.20
	palcol[21] = palette.entries.21
	palcol[22] = palette.entries.22
	palcol[23] = palette.entries.23
	palcol[24] = palette.entries.24
	palcol[25] = palette.entries.25
	palcol[26] = palette.entries.26
	palcol[27] = palette.entries.27
	palcol[28] = palette.entries.28
	palcol[29] = palette.entries.29
	palcol[30] = palette.entries.30
	palcol[31] = palette.entries.31
	palcol[32] = palette.entries.32
	palcol[33] = palette.entries.33
	palcol[34] = palette.entries.34
	palcol[35] = palette.entries.35
	palcol[36] = palette.entries.36
	palcol[37] = palette.entries.37
	palcol[38] = palette.entries.38
	palcol[39] = palette.entries.39
	palcol[40] = palette.entries.40
	palcol[41] = palette.entries.41
	palcol[42] = palette.entries.42
	palcol[43] = palette.entries.43
	palcol[44] = palette.entries.44
	palcol[45] = palette.entries.45
	palcol[46] = palette.entries.46
	palcol[47] = palette.entries.47
	palcol[48] = palette.entries.48
	palcol[49] = palette.entries.49
	palcol[50] = palette.entries.50
	palcol[51] = palette.entries.51
	palcol[52] = palette.entries.52
	palcol[53] = palette.entries.53
	palcol[54] = palette.entries.54
	palcol[55] = palette.entries.55
	palcol[56] = palette.entries.56
	palcol[57] = palette.entries.57
	palcol[58] = palette.entries.58
	palcol[59] = palette.entries.59
	palcol[60] = palette.entries.60
	palcol[61] = palette.entries.61
	palcol[62] = palette.entries.62
	palcol[63] = palette.entries.63
	palcol[64] = palette.entries.64
	palcol[65] = palette.entries.65
	palcol[66] = palette.entries.66
	palcol[67] = palette.entries.67
	palcol[68] = palette.entries.68
	palcol[69] = palette.entries.69
	palcol[70] = palette.entries.70
	palcol[71] = palette.entries.71
	palcol[72] = palette.entries.72
	palcol[73] = palette.entries.73
	palcol[74] = palette.entries.74
	palcol[75] = palette.entries.75
	palcol[76] = palette.entries.76
	palcol[77] = palette.entries.77
	palcol[78] = palette.entries.78
	palcol[79] = palette.entries.79
	palcol[80] = palette.entries.80
	palcol[81] = palette.entries.81
	palcol[82] = palette.entries.82
	palcol[83] = palette.entries.83
	palcol[84] = palette.entries.84
	palcol[85] = palette.entries.85
	palcol[86] = palette.entries.86
	palcol[87] = palette.entries.87
	palcol[88] = palette.entries.88
	palcol[89] = palette.entries.89
	palcol[90] = palette.entries.90
	palcol[91] = palette.entries.91
	palcol[92] = palette.entries.92
	palcol[93] = palette.entries.93
	palcol[94] = palette.entries.94
	palcol[95] = palette.entries.95
	palcol[96] = palette.entries.96
	palcol[97] = palette.entries.97
	palcol[98] = palette.entries.98
	palcol[99] = palette.entries.99
	palcol[100] = palette.entries.100
	palcol[101] = palette.entries.101
	palcol[102] = palette.entries.102
	palcol[103] = palette.entries.103
	palcol[104] = palette.entries.104
	palcol[105] = palette.entries.105
	palcol[106] = palette.entries.106
	palcol[107] = palette.entries.107
	palcol[108] = palette.entries.108
	palcol[109] = palette.entries.109
	palcol[110] = palette.entries.110
	palcol[111] = palette.entries.111
	palcol[112] = palette.entries.112
	palcol[113] = palette.entries.113
	palcol[114] = palette.entries.114
	palcol[115] = palette.entries.115
	palcol[116] = palette.entries.116
	palcol[117] = palette.entries.117
	palcol[118] = palette.entries.118
	palcol[119] = palette.entries.119
	palcol[120] = palette.entries.120
	palcol[121] = palette.entries.121
	palcol[122] = palette.entries.122
	palcol[123] = palette.entries.123
	palcol[124] = palette.entries.124
	palcol[125] = palette.entries.125
	palcol[126] = palette.entries.126
	palcol[127] = palette.entries.127
	palcol[128] = palette.entries.128
	palcol[129] = palette.entries.129
	palcol[130] = palette.entries.130
	palcol[131] = palette.entries.131
	palcol[132] = palette.entries.132
	palcol[133] = palette.entries.133
	palcol[134] = palette.entries.134
	palcol[135] = palette.entries.135
	palcol[136] = palette.entries.136
	palcol[137] = palette.entries.137
	palcol[138] = palette.entries.138
	palcol[139] = palette.entries.139
	palcol[140] = palette.entries.140
	palcol[141] = palette.entries.141
	palcol[142] = palette.entries.142
	palcol[143] = palette.entries.143
	palcol[144] = palette.entries.144
	palcol[145] = palette.entries.145
	palcol[146] = palette.entries.146
	palcol[147] = palette.entries.147
	palcol[148] = palette.entries.148
	palcol[149] = palette.entries.149
	palcol[150] = palette.entries.150
	palcol[151] = palette.entries.151
	palcol[152] = palette.entries.152
	palcol[153] = palette.entries.153
	palcol[154] = palette.entries.154
	palcol[155] = palette.entries.155
	palcol[156] = palette.entries.156
	palcol[157] = palette.entries.157
	palcol[158] = palette.entries.158
	palcol[159] = palette.entries.159
	palcol[160] = palette.entries.160
	palcol[161] = palette.entries.161
	palcol[162] = palette.entries.162
	palcol[163] = palette.entries.163
	palcol[164] = palette.entries.164
	palcol[165] = palette.entries.165
	palcol[166] = palette.entries.166
	palcol[167] = palette.entries.167
	palcol[168] = palette.entries.168
	palcol[169] = palette.entries.169
	palcol[170] = palette.entries.170
	palcol[171] = palette.entries.171
	palcol[172] = palette.entries.172
	palcol[173] = palette.entries.173
	palcol[174] = palette.entries.174
	palcol[175] = palette.entries.175
	palcol[176] = palette.entries.176
	palcol[177] = palette.entries.177
	palcol[178] = palette.entries.178
	palcol[179] = palette.entries.179
	palcol[180] = palette.entries.180
	palcol[181] = palette.entries.181
	palcol[182] = palette.entries.182
	palcol[183] = palette.entries.183
	palcol[184] = palette.entries.184
	palcol[185] = palette.entries.185
	palcol[186] = palette.entries.186
	palcol[187] = palette.entries.187
	palcol[188] = palette.entries.188
	palcol[189] = palette.entries.189
	palcol[190] = palette.entries.190
	palcol[191] = palette.entries.191
	palcol[192] = palette.entries.192
	palcol[193] = palette.entries.193
	palcol[194] = palette.entries.194
	palcol[195] = palette.entries.195
	palcol[196] = palette.entries.196
	palcol[197] = palette.entries.197
	palcol[198] = palette.entries.198
	palcol[199] = palette.entries.199
	palcol[200] = palette.entries.200
	palcol[201] = palette.entries.201
	palcol[202] = palette.entries.202
	palcol[203] = palette.entries.203
	palcol[204] = palette.entries.204
	palcol[205] = palette.entries.205
	palcol[206] = palette.entries.206
	palcol[207] = palette.entries.207
	palcol[208] = palette.entries.208
	palcol[209] = palette.entries.209
	palcol[210] = palette.entries.210
	palcol[211] = palette.entries.211
	palcol[212] = palette.entries.212
	palcol[213] = palette.entries.213
	palcol[214] = palette.entries.214
	palcol[215] = palette.entries.215
	palcol[216] = palette.entries.216
	palcol[217] = palette.entries.217
	palcol[218] = palette.entries.218
	palcol[219] = palette.entries.219
	palcol[220] = palette.entries.220
	palcol[221] = palette.entries.221
	palcol[222] = palette.entries.222
	palcol[223] = palette.entries.223
	palcol[224] = palette.entries.224
	palcol[225] = palette.entries.225
	palcol[226] = palette.entries.226
	palcol[227] = palette.entries.227
	palcol[228] = palette.entries.228
	palcol[229] = palette.entries.229
	palcol[230] = palette.entries.230
	palcol[231] = palette.entries.231
	palcol[232] = palette.entries.232
	palcol[233] = palette.entries.233
	palcol[234] = palette.entries.234
	palcol[235] = palette.entries.235
	palcol[236] = palette.entries.236
	palcol[237] = palette.entries.237
	palcol[238] = palette.entries.238
	palcol[239] = palette.entries.239
	palcol[240] = palette.entries.240
	palcol[241] = palette.entries.241
	palcol[242] = palette.entries.242
	palcol[243] = palette.entries.243
	palcol[244] = palette.entries.244
	palcol[245] = palette.entries.245
	palcol[246] = palette.entries.246
	palcol[247] = palette.entries.247
	palcol[248] = palette.entries.248
	palcol[249] = palette.entries.249
	palcol[250] = palette.entries.250
	palcol[251] = palette.entries.251
	palcol[252] = palette.entries.252
	palcol[253] = palette.entries.253
	palcol[254] = palette.entries.254
	palcol[255] = palette.entries.255
	return palcol
}
