#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import tempfile
import subprocess
import chardet
from gtags import Gtags

class GtagsCommand(object):

    _global_cmd = None
    @property
    def global_cmd(self): return self._global_cmd
    #@global_cmd.setter
    #def global_cmd(self, global_cmd): self._global_cmd = global_cmd

    _gtags_cmd = None
    @property
    def gtags_cmd(self): return self._gtags_cmd
    #@gtags_cmd.setter
    #def gtags_cmd(self, gtags_cmd): self._gtags_cmd = gtags_cmd

    _gtags_conf = None
    @property
    def gtags_conf(self): return self._gtags_conf
    @gtags_conf.setter
    def gtags_conf(self, gtags_conf): 
        if os.path.exists(gtags_conf):
            self._gtags_conf = gtags_conf

    _ignore_case = None
    @property
    def ignore_case(self): return self._ignore_case
    @ignore_case.setter
    def ignore_case(self, ignore_case): self._ignore_case = ignore_case

    _file_name = None
    @property
    def file_name(self): return self._file_name
    #@file_name.setter
    #def file_name(self, file_name): self._file_name = file_name

    _gtags_root = None
    @property
    def gtags_root(self):
        if not self._gtags_root:
            dir_path = self.__get_gtags_rootdir(self.__slash_all_path(self._file_name))
            if dir_path is None:
                #sys.stderr.write('Cannot find gtags root directory for [%s].' % (self._file_name))
                self._gtags_root = None
            else:
                self._gtags_root = self.__slash_all_path(dir_path)
        return self._gtags_root
    #@gtags_root.setter
    #def gtags_root(self, gtags_root): self._gtags_root = gtags_root

    _target_enc = None
    @property
    def target_enc(self): return self._target_enc
    #@target_enc.setter
    #def target_enc(self, target_enc): self._target_enc = target_enc

    _method = None
    #@property
    #def method(self): return self._method
    #@method.setter
    #def method(self, method): self._method = method

    _target_object = None
    #@property
    #def target_object(self): return self._target_object
    #@target_object.setter
    #def target_object(self, target_object): self._target_object = target_object

    _shell_flag = None
    #@property
    #def shell_flag(self): return self._shell_flag
    #@shell_flag.setter
    #def shell_flag(self, shell_flag): self._shell_flag = shell_flag

    def __init__(self, global_path=None, ignore_case=False):
        if os.name == 'nt':
            self._shell_flag = True
            global_name = 'global.exe'
            gtags_name = 'gtags.exe'
        else:
            self._shell_flag = False
            global_name = 'global'
            gtags_name = 'gtags'

        if global_path:
            global_command_path = os.path.join(global_path, global_name)
            global_cmd = global_command_path
            gtags_command_path = os.path.join(global_path, gtags_name)
            gtags_cmd = gtags_command_path
        else:
            global_cmd = global_name
            gtags_cmd = gtags_name

        if not os.path.exists(global_cmd):
            # Find global command in PATH.
            global_in_path = self.__which(global_name)
            if global_in_path:
                self._global_cmd = global_in_path[0]
            else:
                return
        else:
            self._global_cmd = global_cmd

        if not os.path.exists(gtags_cmd):
            # Find gtags command in PATH.
            gtags_in_path = self.__which(gtags_name)
            if gtags_in_path:
                self._gtags_cmd = gtags_in_path[0]
            else:
                return
        else:
            self._gtags_cmd = gtags_cmd

        self._ignore_case = ignore_case

    def __which(self, name, flags=os.X_OK):
        result = []
        exts = filter(None, os.environ.get('PATHEXT', '').split(os.pathsep))
        path = os.environ.get('PATH', None)
        if path is None:
            return []
        for p in os.environ.get('PATH', '').split(os.pathsep):
            p = os.path.join(p, name)
            if os.access(p, flags):
                result.append(p)
            for e in exts:
                pext = p + e
                if os.access(pext, flags):
                    result.append(pext)
        return result

    def __slash_all_path(self, path):
        path = path.replace(os.path.sep, u'/')
        return path

    def __print_error_if_pipe_has_it(self, pipe):
        # Check if pipe has at least 1 line of error(s) ,
        # then print it.
        line = pipe.stderr.readline()
        while line: 
            enc = chardet.detect(line)['encoding']
            line = line.decode(enc)
            self.print_message(line.strip(), 'warn', enc)
            line = pipe.stderr.readline()
    
    def __invoke_command(self, cmd_line):
        gtags_list = []
        for gtags in self.__run_global(cmd_line):
            gtags_list.append(gtags)

        self.display_result(self._gtags_root, gtags_list, self._target_enc)
    
    def __run_global(self, cmd_line):
        # Making temporary file for the purpose of avoiding a deadlock
        with tempfile.TemporaryFile() as f:
            with tempfile.TemporaryFile() as f_e:
                proc = subprocess.Popen(cmd_line,
                                        stdout=f,
                                        stderr=f_e,
                                        shell=self._shell_flag)

                ret_code = proc.wait()

                f_e.seek(0)
                line = f_e.readline()
                while line:
                    enc = chardet.detect(line)['encoding']
                    line = line.decode(enc)
                    self.print_message(line.strip(), 'warn', enc)
                    line = f_e.readline()

                f.seek(0)
                line = f.readline()
                while line:
                    enc = chardet.detect(line)['encoding']
                    line = line.decode(enc)
                    gtags = Gtags(line.strip())
                    yield gtags
                    line = f.readline()

    def __run_gtags(self, cmd_line):
        # Making temporary file for the purpose of avoiding a deadlock
        with tempfile.TemporaryFile() as f:
            with tempfile.TemporaryFile() as f_e:
                proc = subprocess.Popen(cmd_line,
                                        stdout=f,
                                        stderr=f_e,
                                        shell=self._shell_flag)
            
                ret_code = proc.wait()

                f_e.seek(0)
                line = f_e.readline()
                while line:
                    enc = chardet.detect(line)['encoding']
                    line = line.decode(enc)
                    self.print_message(line.strip(), 'info', enc)                     
                    line = f_e.readline()
    
                f.seek(0)
                line = f.readline()
                while line:
                    enc = chardet.detect(line)['encoding']
                    line = line.decode(enc)
                    self.print_message(line.strip(), 'info', enc)
                    line = f.readline()

    def __get_gtags_rootdir(self, file_path):
        cmd_line = [self._global_cmd, '-p']
        os.chdir(os.path.dirname(file_path))
        gtags_rootdir = None

        # Making temporary file for the purpose of avoiding a deadlock
        with tempfile.TemporaryFile() as f:
            with tempfile.TemporaryFile() as f_e:
                proc = subprocess.Popen(cmd_line,
                                        stdout=f,
                                        stderr=f_e,
                                        shell=self._shell_flag)

                ret_code = proc.wait()

                f_e.seek(0)
                line = f_e.readline()
                while line:
                    enc = chardet.detect(line)['encoding']
                    line = line.decode(enc)
                    self.print_message(line.strip(), 'warn', enc)
                    line = f_e.readline()

                f.seek(0)
                line = f.readline()
                if line:
                    enc = chardet.detect(line)['encoding']
                    line = line.decode(enc)
                    gtags_rootdir = line.strip()

        return gtags_rootdir

    def parse_args(self, args):
        if len(args) == 0:
            msg = u'Gtags: No argument is specified.'
            self.print_message(msg, 'warn')
            return False
        elif len(args) == 1:
            msg = u'Gtags: Not enough arguments are provided.'
            self.print_message(msg, 'warn')
            return False

        file_name = args[0]
        enc = chardet.detect(file_name)['encoding']
        file_name = file_name.decode(enc)
        file_name = os.path.abspath(file_name)

        if not os.path.exists(file_name):
            msg = u'Gtags: file [%s] does not exist.' % (file_name)
            self.gtags_command.print_message(msg, 'warn')
            self._file_name = None
            self._target_enc = None
            return False
        else:
            self._file_name = file_name
            self._target_enc = enc

        if len(args) == 2:
            if args[1] == '-f':
                # gtags -f <the file of the current buffer>
                #self.gtags_get_list_of_object(file_name)
                self._method = 'gtags_get_list_of_object'
            elif args[1] == '--gtags-remake':
                #self.remake_tags()
                self._method = 'remake_tags'
            elif args[1] == '--gtags-update' or args[1] == '-u':
                self._method = 'update_tags'
            else:
                # gtags -t <the item provided as the argument>
                #self.gtags_get_object_definition(args[1])
                self._target_object = args[1]
                self._method = 'gtags_get_object_definition'
        elif len(args) == 3:
            if args[1] == '-r':
                # gtags -r <the item provided as the argument>
                #self.gtags_get_object_reference(args[2])
                self._target_object = args[2]
                self._method = 'gtags_get_object_reference'
            elif args[1] == '-s':
                # gtags -s <the item provided as the argument>
                #self.gtags_get_symbol_reference(args[2])
                self._target_object = args[2]
                self._method = 'gtags_get_symbol_reference'
            elif args[1] == '-g':
                # gtags -g <the item provided as the argument>
                #self.gtags_grep(args[2])
                self._target_object = args[2]
                self._method = 'gtags_grep'
            elif args[1] == '--gtags-update' or args[1] == '-u':
                self._method = 'update_tags'
            else:
                return False
        else:
            return False

        return True

    def do_it(self):
        try:
            method = getattr(self, self._method)
        except AttributeError:
            msg = u'Gtags: method [%s] does not exist.' % self._method
            self.gtags_command.print_message(msg, 'warn')
            return False

        os.chdir(self.gtags_root)
        method()
        return True

    def gtags_get_list_of_object(self):
        file_relpath = os.path.relpath(self.__slash_all_path(self._file_name), start=self._gtags_root)
        file_relpath = self.__slash_all_path(file_relpath)
        file_relpath = file_relpath.encode(self._target_enc)
        if self._ignore_case:
            cmd_line = [self._global_cmd, '-x', '-a', '-f', '-i', file_relpath]
        else:
            cmd_line = [self._global_cmd, '-x', '-a', '-f', file_relpath]
        self.__invoke_command(cmd_line)

    def gtags_get_object_definition(self):
        if self._ignore_case:
            cmd_line = [self._global_cmd, '-x', '-a', '-i', self._target_object] 
        else:
            cmd_line = [self._global_cmd, '-x', '-a', self._target_object] 
        self.__invoke_command(cmd_line)
    
    def gtags_get_object_reference(self):
        if self._ignore_case:
            cmd_line = [self._global_cmd, '-x', '-a', '-r', '-i', self._target_object]
        else:
            cmd_line = [self._global_cmd, '-x', '-a', '-r', self._target_object]
        self.__invoke_command(cmd_line)

    def gtags_get_symbol_reference(self):
        if self._ignore_case:
            cmd_line = [self._global_cmd, '-x', '-a', '-s', '-i', self._target_object]    
        else:
            cmd_line = [self._global_cmd, '-x', '-a', '-s', self._target_object]    
        self.__invoke_command(cmd_line)
    
    def gtags_grep(self):
        if self._ignore_case:
            cmd_line = [self._global_cmd, '-x', '-a', '-g', '-i', self._target_object]    
        else:
            cmd_line = [self._global_cmd, '-x', '-a', '-g', self._target_object]    
        self.__invoke_command(cmd_line)

    def remake_tags(self):
        if self._gtags_conf == None:
            cmd_line = [self._gtags_cmd, '-v']
        else:
            cmd_line = [self._gtags_cmd, '-v', '--gtagsconf', self._gtags_conf]
        self.__run_gtags(cmd_line)

    def update_tags(self):
        if self._gtags_conf == None:
            cmd_line = [self._gtags_cmd, '-i', '-v']
        else:
            cmd_line = [self._gtags_cmd, '-i', '-v', '--gtagsconf', self._gtags_conf]
        self.__run_gtags(cmd_line)
