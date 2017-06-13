#!/usr/bin/python
import json
import logging
import sys
from functools import wraps

from flask import Flask, jsonify, request, session

from revs import KGService

############################################################################################
# Initialization
############################################################################################
app = Flask(__name__)
app.secret_key = b'\\x1e!\\xd7!\\xc9\\xc5\\xee\\xde\\x01!u5a\\xa6\\xdd3Nic{\\xfb\\xe7\\xcev'
config_path = "config.json"
if len(sys.argv) > 1:
    arg = sys.argv[1]
    if arg.endswith(".json"):
        config_path = arg
with open(config_path) as f_config:
    config = json.load(f_config)
logging.basicConfig(format='%(asctime)s %(name)s %(levelname)s: %(message)s',
                    datefmt='%m/%d/%Y %H:%M:%S',
                    level=config['logging']['level'])
service = KGService(config)


############################################################################################
# Authentication
############################################################################################
def check_login(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if not config['user']['allow_anonymous_access']:
            if 'user' not in session:
                return jsonify({'error': 'You have not logged in'}), 403
        return f(*args, **kwargs)

    return decorated


@app.route('/api/users/me')
def users_me():
    if 'user' in session:
        return jsonify(session['user'])
    else:
        return '', 204


@app.route('/api/users/register', methods=['POST'])
def users_register():
    if not config['user']['enable_register']:
        return jsonify(error="Sorry, register is disabled now."), 403
    if "name" not in request.json or "password" not in request.json:
        return jsonify(error="Bad Request"), 400
    new_user = service.add_user(request.json['name'], request.json['password'])
    return jsonify(new_user)


@app.route('/api/users/login', methods=['POST'])
def users_login():
    if "name" not in request.json or "password" not in request.json:
        return jsonify(error="Bad Request"), 400
    user = service.find_user(request.json['name'], request.json['password'])
    if user is None:
        return jsonify(error="User name or password is incorrect"), 400
    session['user'] = user
    return jsonify(user)


@app.route('/api/users/logout')
def users_logout():
    del session['user']
    return '', 204


############################################################################################
# Index page
############################################################################################
@app.route("/")
def index():
    return app.send_static_file("index.html")


############################################################################################
# APIs
############################################################################################
@app.route("/api/entity")
def search_entity():
    key = request.args.get('q')
    if key is None:
        results = []
    else:
        results = service.search_entity(key)
    return jsonify(results)


@app.route("/api/explain")
@check_login
def explain():
    source = request.args.get('source')
    target = request.args.get('target')
    if source is None or target is None:
        return jsonify(error="Bad Request"), 400
    max_length = int(request.args.get('maxLength', 3))
    exp = service.explain(source, target, max_length)
    return jsonify({
        'source': exp.source_iri,
        'target': exp.target_iri,
        'triples': exp.triples,
        'types': exp.type_dict
    })


@app.route("/api/types")
@check_login
def get_types():
    entity = request.args.get('entity')
    if entity is None:
        return jsonify(service.get_types(None))
    return jsonify(service.get_types(entity))


############################################################################################
# Main entry
############################################################################################
if __name__ == '__main__':
    app.run(**config['server'])
