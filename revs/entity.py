from elasticsearch.helpers import bulk


class EntityDoc:
    def __init__(self, name, uri, num_occ):
        self.name = name
        self.uri = uri
        self.num_occ = num_occ


class EntityIndexer:
    def __init__(self, config, elastic_search):
        self._config = config
        self._elastic_search = elastic_search
        self._search_limit = self._config['entity']['search_limit']
        self._index_id = self._config['entity']['index_id']

    def search(self, key):
        """
        :param key: search key
        """
        res = self._elastic_search.search(index=self._index_id, doc_type="entity", body={
            "size": self._search_limit,
            "query": {
                "function_score": {
                    "query": {
                        "match": {
                            "name": {
                                "query": key,
                                "fuzziness": "AUTO",
                                "operator": "and"
                            }
                        }
                    },
                    "field_value_factor": {
                        "field": "num_occ"
                    }
                }
            }
        })
        results = []
        for hit in res['hits']['hits']:
            doc = hit['_source']
            results.append({
                'name': doc['name'],
                'url': doc['uri'],
                'score': hit['_score']
            })
        return results

    def index(self, entity_docs):
        bulk(self._elastic_search, [
            {
                '_index': self._index_id,
                '_type': "entity",
                '_source': {
                    'name': doc.name,
                    'uri': doc.uri,
                    'num_occ': doc.num_occ
                }
            }
            for doc in entity_docs
        ])
