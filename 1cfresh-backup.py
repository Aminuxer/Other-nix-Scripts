#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Extract data-dumps (XML-backups) from 1Cfresh.com cloud
# Version : 2020-02-28 by Amin


username="corp-1cfreshbackuper"
password="MegaStrongAndGoodPassword4BackUP"

oneassfresh_accound_id=100500

server='https://1cfresh.com'

print ('1C-Fresh Backup script')
print ('   Server: '+server)
print ('   Login: '+username)

# Use standard libs - no external dependencies !!
import urllib.request
import json


# HTTP-401-Auth support
password_mgr = urllib.request.HTTPPasswordMgrWithDefaultRealm()   # Create password manager
password_mgr.add_password(None, server, username, password)       # Add login/pass to server in pwd-manager
opener = urllib.request.build_opener(urllib.request.HTTPBasicAuthHandler(password_mgr)) # object for authorized http req

urllib.request.install_opener(opener)     # Set as default opener for all urllib.request !!


# Get json with api version
url_getversion = server+'/a/adm/hs/ext_api/version'
try:
    json_version_obj = opener.open(url_getversion)
except Exception as e:
   print(e)
   exit(-1)

print ('   HTTP-Code ' + str(json_version_obj.getcode()) + ' from external '+json_version_obj.getheader('Server'))
json_version_str = json_version_obj.read().decode('utf-8')     # Read http-response and convert raw-bytes to UTF-8 string
#print (json_version_str)

json_ver = json.loads(json_version_str)
print ('   1C Major Ver: '+ str(json_ver['version']) + ' sm_version: ' + str(json_ver['sm_version']) + "\n")



# Get json with list of tenants (database objects)
url_tlist = server+'/a/adm/hs/ext_api/execute'
post_data = '{ "general": { "type": "ext", "method": "tenant/list", "debug": true }, "auth": {"account": ' + str(oneassfresh_accound_id) + '}}'

tlist_obj = urllib.request.urlopen(url_tlist, post_data.encode('utf-8'))
tlist_str = tlist_obj.read().decode('utf-8')     # req - read - decode
#print (tlist_str)

# Parse JSON
tjson_obj = json.loads(tlist_str)
tenants = tjson_obj['tenant']

dbs = {}   # Database properties by iD

for tenant in tenants:
    tid = tenant['id']
    print ('   ** БД: iD: ' + str(tid) + ' Version: ' + tenant['app_version'] + ' Name: '+ tenant['name'])
    dbs.setdefault(tid, {})
    dbs[tid]['ts'] = '1970-01-01T00:00:01'
    dbs[tid]['name'] = tenant['name']
    dbs[tid]['ver'] = tenant['app_version']

# print(dbs)
print ('\n')



# Get json with list of backups
url_blist = server+'/a/adm/hs/ext_api/execute'
post_data = '{ "general": { "type": "ext", "method": "backup/list", "debug": false }, "auth": {"account": ' + str(oneassfresh_accound_id) + '}}'

blist_obj = urllib.request.urlopen(url_blist, post_data.encode('utf-8'))
blist_str = blist_obj.read().decode('utf-8')     # req - read - decode
# print (blist_str)

# Parse JSON
bjson_obj = json.loads(blist_str)
backups = bjson_obj['backup']

for b in backups:
    tid = b['tenant']
    uuid = b['id']
    ts = b['timestamp']
    # print ('   ** Backup: UUiD: ' + str(uuid) + ' App iD: ' + str(tid) + ' TS: ' + ts + ' Name: '+ dbs[tid]['name'])
    if (ts > dbs[tid]['ts']):
       dbs[tid]['ts'] = ts
       dbs[tid]['uuid'] = uuid

# print(dbs)



# Prepare download
url_dlist = server+'/a/adm/hs/ext_api/execute'
for dl in dbs:
    uuid = dbs[dl]['uuid']
    name = dbs[dl]['name']
    ts = dbs[dl]['ts']
    post_data = '{ "id": "' + uuid + '", "general": { "version": 9, "type": "usr", "method": "backup/file_token/download", "debug": true }, \
         "auth": {"account": ' + str(oneassfresh_accound_id) + ', "type": "user" }}'
    # get download token for each most fresh backup
    dlist_obj = urllib.request.urlopen(url_dlist, post_data.encode('utf-8'))
    dlist_str = dlist_obj.read().decode('utf-8')     # req - read - decode
    # Parse JSON
    djson_obj = json.loads(dlist_str)
    token = djson_obj['token']
    url = djson_obj['url']
    error = djson_obj['general']['error']
    response = djson_obj['general']['response']
    print ('   ** Backup: UUiD: ' + str(uuid) + ' TS: ' + ts + ' Name: ' + name)
    print ('      Token: ' + str(token))
    if (error != False):
        print(dlist_str)
    else:
        fn = name + '_' + ts + '.zip'
        local_filename, headers = urllib.request.urlretrieve(url, filename=fn)
        print(headers)
