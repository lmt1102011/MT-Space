// Records several little movies of the game, they become the animated
// pictures on the website.
//
// Usage: node tools/record.js <url> <outfolder> <width> <height>

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

async function waitFor(fn, tries = 180, delay = 500) {
	for (let i = 0; i < tries; i++) {
		try {
			const v = await fn();
			if (v) return v;
		} catch (e) { }
		await new Promise((r) => setTimeout(r, delay));
	}
	return null;
}

// the little movies that are recorded
const SHOTS = [
	{ name: 'menu', query: '', frames: 30, delay: 120, keys: ['d', 'w'] },
	{ name: 'game', query: '?play=1', frames: 60, delay: 120, keys: ['d', 's', 'a', 'w'], shoot: true },
];

async function main() {
	const url = process.argv[2] || 'http://127.0.0.1:8099/game/index.html';
	const outdir = process.argv[3] || 'shots';
	const width = parseInt(process.argv[4] || '640', 10);
	const height = parseInt(process.argv[5] || '360', 10);

	const port = 9222 + Math.floor(Math.random() * 500);
	const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'mtrec-'));
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
	await send('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: 1, mobile: false });

	for (const shot of SHOTS) {
		const folder = path.join(outdir, shot.name);
		if (!fs.existsSync(folder)) fs.mkdirSync(folder, { recursive: true });
		await send('Page.navigate', { url: url + shot.query });
		const booted = await waitFor(async () => {
			const gone = await evaluate("!document.getElementById('status')");
			return gone === true;
		}, 180, 1000);
		if (!booted) { console.log('FAIL: the game did not start for ' + shot.name); continue; }

		await new Promise((r) => setTimeout(r, 2500));

		// The game shoots while the left mouse button is held, so the little
		// movie has to hold it down and aim around instead of only walking.
		let aimX = width * 0.72;
		let aimY = height * 0.42;
		if (shot.shoot) {
			await send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: aimX, y: aimY });
			await send('Input.dispatchMouseEvent', {
				type: 'mousePressed', x: aimX, y: aimY, button: 'left', buttons: 1, clickCount: 1,
			});
		}

		// hold the keys so the ship keeps moving, a tap now and then is not
		// enough to dodge the swarm while the mouse is busy shooting
		const walk = [['d'], ['d', 'w'], ['s', 'w'], ['s'], ['s', 'a'], ['a'], ['a', 'w'], ['w']];
		let held = [];

		for (let i = 0; i < shot.frames; i++) {
			let want;
			if (shot.shoot) {
				want = walk[Math.floor(i / 8) % walk.length];
			} else {
				want = [shot.keys[i % shot.keys.length]];
			}
			for (const key of held) {
				if (!want.includes(key)) {
					await evaluate("window.dispatchEvent(new KeyboardEvent('keyup', {key:'" + key + "'}))");
				}
			}
			for (const key of want) {
				if (!held.includes(key)) {
					await evaluate("window.dispatchEvent(new KeyboardEvent('keydown', {key:'" + key + "'}))");
				}
			}
			held = want;
			if (shot.shoot) {
				aimX = width * (0.62 + 0.20 * Math.sin(i * 0.55));
				aimY = height * (0.42 + 0.18 * Math.cos(i * 0.42));
				await send('Input.dispatchMouseEvent', {
					type: 'mouseMoved', x: aimX, y: aimY, button: 'left', buttons: 1,
				});
			}
			await new Promise((r) => setTimeout(r, shot.delay));
			const pic = await send('Page.captureScreenshot', { format: 'png' });
			if (pic && pic.data) {
				fs.writeFileSync(path.join(folder, 'frame_' + String(i).padStart(4, '0') + '.png'),
					Buffer.from(pic.data, 'base64'));
			}
		}
		for (const key of held) {
			await evaluate("window.dispatchEvent(new KeyboardEvent('keyup', {key:'" + key + "'}))");
		}
		if (shot.shoot) {
			await send('Input.dispatchMouseEvent', {
				type: 'mouseReleased', x: aimX, y: aimY, button: 'left', buttons: 0, clickCount: 1,
			});
		}
		console.log('recorded ' + shot.name + ' (' + shot.frames + ' frames)');
	}

	ws.close();
	chrome.kill();
	process.exit(0);
}

main();
