#!/usr/bin/python

import sys
import os


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
                if line.startswith('#'):
                    continue
                if line.startswith('@'):
                    raise NotImplementedError("@ directive cannot be digested now")
                f_tsv.write('\t'.join(line.split()[:3]))
                f_tsv.write('\n')


if __name__ == '__main__':
    if len(sys.argv) <= 1:
        print('Usage: %s a.ttl b.ttl...' % os.path.basename(sys.argv[0]))
        exit(1)
    for i in range(1, len(sys.argv)):
        convert(sys.argv[i])
