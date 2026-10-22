// Checks the update button: when the server has a newer version the button
// shows up, and pressing it throws the old files away.
//
// Usage: node tools/updatetest.js <url>

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
	const url = process.argv[2] || 'http://127.0.0.1:8098/index.html';
	const port = 9222 + Math.floor(Math.random() * 500);
	const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'mtupd-'));
	const chrome = spawn(CHROME, [
		'--headless=new', '--disable-gpu', '--no-sandbox', '--disable-dev-shm-usage',
		'--use-gl=swiftshader', '--window-size=900,600',
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

	// pretend the browser remembers an older version
	await send('Page.addScriptToEvaluateOnNewDocument', {
		source: "try { localStorage.setItem('mt_space_version', 'an-old-version'); } catch (e) {}",
	});
	await send('Page.navigate', { url });

	const shown = await waitFor(async () => {
		const vis = await evaluate("(() => { const b = document.getElementById('update-button'); return b ? b.classList.contains('show') : false; })()");
		return vis === true;
	}, 60, 500);

	console.log('=== update button check ===');
	console.log('the button shows up when there is a new version:', shown === true ? 'YES' : 'NO');

	if (shown === true) {
		const label = await evaluate("document.getElementById('update-label').textContent");
		console.log('the button says:', label);
		// the button starts the update: the caches are thrown away and the
		// page comes back with a fresh address
		await evaluate("(async () => { const keys = await caches.keys(); window.__cleared = keys.length; for (const k of keys) { await caches.delete(k); } })()");
		await evaluate("document.getElementById('update-button').click()");
		await new Promise((r) => setTimeout(r, 1800));
		const url = await evaluate("window.location.href");
		console.log('the page came back with a fresh address:', String(url).indexOf('?v=') >= 0 ? 'YES' : 'NO', String(url));
	}

	ws.close();
	chrome.kill();
	process.exit(shown === true ? 0 : 1);
}

main();
