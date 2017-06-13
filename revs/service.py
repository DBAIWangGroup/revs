import psycopg2
from elasticsearch import Elasticsearch
from pymongo import MongoClient

from . import EntityIndexer
from . import Explanation
from . import PathFinder
from . import TypeResolver
from . import Users


class KGService:
    def __init__(self, config):
        self._config = config
        self._pg_conn = psycopg2.connect(self._config['postgres']['connection_string'])
        self._mongo_client = MongoClient(self._config['mongo']['url'])
        self._elastic_search = Elasticsearch(self._config['elastic_search']['url'])

        self._path_finder = PathFinder(self._config, self._pg_conn, self._mongo_client)
        self._entity_indexer = EntityIndexer(self._config, self._elastic_search)
        self._type_resolver = TypeResolver(self._config, self._pg_conn)
        self._users = Users(self._config, self._mongo_client)
        self._type_resolver.init()

    def __del__(self):
        self._pg_conn.close()
        self._mongo_client.close()

    def search_entity(self, key):
        return self._entity_indexer.search(key)

    def explain(self, source, target, max_length):
        path_list = list(self._path_finder.find(source, target, max_length))
        type_dict = self._type_resolver.get_types_for_paths(path_list)
        return Explanation(source, target, path_list, type_dict)

    def add_user(self, user_name, password):
        return self._users.add(user_name, password)

    def find_user(self, user_name, password):
        return self._users.find(user_name, password)

    def get_types(self, entity):
        if entity is None:
            return self._type_resolver.get_class_hierarchy()
        return self._type_resolver.get_types([entity])
