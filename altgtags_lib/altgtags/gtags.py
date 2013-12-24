#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re

class Gtags(object):

    _name = None
    @property
    def name(self): return self._name
    #@name.setter
    #def name(self, name): self._name = name

    _linum = None
    @property
    def linum(self): return self._linum
    @linum.setter
    def linum(self, linum): self._linum = linum

    _path = None
    @property
    def path(self): return self._path
    @path.setter
    def path(self, path): self._path = path

    _content = None
    @property
    def content(self): return self._content
    @content.setter
    def content(self, content): self._content = content

    def __init__(self, line):
        self.__parse(line)

    def __parse(self, line):
        max_split = 2
        items = line.split(None, max_split)
        if not len(items) == 3:
            if DEBUG:
                print items
            #sys.stderr.write('Unexpected result when parsing an output\n')
            # if an unexpected result has occurred, fill a gtags object with dummy data
            self._name = u'N/A'
            self._linum = u'N/A'
            self._path = u'N/A'
            self._content = u'N/A'
            return False
        else:
            self._name = items[0]
            self._linum = items[1]
            p = re.compile('^.+?\s')
            m = p.match(items[2])
            if m:
                self._path = items[2][:m.end()].strip()
                self._content = items[2][m.end():].rstrip()
                return True
            else:
                self._path = u'N/A'
                self._content = u'N/A'
                return False

