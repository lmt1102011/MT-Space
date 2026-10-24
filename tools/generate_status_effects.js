const fs = require("node:fs");
const path = require("node:path");
const zlib = require("node:zlib");

let size = 192;
let pixels = Buffer.alloc(size * size * 4);

function blend(x, y, color, alpha) {
	if (x < 0 || y < 0 || x >= size || y >= size || alpha <= 0) return;
	const index = (y * size + x) * 4;
	const oldAlpha = pixels[index + 3] / 255;
	const outAlpha = alpha + oldAlpha * (1 - alpha);
	for (let channel = 0; channel < 3; channel++) {
		const old = pixels[index + channel] / 255;
		pixels[index + channel] = Math.round(
			((color[channel] * alpha + old * oldAlpha * (1 - alpha)) / outAlpha) * 255,
		);
	}
	pixels[index + 3] = Math.round(outAlpha * 255);
}

function ellipse(cx, cy, rx, ry, color, opacity, soft = false) {
	const left = Math.max(0, Math.floor(cx - rx));
	const right = Math.min(size - 1, Math.ceil(cx + rx));
	const top = Math.max(0, Math.floor(cy - ry));
	const bottom = Math.min(size - 1, Math.ceil(cy + ry));
	for (let y = top; y <= bottom; y++) {
		for (let x = left; x <= right; x++) {
			const dx = (x + 0.5 - cx) / rx;
			const dy = (y + 0.5 - cy) / ry;
			const distance = Math.sqrt(dx * dx + dy * dy);
			if (distance >= 1) continue;
			const edge = soft ? Math.pow(1 - distance, 2) : 1;
			blend(x, y, color, opacity * edge);
		}
	}
}

function polygon(points, color, opacity) {
	const minX = Math.max(0, Math.floor(Math.min(...points.map((p) => p[0]))));
	const maxX = Math.min(size - 1, Math.ceil(Math.max(...points.map((p) => p[0]))));
	const minY = Math.max(0, Math.floor(Math.min(...points.map((p) => p[1]))));
	const maxY = Math.min(size - 1, Math.ceil(Math.max(...points.map((p) => p[1]))));
	for (let y = minY; y <= maxY; y++) {
		for (let x = minX; x <= maxX; x++) {
			let inside = false;
			for (let i = 0, j = points.length - 1; i < points.length; j = i++) {
				const [xi, yi] = points[i];
				const [xj, yj] = points[j];
				if ((yi > y) !== (yj > y) && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) {
					inside = !inside;
				}
			}
			if (inside) blend(x, y, color, opacity);
		}
	}
}

function ring(cx, cy, outerRadius, innerRadius, color, opacity, startAngle = 0, endAngle = Math.PI * 2) {
	const left = Math.max(0, Math.floor(cx - outerRadius));
	const right = Math.min(size - 1, Math.ceil(cx + outerRadius));
	const top = Math.max(0, Math.floor(cy - outerRadius));
	const bottom = Math.min(size - 1, Math.ceil(cy + outerRadius));
	for (let y = top; y <= bottom; y++) {
		for (let x = left; x <= right; x++) {
			const distance = Math.hypot(x + 0.5 - cx, y + 0.5 - cy);
			if (distance <= outerRadius && distance >= innerRadius) {
				const turn = Math.PI * 2;
				const angle = (Math.atan2(y + 0.5 - cy, x + 0.5 - cx) + turn) % turn;
				const start = (startAngle + turn) % turn;
				const end = (endAngle + turn) % turn;
				const inArc = start <= end
					? angle >= start && angle <= end
					: angle >= start || angle <= end;
				if (!inArc) continue;
				const edge = Math.min(distance - innerRadius, outerRadius - distance);
				blend(x, y, color, opacity * Math.min(1, edge / 2));
			}
		}
	}
}

