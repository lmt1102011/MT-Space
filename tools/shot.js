// Records the game and makes animated pictures out of it.
//
// It plays the exported game in a headless chrome, takes a picture every
// now and then and puts the pictures together as a looping animation.
//
// Usage: node tools/shot.js <url> <outfile> <count> <delayMs> [w] [h]

const { spawn } = require('child_process');
const http = require('http');
const path = require('path');
const os = require('os');
const fs = require('fs');

const CHROME = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';

function get(port, pathName) {
	return new Promise((resolve, reject) => {
		http.get({ host: '127.0.0.1', port, path: pathName }, (res) => {
			let data = '';
			res.on('data', (c) => (data += c));
			res.on('end', () => resolve(data));
		}).on('error', reject);
	});
}

async function waitFor(fn, tries = 120, delay = 500) {
	for (let i = 0; i < tries; i++) {
		try {
			const v = await fn();
			if (v) return v;
		} catch (e) { }
		await new Promise((r) => setTimeout(r, delay));
	}
	return null;
}

async function main() {
	const url = process.argv[2] || 'http://127.0.0.1:8099/index.html';
	const out = process.argv[3] || 'shot';
	const count = parseInt(process.argv[4] || '12', 10);
	const delay = parseInt(process.argv[5] || '250', 10);
	const width = parseInt(process.argv[6] || '640', 10);
	const height = parseInt(process.argv[7] || '360', 10);

	const port = 9222 + Math.floor(Math.random() * 500);
	const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'mtshot-'));
	const chrome = spawn(CHROME, [
		'--headless=new', '--disable-gpu', '--no-sandbox', '--disable-dev-shm-usage',
		'--use-gl=swiftshader', '--hide-scrollbars',
		'--window-size=' + width + ',' + height,
		'--remote-debugging-port=' + port, '--user-data-dir=' + profile, 'about:blank',
	], { stdio: ['ignore', 'pipe', 'pipe'] });

	const target = await waitFor(async () => {
		const list = JSON.parse(await get(port, '/json/list'));
		return list.find((x) => x.type === 'page');
	});
	if (!target) { console.log('FAIL: chrome did not start'); chrome.kill(); process.exit(1); }

	const WebSocket = require('ws');
	const ws = new WebSocket(target.webSocketDebuggerUrl);
	let id = 0;
	const pending = new Map();
	await new Promise((r) => ws.on('open', r));
	ws.on('message', (raw) => {
		const msg = JSON.parse(raw.toString());
		if (msg.id && pending.has(msg.id)) { pending.get(msg.id)(msg.result); pending.delete(msg.id); }
	});
	function send(method, params) {
		id += 1;
		const mid = id;
		return new Promise((resolve) => { pending.set(mid, resolve); ws.send(JSON.stringify({ id: mid, method, params: params || {} })); });
	}
	async function evaluate(expression) {
		const r = await send('Runtime.evaluate', { expression, returnByValue: true });
		return r.result ? r.result.value : undefined;
	}

	await send('Runtime.enable');
	await send('Page.enable');
	await send('Emulation.setDeviceMetricsOverride', {
		width, height, deviceScaleFactor: 1, mobile: false,
	});
	await send('Page.navigate', { url });

	// wait for the game to show up
	const booted = await waitFor(async () => {
		const gone = await evaluate("!document.getElementById('status')");
		return gone === true;
	}, 180, 1000);
	if (!booted) { console.log('FAIL: the game did not start'); ws.close(); chrome.kill(); process.exit(1); }

	const dir = path.dirname(out);
	if (dir && !fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
	const base = out.replace(/\.[a-z]+$/, '');
	console.log('saving frames into ' + dir);

	// let the game run a moment, then take the pictures
	await new Promise((r) => setTimeout(r, 2500));
	for (let i = 0; i < count; i++) {
		// move the ship around so the pictures are not all the same
		const key = i % 2 === 0 ? 'd' : 's';
		await evaluate("window.dispatchEvent(new KeyboardEvent('keydown', {key:'" + key + "'}))");
		await new Promise((r) => setTimeout(r, delay * 0.5));
		await evaluate("window.dispatchEvent(new KeyboardEvent('keyup', {key:'" + key + "'}))");
		const shot = await send('Page.captureScreenshot', { format: 'png' });
		if (shot && shot.data) {
			const name = base + '_' + String(i).padStart(4, '0') + '.png';
			fs.writeFileSync(name, Buffer.from(shot.data, 'base64'));
			console.log('frame ' + name);
		}
		await new Promise((r) => setTimeout(r, delay));
	}
	console.log('DONE ' + count + ' frames');

	ws.close();
	chrome.kill();
	process.exit(0);
}

main();
