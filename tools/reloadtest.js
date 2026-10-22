// Checks the automatic reload: a browser that still has the old version in
// its storage has to fetch the new one by itself.
//
// Usage: node tools/reloadtest.js <url>

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
	const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'mtreload-'));
	const chrome = spawn(CHROME, [
		'--headless=new', '--disable-gpu', '--no-sandbox', '--disable-dev-shm-usage',
		'--use-gl=swiftshader', '--window-size=1280,720',
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
	let navigations = 0;
	const logs = [];

	await new Promise((r) => ws.on('open', r));
	ws.on('message', (raw) => {
		const msg = JSON.parse(raw.toString());
		if (msg.id && pending.has(msg.id)) { pending.get(msg.id)(msg.result); pending.delete(msg.id); return; }
		if (msg.method === 'Page.frameNavigated' && msg.params.frame.parentId === undefined) {
			navigations += 1;
		}
		if (msg.method === 'Runtime.consoleAPICalled') {
			const text = (msg.params.args || []).map((a) => (a.value !== undefined ? a.value : a.description || a.type)).join(' ');
			logs.push(msg.params.type + ': ' + text);
		}
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
	await send('Page.navigate', { url });

	// wait for the game to boot
	await waitFor(async () => {
		const gone = await evaluate("!document.getElementById('status')");
		return gone === true;
	}, 120, 1000);

	const first = await evaluate("localStorage.getItem('mt_space_version') || ''");
	console.log('=== reload test ===');
	console.log('1. the version the browser remembers:', first);

	// pretend the browser still has an old version
	await evaluate("localStorage.setItem('mt_space_version', 'an-old-version-from-before'); 'set'");
	const navBefore = navigations;

	// reload the page, the page itself has to notice the new version
	await send('Page.reload', { ignoreCache: false });

	// after the caches were dropped the game has to download itself again,
	// so it takes a while before it is running
	const booted = await waitFor(async () => {
		const gone = await evaluate("!document.getElementById('status')");
		return gone === true;
	}, 150, 1000);

	// the page stores the version it saw, wait for that to happen
	const after = await waitFor(async () => {
		const v = await evaluate("localStorage.getItem('mt_space_version') || ''");
		return v === first ? v : null;
	}, 60, 1000);

	const extra = navigations - navBefore;
	console.log('2. the version after the reload:', after);
	console.log('3. the page loaded again on its own:', extra > 1 ? 'YES (' + extra + ' loads)' : 'NO (' + extra + ' load)');
	console.log('4. the game is running again:', booted === true ? 'YES' : 'NO');
	const ok = after === first && extra > 1 && booted === true;
	console.log('RESULT:', ok ? 'PASS' : 'FAIL');
	logs.slice(0, 8).forEach((l) => console.log('   ' + l));

	ws.close();
	chrome.kill();
	process.exit(ok ? 0 : 1);
}

main();