function writePng(filename) {
	const rows = Buffer.alloc((size * 4 + 1) * size);
	for (let y = 0; y < size; y++) {
		const row = y * (size * 4 + 1);
		rows[row] = 0;
		pixels.copy(rows, row + 1, y * size * 4, (y + 1) * size * 4);
	}
	const crcTable = Array.from({ length: 256 }, (_, value) => {
		let crc = value;
		for (let bit = 0; bit < 8; bit++) crc = crc & 1 ? 0xedb88320 ^ (crc >>> 1) : crc >>> 1;
		return crc >>> 0;
	});
	function chunk(type, data) {
		const name = Buffer.from(type);
		const body = Buffer.concat([name, data]);
		let crc = 0xffffffff;
		for (const byte of body) crc = crcTable[(crc ^ byte) & 0xff] ^ (crc >>> 8);
		const result = Buffer.alloc(12 + data.length);
		result.writeUInt32BE(data.length, 0);
		name.copy(result, 4);
		data.copy(result, 8);
		result.writeUInt32BE((crc ^ 0xffffffff) >>> 0, 8 + data.length);
		return result;
	}
	const header = Buffer.alloc(13);
	header.writeUInt32BE(size, 0);
	header.writeUInt32BE(size, 4);
	header[8] = 8;
	header[9] = 6;
	const png = Buffer.concat([
		Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
		chunk("IHDR", header),
		chunk("IDAT", zlib.deflateSync(rows, { level: 9 })),
		chunk("IEND", Buffer.alloc(0)),
	]);
	fs.writeFileSync(path.join(__dirname, "..", "assets", filename), png);
}

pixels.fill(0);
ellipse(96, 96, 48, 48, [1.0, 0.12, 0.015], 0.72, true);
ellipse(96, 96, 37, 37, [1.0, 0.20, 0.015], 0.92, true);
ellipse(96, 96, 27, 27, [1.0, 0.48, 0.035], 0.96, true);
ellipse(93, 92, 16, 16, [1.0, 0.82, 0.16], 0.98, true);
ellipse(90, 89, 8, 8, [1.0, 0.98, 0.62], 0.96, true);
writePng("burn_effect.png");

pixels.fill(0);
ellipse(96, 96, 71, 71, [0.12, 0.65, 1.0], 0.13, true);
const ice = [0.43, 0.86, 1.0];
const iceLight = [0.83, 0.97, 1.0];
const vertices = [];
for (let i = 0; i < 12; i++) {
	const angle = (Math.PI * 2 * i) / 12 - Math.PI / 2;
	const radius = i % 2 === 0 ? 83 : 72;
	vertices.push([96 + Math.cos(angle) * radius, 96 + Math.sin(angle) * radius]);
}
for (let i = 0; i < vertices.length; i++) {
	const a = vertices[i];
	const b = vertices[(i + 1) % vertices.length];
	const inward = [96 + (a[0] - 96) * 0.72, 96 + (a[1] - 96) * 0.72];
	polygon([a, b, inward], i % 2 ? iceLight : ice, 0.82);
}
for (let i = 0; i < 8; i++) {
	const angle = (Math.PI * 2 * i) / 8 - Math.PI / 2;
	const direction = [Math.cos(angle), Math.sin(angle)];
	const center = [96 + direction[0] * 72, 96 + direction[1] * 72];
	const side = [-direction[1] * 5, direction[0] * 5];
	polygon([
		[center[0] - side[0], center[1] - side[1]],
		[center[0] + side[0], center[1] + side[1]],
		[96 + direction[0] * 93, 96 + direction[1] * 93],
	], iceLight, 0.95);
}
for (let y = 0; y < size; y++) {
	for (let x = 0; x < size; x++) {
		const dx = x + 0.5 - 96;
		const dy = y + 0.5 - 96;
		if (dx * dx + dy * dy < 56 * 56) {
			pixels.fill(0, (y * size + x) * 4, (y * size + x) * 4 + 4);
		}
	}
}
writePng("freeze_effect.png");

