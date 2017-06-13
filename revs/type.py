import logging

from . import Util


class TypeResolver:
    def __init__(self, config, pg_conn):
        self._config = config
        self._pg_conn = pg_conn
        self._parent_class = dict()
        self._sub_classes = dict()
        self._class_hierarchy = dict()
        self._root_class = self._config['ontology']['root_class']
        self._prefix_dict = self._config['path']['prefix']
        self._base_uri = self._config['path']['base']
        self._enabled = self._config['ontology']['enabled']
        self._logger = logging.getLogger(self.__class__.__name__)

    def init(self):
        if not self._enabled:
            return
        self._logger.debug('[Query Type Hierarchy]')
        cursor = self._pg_conn.cursor()
        cursor.execute("SELECT subject,\"object\" FROM ontology "
                       "WHERE predicate='<http://www.w3.org/2000/01/rdf-schema#subClassOf>'")
        for row in cursor.fetchall():
            clazz = self._clean_uri(row[0])
            parent = self._clean_uri(row[1])
            if self._parent_class.get(clazz) is None or parent.startswith('dbo:'):
                self._parent_class[clazz] = parent
            parent_sub_classes = self._sub_classes.get(parent)
            if parent_sub_classes is None:
                parent_sub_classes = set()
                self._sub_classes[parent] = parent_sub_classes
            parent_sub_classes.add(clazz)
        queue = []
        root_dict = dict()
        self._class_hierarchy[self._root_class] = root_dict
        queue.append((self._root_class, root_dict))
        while len(queue) > 0:
            clazz, sub_class_dict = queue.pop()
            sub_classes = self._sub_classes.get(clazz)
            if sub_classes is None:
                continue
            for sub_class in sub_classes:
                new_sub_dict = dict()
                sub_class_dict[sub_class] = new_sub_dict
                queue.append((sub_class, new_sub_dict))
        self._logger.debug('[Type Hierarchy Loaded]')

    def _clean_uri(self, uri):
        return Util.compress_uri(uri, self._base_uri, self._prefix_dict)

    def get_class_hierarchy(self):
        return self._class_hierarchy

    def get_types_for_paths(self, path_list):
        entity_list = set()
        for path in path_list:
            for triple in path:
                entity_list.add(triple[u's'].strip('<>'))
                entity_list.add(triple[u'o'].strip('<>'))
        return self.get_types(list(entity_list))

    def get_types(self, entity_list):
        type_dict = dict()
        if not self._enabled:
            return type_dict
        batch_size = self._config['ontology']['batch_size']
        start = 0
        total = len(entity_list)
        while start < total:
            self._get_types(entity_list[start:start + batch_size], type_dict)
            start += batch_size
        return type_dict

    def _get_types(self, entity_list, type_dict):
        if len(entity_list) == 0:
            return
        entity_iri_list = ('<' + self._base_uri + entity + '>' for entity in entity_list)
        cursor = self._pg_conn.cursor()
        param_str = ','.join(('%s' for _ in range(len(entity_list))))
        sql = cursor.mogrify('SELECT entity, "type" FROM instanceTypes WHERE entity IN (%s)' % param_str,
                             tuple(entity_iri_list))
        self._logger.debug("[Query Entity Types] (%d) %s", len(entity_list), sql)
        cursor.execute(sql)
        for row in cursor.fetchall():
            entity = self._clean_uri(row[0])
            clazz = self._clean_uri(row[1])
            type_list = []
            while clazz is not None:
                type_list.append(clazz)
                clazz = self._parent_class.get(clazz)
            type_dict[entity] = type_list
        for entity in entity_list:
            entity_iri = '<' + entity + '>'
            if entity_iri not in type_dict:
                type_dict[entity_iri] = [self._root_class]
