# python server to handle POST request
import os, json
from flask import Flask, request
from orm import *

app = Flask(__name__)
app.debug = True

@app.route('/api', methods=['POST', 'GET'])
def post_signature():
	if request.method == 'POST':
		hash_str = os.urandom(16).encode('hex')
		data = json.loads(request.data)
		genes = data['genes']
		coefs = data['coefs']
		desc = data['desc']
		## save into the db
		add_associations(hash_str, genes, coefs, session, desc=desc)
		return hash_str

	elif request.method == 'GET':
		hash_str = request.args.get('id', '')
		genes, coefs = get_associations(hash_str, session)
		data = {'genes':genes, 'coefs':coefs}
		return json.dumps(data)

if __name__ == '__main__':
	app.run(port=5050)
	