size = 384;
pixels = Buffer.alloc(size * size * 4);
const chargeCenter = 192;
ellipse(chargeCenter, chargeCenter, 180, 180, [0.10, 1.0, 0.35], 0.28, true);
ring(chargeCenter, chargeCenter, 174, 165, [0.12, 1.0, 0.38], 0.48);
ring(chargeCenter, chargeCenter, 168, 163, [0.47, 1.0, 0.62], 0.94, -0.15, 2.24);
ring(chargeCenter, chargeCenter, 168, 163, [0.47, 1.0, 0.62], 0.94, 2.48, 4.15);
ring(chargeCenter, chargeCenter, 168, 163, [0.47, 1.0, 0.62], 0.94, 4.45, 6.05);
for (let i = 0; i < 18; i++) {
	const angle = (Math.PI * 2 * i) / 18;
	const distance = i % 2 ? 155 : 170;
	const cx = chargeCenter + Math.cos(angle) * distance;
	const cy = chargeCenter + Math.sin(angle) * distance;
	ellipse(cx, cy, i % 3 === 0 ? 5 : 3, i % 3 === 0 ? 5 : 3,
		[0.84, 1.0, 0.87], 0.85);
}
for (let i = 0; i < 12; i++) {
	const angle = (Math.PI * 2 * i) / 12 + 0.13;
	const inner = 144;
	const outer = i % 3 === 0 ? 158 : 151;
	const side = 2;
	const direction = [Math.cos(angle), Math.sin(angle)];
	const perpendicular = [-direction[1] * side, direction[0] * side];
	polygon([
		[chargeCenter + direction[0] * inner + perpendicular[0], chargeCenter + direction[1] * inner + perpendicular[1]],
		[chargeCenter + direction[0] * inner - perpendicular[0], chargeCenter + direction[1] * inner - perpendicular[1]],
		[chargeCenter + direction[0] * outer - perpendicular[0] * 0.45, chargeCenter + direction[1] * outer - perpendicular[1] * 0.45],
		[chargeCenter + direction[0] * outer + perpendicular[0] * 0.45, chargeCenter + direction[1] * outer + perpendicular[1] * 0.45],
	], [0.64, 1.0, 0.72], 0.5);
}
writePng("charger_charge.png");

pixels.fill(0);
for (let i = 0; i < 11; i++) {
	const lane = 54 + i * 27;
	const originX = 230 + (i % 4) * 8;
	const endX = 24 + (i % 5) * 14;
	const bend = (i % 3 - 1) * 9;
	const outer = i % 4 === 0 ? 5.5 : 3.2;
	polygon([
		[originX, lane - outer],
		[originX - 24, lane + bend - outer * 0.55],
		[endX + 20, lane + bend - outer * 0.22],
		[endX, lane + bend],
		[endX + 20, lane + bend + outer * 0.22],
		[originX - 24, lane + bend + outer * 0.55],
		[originX, lane + outer],
	], i % 3 === 0 ? [0.88, 1.0, 0.88] : [0.46, 1.0, 0.64], i % 3 === 0 ? 0.72 : 0.38);
	polygon([
		[originX - 7, lane - outer * 0.34],
		[endX + 25, lane + bend - outer * 0.12],
		[endX + 9, lane + bend],
		[endX + 25, lane + bend + outer * 0.12],
		[originX - 7, lane + outer * 0.34],
	], [0.94, 1.0, 0.96], i % 3 === 0 ? 0.68 : 0.32);
}
writePng("charger_dash.png");

pixels.fill(0);
for (let i = 0; i < 3; i++) {
	const cx = 130 + i * 62;
	const cy = 108 - i * 14;
	ellipse(cx, cy, 25 + i * 5, 22 + i * 4, [0.49, 1.0, 0.73], 0.18, true);
	ellipse(cx, cy, 10 + i * 2, 9 + i * 2, [0.75, 1.0, 0.84], 0.42, true);
}
writePng("charger_winded.png");