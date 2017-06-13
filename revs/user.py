class Users:
    def __init__(self, config, mongo_client):
        self._config = config
        self._db = mongo_client[self._config['mongo']['db']]
        self._user_table = self._db[self._config['mongo']['user_table']]

    def add(self, user_name, password):
        inserted = self._user_table.insert_one({
            'name': user_name,
            'password': password
        })
        return {
            'id': str(inserted.inserted_id),
            'name': user_name
        }

    def find(self, user_name, password):
        user = self._user_table.find_one({
            'name': user_name,
            'password': password
        })
        if user is None:
            return None
        return {
            "id": str(user['_id']),
            "name": user['name']
        }
