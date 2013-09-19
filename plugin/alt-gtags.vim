if exists('g:loaded_alt_gtags')
  finish
endif
let g:loaded_alt_gtags = 1

let s:save_cpo = &cpo
set cpo&vim

function! s:LoadPythonModulePath()
    for l:i in split(globpath(&runtimepath, "plugin/alt_gtags_lib"), '\n')
        let s:python_module_path = fnamemodify(l:i, ":p")
    endfor
    python << EOF
import vim
import site

site.addsitedir(vim.eval('s:python_module_path'))
EOF
endfunction

function! s:AltGtags(argline)

    call s:LoadPythonModulePath()

python << EOF
import vim
import os
import tempfile
import subprocess
import re
import chardet

DEBUG = True

class Gtags(object):

    @property
    def name(self): return self._name
    #@name.setter
    #def name(self, name): self._name = name

    @property
    def linum(self): return self._linum
    @linum.setter
    def linum(self, linum): self._linum = linum

    @property
    def path(self): return self._path
    @path.setter
    def path(self, path): self._path = path

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

class GtagsCommand(object):

    @property
    def global_cmd(self): return self._global_cmd
    #@global_cmd.setter
    #def global_cmd(self, global_cmd): self._global_cmd = global_cmd

    @property
    def gtags_conf(self): return self._gtags_conf
    @gtags_conf.setter
    def gtags_conf(self, gtags_conf): 
        if os.path.exists(gtags_conf):
            self._gtags_conf = gtags_conf

    @property
    def ignore_case(self): return self._ignore_case
    @ignore_case.setter
    def ignore_case(self, ignore_case): self._ignore_case = ignore_case

    @property
    def gtags_root(self): return self._gtags_root
    #@gtags_root.setter
    #def gtags_root(self, gtags_root): self._gtags_root = gtags_root

    @property
    def target_enc(self): return self._target_enc
    #@target_enc.setter
    #def target_enc(self, target_enc): self._target_enc = target_enc

    #@property
    #def shell_flag(self): return self._shell_flag
    #@shell_flag.setter
    #def shell_flag(self, shell_flag): self._shell_flag = shell_flag

    def __init__(self, file_path, enc):

        if os.name == 'nt':
            self._shell_flag = True
            global_name = 'global.exe'
            gtags_name = 'gtags.exe'
        else:
            self._shell_flag = False
            global_name = 'global'
            gtags_name = 'gtags'

        self._global_cmd = global_name
        dir_path = self.__get_gtags_rootdir(self.__slash_all_path(file_path))

        if dir_path == None:
            #sys.stderr.write('Cannot find gtags root directory for [%s].' % (file_path))
            self._gtags_root = None
        else:
            self._gtags_root = self.__slash_all_path(dir_path)

        self._target_enc = enc
        self._ignore_case = False

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
            PrintWrapper.print_message(line.strip(), 'warn', enc)
            line = pipe.stderr.readline()
    
    def __do_it(self, cmd_line):
        gtags_list = []
        for gtags in self.__run_global(cmd_line):
            gtags_list.append(gtags)

        PrintWrapper.display_result(self._gtags_root, gtags_list, self._target_enc)
    
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
                    PrintWrapper.print_message(line.strip(), 'warn', enc)
                    line = f_e.readline()

                f.seek(0)
                line = f.readline()
                while line:
                    enc = chardet.detect(line)['encoding']
                    line = line.decode(enc)
                    gtags = Gtags(line.strip())
                    yield gtags
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
                    PrintWrapper.print_message(line.strip(), 'warn', enc)
                    line = f_e.readline()

                f.seek(0)
                line = f.readline()
                if line:
                    enc = chardet.detect(line)['encoding']
                    line = line.decode(enc)
                    gtags_rootdir = line.strip()

        return gtags_rootdir

    def gtags_get_list_of_object(self, file_fullpath):
        file_relpath = os.path.relpath(self.__slash_all_path(file_fullpath), start=self._gtags_root)
        file_relpath = self.__slash_all_path(file_relpath)
        file_relpath = file_relpath.encode(self._target_enc)
        if self._ignore_case:
            cmd_line = [self._global_cmd, '-x', '-a', '-f', '-i', file_relpath]
        else:
            cmd_line = [self._global_cmd, '-x', '-a', '-f', file_relpath]
        self.__do_it(cmd_line)

    def gtags_get_object_definition(self, def_to_find):
        if self._ignore_case:
            cmd_line = [self._global_cmd, '-x', '-a', '-i', def_to_find] 
        else:
            cmd_line = [self._global_cmd, '-x', '-a', def_to_find] 
        self.__do_it(cmd_line)
    
    def gtags_get_object_reference(self, ref_to_find):
        if self._ignore_case:
            cmd_line = [self._global_cmd, '-x', '-a', '-r', '-i', ref_to_find]    
        else:
            cmd_line = [self._global_cmd, '-x', '-a', '-r', ref_to_find]    
        self.__do_it(cmd_line)

    def gtags_get_symbol_reference(self, sym_to_find):
        if self._ignore_case:
            cmd_line = [self._global_cmd, '-x', '-a', '-s', '-i', sym_to_find]    
        else:
            cmd_line = [self._global_cmd, '-x', '-a', '-s', sym_to_find]    
        self.__do_it(cmd_line)
    
    def gtags_grep(self, str_to_grep):
        if self._ignore_case:
            cmd_line = [self._global_cmd, '-x', '-a', '-g', '-i', str_to_grep]    
        else:
            cmd_line = [self._global_cmd, '-x', '-a', '-g', str_to_grep]    
        self.__do_it(cmd_line)

