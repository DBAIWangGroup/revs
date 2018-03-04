#!/usr/bin/python

import os
import sys


def convert(ttl_file):
    print('Processing %s...' % ttl_file)
    if ttl_file.endswith('.ttl'):
        tsv_file = ttl_file.replace('.ttl', '.tsv')
    elif ttl_file.endswith('.nt'):
        tsv_file = ttl_file.replace('.nt', '.tsv')
    else:
        raise RuntimeError("File type not supported: %s" % ttl_file)
    with open(ttl_file) as f_ttl:
        with open(tsv_file, 'w') as f_tsv:
            for line in f_ttl:
                line = line.strip()
                if line.startswith('#'):
                    continue
                if line.startswith('@'):
                    raise NotImplementedError("@ directive cannot be digested now")
                assert line[-1] == '.', line
                line = line[:-1].strip()
                predicate_start = None
                object_start = None
                for pos, ch in enumerate(line):
                    if ch == ' ':
                        if predicate_start is None:
                            predicate_start = pos + 1
                            continue
                        if object_start is None:
                            object_start = pos + 1
                            break
                subject = line[:predicate_start - 1]
                predicate = line[predicate_start:object_start - 1]
                obj = line[object_start:]
                f_tsv.write('\t'.join((subject, predicate, obj)))
                f_tsv.write('\n')


if __name__ == '__main__':
    if len(sys.argv) <= 1:
        print('Usage: %s a.ttl b.ttl...' % os.path.basename(sys.argv[0]))
        exit(1)
    for i in range(1, len(sys.argv)):
        convert(sys.argv[i])
