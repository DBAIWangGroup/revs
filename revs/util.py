class Util:
    def __init__(self):
        pass

    @staticmethod
    def compress_uri(uri, base_uri, prefix_map):
        uri = uri.strip('<>')
        if uri.startswith(base_uri):
            return '<' + uri[len(base_uri):] + '>'
        for prefix, prefix_uri in prefix_map.items():
            if uri.startswith(prefix_uri):
                return prefix + ':' + uri[len(prefix_uri):]
        return uri
