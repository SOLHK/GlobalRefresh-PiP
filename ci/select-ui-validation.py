import glob, json, os, pathlib, plistlib, subprocess, sys
channel = sys.argv[1]
expected = '27B5019j' if channel == 'beta' else '27A266a'
apps = []
for path in glob.glob('/Applications/Xcode*.app'):
    try:
        with open(path + '/Contents/version.plist', 'rb') as f:
            meta = plistlib.load(f)
        apps.append({'path': path, 'build': meta.get('ProductBuildVersion')})
    except OSError:
        pass
print(json.dumps(apps, indent=2), flush=True)
selected = next((a for a in apps if a['build'] == expected), None)
if not selected:
    sys.exit('Required Xcode build ' + expected + ' is not installed; no fallback.')
os.environ['DEVELOPER_DIR'] = selected['path'] + '/Contents/Developer'
subprocess.run(['xcodebuild', '-version'], check=True)
runtimes = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'runtimes', '-j']))['runtimes']
print(json.dumps(runtimes, indent=2), flush=True)
# Verify beta 2 against Apple's simulator catalog; simulator and device builds can differ.
if channel == 'beta':
    import urllib.request
    catalog = plistlib.loads(urllib.request.urlopen('https://devimages-cdn.apple.com/downloads/xcode/simulators/index2.dvtdownloadableindex', timeout=60).read())
    candidates = [r for r in catalog['downloadables'] if 'iOS 27.2' in r.get('name', '') and 'beta 2' in r.get('name', '').lower()]
    if not candidates:
        sys.exit('Apple simulator catalog has no identifiable iOS 27.2 beta 2 runtime; refusing to substitute beta 1.')
    builds = {r.get('simulatorVersion', {}).get('buildUpdate') for r in candidates}
else:
    builds = {'24A434'}
runtime = next((r for r in runtimes if r.get('isAvailable') and r.get('buildversion') in builds), None)
if not runtime:
    sys.exit('Required simulator runtime is unavailable. Expected: ' + repr(builds))
devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '-j']))['devices'].get(runtime['identifier'], [])
device = next((d for d in devices if d['name'].startswith('iPhone') and 'Pro' in d['name']), None)
if not device:
    sys.exit('No compatible iPhone simulator available')
subprocess.run(['xcrun', 'simctl', 'boot', device['udid']], check=device['state'] != 'Booted')
subprocess.run(['xcrun', 'simctl', 'bootstatus', device['udid'], '-b'], check=True)
with open(os.environ['GITHUB_ENV'], 'a') as f:
    f.write('DEVELOPER_DIR=' + os.environ['DEVELOPER_DIR'] + '\nSIMULATOR_ID=' + device['udid'] + '\n')
