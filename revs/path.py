import logging

from pymongo.errors import DocumentTooLarge

from . import Util


class PathFinder:
    def __init__(self, config, pg_conn, mongo_client):
        self._config = config
        self._pg_conn = pg_conn
        self._mongo_client = mongo_client
        self._logger = logging.getLogger(self.__class__.__name__)
        self._base_uri = self._config['path']['base']
        self._prefix_dict = self._config['path']['prefix']

    def find(self, source, target, max_length):
        self._logger.debug("[Start Finding Paths] source=%s target=%s", source, target)
        mongo_db = self._mongo_client[self._config['mongo']['db']]
        cache_table = mongo_db[self._config['mongo']['path_cache_table']]
        cursor = self._pg_conn.cursor()
        source_norm = u"<" + self._base_uri + source + u">"
        target_norm = u"<" + self._base_uri + target + u">"
        for length in range(1, max_length + 1):
            record = {"source": source, "target": target, "length": length}
            cache = cache_table.find_one(record)
            if cache is None:
                path_list = self._find_path(cursor, source_norm, target_norm, length)
                self._logger.debug("[Found Paths] length=%d count=%d", length, len(path_list))
                for path in path_list:
                    yield path
                record['path_list'] = path_list
                try:
                    cache_table.insert_one(record)
                except DocumentTooLarge:
                    self._logger.warn('[Path List Too Large] source: %s target: %s length: %d size: %d',
                                      source, target, length, len(path_list))
            else:
                path_list = cache[u'path_list']
                self._logger.debug("[Found Paths (in cache)] length=%d count=%d", length, len(path_list))
                for path in path_list:
                    yield path
        self._logger.debug("[Path Finding Finished]")

    def _find_path(self, cursor, source_norm, target_norm, length):
        path_list = []
        facts_table = self._config['postgres'].get('facts_table')  # for legacy database compatibility
        if facts_table is None:
            facts_table = 'facts'
        header = self._build_query_header(facts_table, length)
        flag = (1 << length) - 1
        while flag >= 0:
            body = self._build_query_body(flag, length)
            sql = cursor.mogrify(''.join([header, body, 'LIMIT 2000 ']), (source_norm, target_norm))
            self._logger.debug("[Query Path] %s", sql)
            cursor.execute(sql)
            for row in cursor.fetchall():
                path = []
                for i in range(0, length):
                    path.append({
                        u"s": self._clean_uri(row[i * 3]),
                        u"p": self._clean_uri(row[i * 3 + 1]),
                        u"o": self._clean_uri(row[i * 3 + 2])
                    })
                path_list.append(path)
            flag -= 1
        return path_list

    def _clean_uri(self, uri):
        return Util.compress_uri(uri, self._base_uri, self._prefix_dict)

    @staticmethod
    def _build_query_header(facts_table, path_length):
        select_fragments = []
        from_fragments = []
        for i in range(1, path_length + 1):
            if i > 1:
                select_fragments.append(', ')
                from_fragments.append(', ')
            select_fragments.append('f%d.subject, f%d.predicate, f%d.object ' % (i, i, i))
            from_fragments.append('%s f%d ' % (facts_table, i))
        return ''.join([
            'SELECT ',
            ''.join(select_fragments),
            'FROM ',
            ''.join(from_fragments),
            'WHERE '
        ])

    @staticmethod
    def _build_query_body(flag, path_length):
        body_fragments = []
        entities = []
        current_entity = None
        for i in range(1, path_length + 1):
            if (flag & 1) == 1:
                if i == 1:
                    body_fragments.append('f1.subject=%s ')  # string injection is delayed
                    entities.append('f1.subject')
                    current_entity = 'f1.object'
                else:
                    body_fragments.append(' AND %s=f%d.subject ' % (current_entity, i))
                    entities.append(current_entity)
                    current_entity = 'f%d.object' % i
            else:
                if i == 1:
                    body_fragments.append('f1.object=%s ')  # string injection is delayed
                    entities.append('f1.object')
                    current_entity = 'f1.subject'
                else:
                    body_fragments.append(' AND %s=f%d.object ' % (current_entity, i))
                    entities.append(current_entity)
                    current_entity = 'f%d.subject' % i
            if i == path_length:
                body_fragments.append(' AND %s=%%s ' % current_entity)
                entities.append(current_entity)
            flag >>= 1
        for i in range(path_length):
            for j in range(i + 2, path_length + 1):  # assume subject != object in the same triple
                if i == 0 and j == path_length:  # ignore source != target restriction
                    continue
                body_fragments.append(' AND %s<>%s ' % (entities[i], entities[j]))
        return ''.join(body_fragments)
