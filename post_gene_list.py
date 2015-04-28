# to test server.py

import json
import requests

url = 'http://127.0.0.1:5050/api'
base_url = 'http://127.0.0.1:3838?id='

genes = ['GENE%s' % i for i in range(10)]
coefs = [i/10. for i in range(10)]

data = {'genes': genes, 'coefs': coefs, 'desc':'descriptions ...'}
headers = {'Content-type': 'application/json', 'Accept': 'text/plain'}
r = requests.post(url, data=json.dumps(data), headers=headers)
# print r.headers

paea_url = base_url + r.text
print paea_url

# from orm import *
# add_associations('test3', genes, coefs, session, desc='None')
