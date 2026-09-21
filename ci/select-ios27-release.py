import glob,json,os,pathlib,plistlib,subprocess,sys,urllib.request
root=pathlib.Path('simulator-evidence');root.mkdir(exist_ok=True)
expected_xcode='27A266a'
expected_os='24A434'
# Device firmware is 24A437; Apple's released simulator uses 24A434.
catalog_url='https://devimages-cdn.apple.com/downloads/xcode/simulators/index2.dvtdownloadableindex'
catalog=plistlib.loads(urllib.request.urlopen(catalog_url,timeout=30).read())
release=next((d for d in catalog['downloadables'] if d.get('name')=='iOS 27.0 Simulator Runtime' and d.get('simulatorVersion',{}).get('buildUpdate')==expected_os),None)
if release is None: sys.exit('Apple catalog does not confirm the required release simulator.')
(root/'apple-runtime-release.json').write_text(json.dumps(release,indent=2))
print('APPLE_RELEASE_RUNTIME='+json.dumps(release),flush=True)
apps=[]
for p in glob.glob('/Applications/Xcode*.app'):
 try:
  with open(p+'/Contents/version.plist','rb') as f: meta=plistlib.load(f)
  apps.append({'path':p,'build':meta.get('ProductBuildVersion')})
 except OSError: pass
print('Installed Xcode builds:',json.dumps(apps),flush=True)
(root/'xcode-inventory.json').write_text(json.dumps(apps,indent=2))
matching=[x for x in apps if x['build']==expected_xcode]
if not matching: sys.exit('Required released Xcode build 27A266a is unavailable; no fallback permitted.')
developer=str(pathlib.Path(matching[0]['path']).resolve()/'Contents/Developer')
os.environ['DEVELOPER_DIR']=developer
with open(os.environ['GITHUB_ENV'],'a') as f:f.write('DEVELOPER_DIR='+developer+'\n')
subprocess.run(['xcodebuild','-version'],check=True)
def runtimes():
 return json.loads(subprocess.check_output(['xcrun','simctl','list','runtimes','-j']))['runtimes']
def matches(r):
 return r.get('version')=='27.0' and r.get('buildversion')==expected_os and r.get('isAvailable')
rs=runtimes();print('Runtime inventory:',json.dumps(rs),flush=True)
if not any(matches(r) for r in rs):
 print('Requesting the exact released iOS build from Apple; no beta fallback.',flush=True)
 subprocess.run(['xcodebuild','-downloadPlatform','iOS','-buildVersion',expected_os,'-architectureVariant','arm64'],check=True,timeout=900)
 rs=runtimes()
(root/'runtime-inventory.json').write_text(json.dumps(rs,indent=2))
selected=next((r for r in rs if matches(r)),None)
if not selected:sys.exit('Exact iOS 27.0 simulator (24A434) runtime unavailable. Tests not run on a substitute.')
types=json.loads(subprocess.check_output(['xcrun','simctl','list','devicetypes','-j']))['devicetypes']
iphone=next((d for name in ['iPhone 18 Pro Max','iPhone 18 Pro','iPhone 17 Pro Max'] for d in types if d['name']==name),None)
if not iphone:sys.exit('No suitable iPhone simulator device type is installed.')
udid=subprocess.check_output(['xcrun','simctl','create','GlobalRefresh-iOS27-Release',iphone['identifier'],selected['identifier']],text=True).strip()
evidence={'xcodeBuild':expected_xcode,'developerDir':developer,'runtime':selected,'device':iphone,'udid':udid}
(root/'verified-environment.json').write_text(json.dumps(evidence,indent=2))
print('VERIFIED_RELEASE_ENVIRONMENT='+json.dumps(evidence),flush=True)
with open(os.environ['GITHUB_ENV'],'a') as f:f.write('SIMULATOR_ID='+udid+'\n')
subprocess.run(['xcrun','simctl','boot',udid],check=True)
subprocess.run(['xcrun','simctl','bootstatus',udid,'-b'],check=True)
