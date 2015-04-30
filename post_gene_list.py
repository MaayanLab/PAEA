# to test server.py

import json
import requests

url = 'http://amp.pharm.mssm.edu/Enrichr/addList'
base_url = 'http://127.0.0.1:3838?id='

genes = ['GENE%s' % i for i in range(20)]
coefs = [i/10. for i in range(20)]

gene_list = ''
for gene, coef in zip(genes, coefs):
	gene_list += '%s,%s\n'% (gene, coef)

data = {'list': gene_list, 'inputMethod': "PAEA", 'description':'descriptions ...'}
r = requests.post(url, files=data)
# print r.text

paea_url = base_url + str(json.loads(r.text)['userListId'])
print paea_url


