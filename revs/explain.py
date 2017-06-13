class Explanation:

    def __init__(self, source, target, path_list, type_dict):
        self.source_iri = '<' + source + '>'
        self.target_iri = '<' + target + '>'
        self.path_list = path_list
        self.type_dict = type_dict

        triple_set = set()
        for path in self._get_minimal_list():
            for segment in path:
                triple_set.add((segment[u's'], segment[u'p'], segment[u'o']))
        self.triples = [
            {
                u's': triple[0],
                u'p': triple[1],
                u'o': triple[2]
            }
            for triple in triple_set]

    def _get_minimal_list(self):
        result_list = list()
        neighbours_set = set()
        for path in self.path_list:
            for triple in path:
                neighbours_set.add((triple[u's'], triple[u'o']))
                neighbours_set.add((triple[u'o'], triple[u's']))
        for path in self.path_list:
            triple_list = []
            current = self.source_iri
            for triple in path:
                triple_list.append(current)
                if triple[u's'] == current:
                    current = triple[u'o']
                else:
                    current = triple[u's']
            triple_list.append(current)
            assert current == self.target_iri
            skip = False
            for dist in range(2, len(triple_list) - 1):
                for start in range(0, len(triple_list) - dist):
                    a = triple_list[start]
                    b = triple_list[start + dist]
                    if (a, b) in neighbours_set:
                        skip = True
                        break
                if skip:
                    break
            if skip:
                continue
            result_list.append(path)
        return result_list
