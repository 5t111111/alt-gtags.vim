if exists('g:loaded_nu_gtags')
  finish
endif
let g:loaded_nu_gtags = 1

let s:save_cpo = &cpo
set cpo&vim

" Path to the executed script file
"let g:path_to_this = expand("<sfile>:p:h")

"-------------------------------------------------------
" Python World
"-------------------------------------------------------
function! s:NuGtags(argline)

python << EOF
import vim
import os
import tempfile

DEBUG = True

class Gtags(object):

	@property
	def name(self): return self._name
	#@name.setter
	#def name(self, name): self._name = name

	@property
	def linum(self): return self._linum
	#@linum.setter
	#def linum(self, linum): self._linum = linum

	@property
	def path(self): return self._path
	#@path.setter
	#def path(self, path): self._path = path

	@property
	def content(self): return self._content
	@content.setter
	def content(self, content): self._content = content

	def __init__(self, line):
		self.__parse(line)

	def __parse(self, line):
		max_split = 3 
		items = line.split(None, max_split)
		if not len(items) == 4:
			if DEBUG:
				print items
			sys.stderr.write('Unexpected result when parsing an output¥n')
			# if an unexpected result has occurred, fill a gtags object with dummy data
			self._name = 'N/A'
			self._linum = '0'
			self._path = 'N/A'
			self._content = 'N/A'
			return False
		else:
			self._name = items[0]
			self._linum = items[1]
			self._path = items[2]
			self._content =items[3]
			return True

class GtagsCommand(object):

	@property
	def gtags_root(self): return self._gtags_root
	#@gtags_root.setter
	#def gtags_root(self, gtags_root): self._gtags_root = gtags_root

	def __init__(self, file_path):
		dir_path = self.__find_gtags_rootdir(self.__slash_all_path(file_path))
		if dir_path == None:
			sys.stderr('ERROR: Cannot find gtags root directory for %s.' & (file_path))
			return None
		self._gtags_root = self.__slash_all_path(dir_path)		

	def __slash_all_path(self, path):
		return path.replace(os.path.sep, '/')

	def __output_to_stderr_if_pipe_has_errors(self, pipe):
		# Check if pipe has at least 1 line of error(s)
		line = pipe.stderr.readline()
		if line: 
			pipe.stderr.seek(0)
			for line in iter(pipe.stderr.readline, ''):
				sys.stderr.write(line)
	
	def __do_it(self, cmd_line):
		os.chdir(self._gtags_root)
		gtags_list = []
		for gtags in self.__run_global(cmd_line):
			gtags_list.append(gtags)
		self.__display_list_in_quickfix(gtags_list)
	
	def __run_global(self, cmd_line):
		
		# Making temporary file for the purpose of avoiding a deadlock
		with tempfile.TemporaryFile() as f:
			proc = subprocess.Popen(cmd_line,
									stdin=subprocess.PIPE,
									stdout=f,
									stderr=subprocess.PIPE,
									shell=True)
		
			ret_code = proc.wait()
			self.__output_to_stderr_if_pipe_has_errors(proc)
			f.seek(0)
	
			for line in iter(f.readline, ''):
				gtags = Gtags(line.strip())
				yield gtags
	
	def __find_gtags_rootdir(self, file_path):
		search_path = os.path.dirname(file_path)
	
		while True:
			files = os.listdir(search_path)
			if 'GTAGS' in files:
				return search_path
			if os.path.split(search_path)[1] == '':
				break
			else:
				search_path = os.path.split(search_path)[0]
	
		return None 

	def __display_list_in_quickfix(self, gtags_list):
		
		if len(gtags_list) == 0:
			return

		EFM_SEPARATOR = '[EFM_SEP]'
		GTAGS_EFM = EFM_SEPARATOR.join(['%f', '%l', '%m'])
	
		list_to_display = [] 
	
		for gtags in gtags_list:
			# replace single quates with double ones to avoid unexpected error or something
			gtags.content = gtags.content.replace("'", '"')
			s = EFM_SEPARATOR.join([gtags.path, gtags.linum, gtags.content])
			list_to_display.append(s) 
		
		# Saving the original efm
		vim.command('let l:efm_org = &efm')
		vim.command('let &efm = "%s"' % (GTAGS_EFM))
	
		vim.command('let l:list_to_display = %s' % (repr(eval('list_to_display'))))
		vim.command('cd %s' % (self.gtags_root))
		vim.command('botright copen')
		vim.command('cgete l:list_to_display')
		vim.command('wincmd p')
		vim.command('let &efm = l:efm_org')

	def gtags_get_list_of_object(self, file_fullpath):
		file_relpath = os.path.relpath(self.__slash_all_path(file_fullpath), start=self._gtags_root)
		cmd_line = ['global', '-x', '-f', self.__slash_all_path(file_relpath)]
		self.__do_it(cmd_line)

	def gtags_get_object_definition(self, def_to_find):
		cmd_line = ['global', '-x', def_to_find]	
		self.__do_it(cmd_line)
	
	def gtags_get_object_reference(self, ref_to_find):
		cmd_line = ['global', '-x', '-r', ref_to_find]	
		self.__do_it(cmd_line)

	def gtags_get_symbol_reference(self, sym_to_find):
		cmd_line = ['global', '-x', '-s', sym_to_find]	
		self.__do_it(cmd_line)
	
	def gtags_grep(self, str_to_grep):
		cmd_line = ['global', '-x', '-g', '-a', str_to_grep]	
		self.__do_it(cmd_line)

def main(arg_line):

	cur_buf_name = vim.current.buffer.name
	if cur_buf_name == None:
		return

	gtags_command = GtagsCommand(cur_buf_name)
	if gtags_command == None:
		sys.stderr.write('ERROR: An error has occurred.')
		return

	if not arg_line == '':
		args = arg_line.split()
	else:
		cword = vim.eval('expand("<cword>")')
		if cword == None or cword == '':
			# Since you need to put the cursor on a word, just exit the program.
			return
		else:
			# gtags <the word on which the cursor is>
			gtags_command.gtags_get_object_definition(cword)
			return

	if len(args) == 1:
		if args[0] == '-f':
			# gtags -f <the file of the current buffer>
			gtags_command.gtags_get_list_of_object(vim.current.buffer.name)
		elif args[0] == '-r':
			# gtags -r <the word on which the cursor is>
			cword = vim.eval('expand("<cword>")')
			gtags_command.gtags_get_object_reference(cword)
		elif args[0] == '-s':
			# gtags -s <the word on which the cursor is>
			cword = vim.eval('expand("<cword>")')
			gtags_command.gtags_get_symbol_reference(cword)
		else:
			# gtags -t <the item provided as the argument>
			gtags_command.gtags_get_object_definition(args[0])
	elif len(args) == 2:
		if args[0] == '-f':
			# gtags -f <the item provided as the argument>
			gtags_command.gtags_get_list_of_object(args[1])
		if args[0] == '-r':
			# gtags -r <the item provided as the argument>
			gtags_command.gtags_get_object_reference(args[1])
		if args[0] == '-s':
			# gtags -s <the item provided as the argument>
			gtags_command.gtags_get_symbol_reference(args[1])

main(vim.eval('a:argline'))

EOF
endfunction

" Define the set of NuGtags commands
command! -nargs=* NuGtags call s:NuGtags(<q-args>)

let &cpo = s:save_cpo
unlet s:save_cpo

