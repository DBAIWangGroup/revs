import json
import sys

import psycopg2
from elasticsearch import Elasticsearch

from revs import EntityIndexer, EntityDoc


def main():
    config_path = "config.json"
    if len(sys.argv) > 1:
        arg = sys.argv[1]
        if arg.endswith(".json"):
            config_path = arg
    with open(config_path) as f:
        config = json.load(f)
    base_uri = config['path']['base']
    indexer = EntityIndexer(config, Elasticsearch(config['elastic_search']['url']))
    with psycopg2.connect(config['postgres']['connection_string']) as pg_conn:
        with pg_conn.cursor() as cursor:
            facts_table = config['postgres'].get('facts_table')  # for legacy database compatibility
            if facts_table is None:
                facts_table = 'facts'
            entity_occ = {}
            cursor.execute("SELECT subject, count(*) FROM %s GROUP BY subject" % facts_table)
            for r in cursor.fetchall():
                uri = r[0][1:-1]
                num_occ = r[1]
                if uri.find(base_uri) < 0:
                    continue
                uri = uri[len(base_uri):]
                entity_occ[uri] = num_occ

            cursor.execute("SELECT object, count(*) FROM %s GROUP BY object" % facts_table)
            for r in cursor.fetchall():
                uri = r[0][1:-1]
                num_occ = r[1]
                if uri.find(base_uri) < 0:
                    continue
                uri = uri[len(base_uri):]
                num_existing_occ = entity_occ.get(uri)
                if num_existing_occ is None:
                    num_existing_occ = 0
                entity_occ[uri] = num_existing_occ + num_occ

            indexer.index((
                EntityDoc(uri.replace('_', ' '), base_uri + uri, num_occ)
                for uri, num_occ in entity_occ.items()
            ))


if __name__ == '__main__':
    main()