class PrintWrapper(object):

    @classmethod
    def print_message(cls, msg, lvl='info', enc='utf_8'):
        msg = re.escape(msg)
        msg = msg.encode(enc)
        if lvl == 'info':
            vim.command('echo "%s"' % (msg))
        if lvl == 'warn':
            vim.command('echohl warningmsg | echo "%s" | echohl none' % (msg))

    @classmethod
    def display_result(cls, gtags_root, gtags_list, target_enc):

        # no result found
        if len(gtags_list) == 0:
            msg = u'No result found.'
            cls.print_message(msg, 'warn')
            vim.command('cclose')
            return

        EFM_SEPARATOR = '[EFM_SEP]'
        GTAGS_EFM = EFM_SEPARATOR.join(['%f', '%l', '%m'])

        list_str = u'['

        for gtags in gtags_list:
            # replace single quates with double ones to avoid unexpected error or something
            gtags.content = gtags.content.replace("'", '"')

            s = EFM_SEPARATOR.join([gtags.path, gtags.linum, gtags.content])

            # create the string of the list format
            list_str = u"%s'%s'," % (list_str, s) 

        list_str = u'%s]' % list_str
        
        # Saving the original efm
        vim.command('let l:efm_org = &efm')
        vim.command('let &efm = "%s"' % (GTAGS_EFM))
        vim_enc = vim.eval('&encoding')
        list_str = list_str.encode(vim_enc, errors='replace')
        vim.command('let l:list_str = %s' % (list_str))

        gtags_root = gtags_root.encode(target_enc)
        
        vim.command('cd %s' % (gtags_root))
        vim.command('botright copen')
        vim.command('cgete l:list_str')
        vim.command('wincmd p')
        vim.command('let &efm = l:efm_org')

def main(arg_line):

    cur_buf_name = vim.current.buffer.name
    if cur_buf_name == None:
        msg = u'Gtags: Cannot get the name of the current buffer.'
        PrintWrapper.print_message(msg, 'warn')
        return

    enc = chardet.detect(cur_buf_name)['encoding']
    cur_buf_name = cur_buf_name.decode(enc)

    gtags_command = GtagsCommand(cur_buf_name, enc)
    if gtags_command.gtags_root == None:
        msg = 'Gtags: Cannot find the gtags root directory for [%s].' % (cur_buf_name)
        PrintWrapper.print_message(msg, 'warn')
        return

    os.chdir(gtags_command.gtags_root)

    if not arg_line == '':
        args = arg_line.split()
    else:
        cword = vim.eval('expand("<cword>")')
        if cword == None or cword == '':
            # Since you need to put the cursor on a word, just exit the program.
            return
        else:
            # gtags <the word on which the cursor is>
            msg = u'Gtags: Getting the definiton(s) of [%s].' % (cword)
            PrintWrapper.print_message(msg, lvl='info')
            gtags_command.gtags_get_object_definition(cword)
            return

    if len(args) == 1:
        if args[0] == '-f':
            # gtags -f <the file of the current buffer>
            msg = u'Gtags: Getting the list of the object(s) for [%s].' % (cur_buf_name)
            PrintWrapper.print_message(msg, lvl='info')
            gtags_command.gtags_get_list_of_object(cur_buf_name)
        elif args[0] == '-r':
            # gtags -r <the word on which the cursor is>
            cword = vim.eval('expand("<cword>")')
            msg = 'Gtags: Getting the reference(s) of [%s].' % (cword)
            PrintWrapper.print_message(msg, lvl='info')
            gtags_command.gtags_get_object_reference(cword)
        elif args[0] == '-s':
            # gtags -s <the word on which the cursor is>
            cword = vim.eval('expand("<cword>")')
            msg = 'Gtags: Getting the symbol reference(s) of [%s].' % (cword)
            PrintWrapper.print_message(msg, lvl='info')
            gtags_command.gtags_get_symbol_reference(cword)
        else:
            # gtags -t <the item provided as the argument>
            msg = u'Gtags: Getting the definiton(s) of [%s].' % (args[0])
            PrintWrapper.print_message(msg, lvl='info')
            gtags_command.gtags_get_object_definition(args[0])
    elif len(args) == 2:
        if args[0] == '-f':
            # gtags -f <the item provided as the argument>
            gtags_command.gtags_get_list_of_object(args[1])
        if args[0] == '-r':
            # gtags -r <the item provided as the argument>
            msg = 'Gtags: Getting the reference(s) of [%s].' % (args[1])
            PrintWrapper.print_message(msg, lvl='info')
            gtags_command.gtags_get_object_reference(args[1])
        if args[0] == '-s':
            # gtags -s <the item provided as the argument>
            msg = 'Gtags: Getting the symbol reference(s) of [%s].' % (args[1])
            PrintWrapper.print_message(msg, lvl='info')
            gtags_command.gtags_get_symbol_reference(args[1])

main(vim.eval('a:argline'))
EOF
"------------------------------------------------------
endfunction

" Define the set of AltGtags commands
command! -nargs=* AltGtags call s:AltGtags(<q-args>)

let &cpo = s:save_cpo
unlet s:save_cpo

