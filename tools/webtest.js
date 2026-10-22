// Opens the exported game in a headless chrome and reports what happens:
// console messages, page errors and whether the canvas really shows the game.
//
// Usage: node tools/webtest.js <url>

const { spawn } = require('child_process');
const http = require('http');
const path = require('path');
const os = require('os');
const fs = require('fs');

const CHROME = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const url = process.argv[2] || 'https://lmt1102011.github.io/MT-Space/';

function get(port, pathName) {
	return new Promise((resolve, reject) => {
		http.get({ host: '127.0.0.1', port, path: pathName }, (res) => {
			let data = '';
			res.on('data', (c) => (data += c));
			res.on('end', () => resolve(data));
		}).on('error', reject);
	});
}

async function waitFor(fn, tries = 60, delay = 500) {
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
	const port = 9222 + Math.floor(Math.random() * 500);
	const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'mtweb-'));
	const chrome = spawn(CHROME, [
		'--headless=new',
		'--disable-gpu',
		'--no-sandbox',
		'--disable-dev-shm-usage',
		'--use-gl=swiftshader',
		'--window-size=1280,720',
		'--remote-debugging-port=' + port,
		'--user-data-dir=' + profile,
		'about:blank',
	], { stdio: ['ignore', 'pipe', 'pipe'] });

	let chromeErr = '';
	chrome.stderr.on('data', (d) => (chromeErr += d.toString()));

	const targets = await waitFor(async () => {
		const t = await get(port, '/json/list');
		const list = JSON.parse(t);
		return list.find((x) => x.type === 'page');
	});
	if (!targets) {
		console.log('FAIL: chrome did not start');
		console.log(chromeErr.slice(0, 500));
		chrome.kill();
		process.exit(1);
	}

	const WebSocket = require('ws');
	let ws;
	try {
		ws = new WebSocket(targets.webSocketDebuggerUrl);
	} catch (e) {
		console.log('FAIL: no websocket module (npm i ws)');
		chrome.kill();
		process.exit(1);
	}

	let id = 0;
	const pending = new Map();
	const logs = [];
	const errors = [];

	await new Promise((r) => ws.on('open', r));
	ws.on('message', (raw) => {
		const msg = JSON.parse(raw.toString());
		if (msg.id && pending.has(msg.id)) {
			pending.get(msg.id)(msg.result);
			pending.delete(msg.id);
			return;
		}
		if (msg.method === 'Runtime.consoleAPICalled') {
			const text = (msg.params.args || [])
				.map((a) => (a.value !== undefined ? a.value : a.description || a.type))
				.join(' ');
			logs.push(msg.params.type + ': ' + text);
		}
		if (msg.method === 'Runtime.exceptionThrown') {
			errors.push(msg.params.exceptionDetails.text + ' ' +
				(msg.params.exceptionDetails.exception || {}).description);
		}
	});

	function send(method, params) {
		id += 1;
		const mid = id;
		return new Promise((resolve) => {
			pending.set(mid, resolve);
			ws.send(JSON.stringify({ id: mid, method, params: params || {} }));
		});
	}

	await send('Runtime.enable');
	await send('Page.enable');
	await send('Page.navigate', { url });

	// give the game time to load and run
	await new Promise((r) => setTimeout(r, 25000));

	const probe = await send('Runtime.evaluate', {
		expression: `(() => {
			const c = document.getElementById('canvas');
			const gl = c && (c.getContext('webgl2') || c.getContext('webgl'));
			return JSON.stringify({
				canvas: !!c,
				w: c ? c.width : 0,
				h: c ? c.height : 0,
				hasGl: !!gl,
				status: document.getElementById('status') ? 'present' : 'gone',
				fsButton: !!document.getElementById('fullscreen'),
				fsText: document.getElementById('fullscreen') ? document.getElementById('fullscreen').textContent : '',
				stored: (function(){ try { return localStorage.getItem('mt_space_version') || ''; } catch(e) { return 'x'; } })(),
			});
		})()`,
		returnByValue: true,
	});

	console.log('=== web test ===');
	try {
		console.log('probe:', JSON.parse(probe.result.value));
	} catch (e) {
		console.log('probe failed:', e.message);
	}
	console.log('--- console (' + logs.length + ') ---');
	logs.slice(0, 15).forEach((l) => console.log('  ' + l));
	console.log('--- errors (' + errors.length + ') ---');
	errors.slice(0, 10).forEach((l) => console.log('  ' + l));

	ws.close();
	chrome.kill();
	process.exit(0);
}

main();
