# python server to handle POST request
import sys
from flask import Flask, request
from crossdomain import crossdomain

import rpy2.robjects as ro
ro.r('''
	source("api_funcs.R")
	''')
api_paea = ro.globalenv['api_paea']

app = Flask(__name__)
app.debug = False

@app.route('PAEA/api', methods=['POST', 'GET'])
@crossdomain(origin='*')
def post_signature():
	if request.method == 'POST':
		ids = request.form['ids'].split(',')
		library_name = request.form['backgroundType']
		print ids, library_name
		res = api_paea(ids, library_name)
		return list(res)[0]

	elif request.method == 'GET':
		return 'hello world'

if __name__ == '__main__':
	if len(sys.argv) > 1:
		port = int(sys.argv[1])
	else:
		port = 5000
	if len(sys.argv) > 2:
		host = sys.argv[2]
	else:
		host = '127.0.0.1'
	app.run(host=host, port=port)

