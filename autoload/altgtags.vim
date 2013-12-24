let s:save_cpo = &cpo
set cpo&vim

function! s:LoadPythonModulePath()
    for l:i in split(globpath(&runtimepath, "altgtags_lib"), '\n')
        let s:python_module_path = fnamemodify(l:i, ":p")
    endfor
    python << EOF
import vim
import site

site.addsitedir(vim.eval('s:python_module_path'))
EOF
endfunction

function! altgtags#AltGtags(argline)

    call s:LoadPythonModulePath()

python << EOF
import os
import sys
import re
from altgtags.gtags_command import GtagsCommand

def print_message(self, msg, lvl='info', enc='utf_8'):
    msg = re.escape(msg)
    msg = msg.encode(enc)
    if lvl == 'info':
        vim.command('echo "%s"' % (msg))
    if lvl == 'warn':
        vim.command('echohl warningmsg | echo "%s" | echohl none' % (msg))

def display_result(self, gtags_root, gtags_list, target_enc):

    # no result found
    if len(gtags_list) == 0:
        msg = u'No result found.'
        self.print_message(msg, 'warn')
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

def main(args):
    global_path = None
    ignore_case = 'false'

    from types import MethodType
    GtagsCommand.print_message = MethodType(print_message, None, GtagsCommand)
    GtagsCommand.display_result = MethodType(display_result, None, GtagsCommand)

    ignore_case = True if ignore_case.lower() == 'true' else False
    gtags_command = GtagsCommand(global_path, ignore_case)

    if gtags_command.global_cmd is None:
        msg = 'Gtags: global command does not exist.' 
        gtags_command.print_message(msg, 'warn')
        return False

    if gtags_command.gtags_cmd is None:
        msg = 'Gtags: gtags command does not exist.' 
        gtags_command.print_message(msg, 'warn')
        return False

    ret = gtags_command.parse_args(args)
    if not ret:
        msg = 'Gtags: Failed to parse the arguments.' 
        gtags_command.print_message(msg, 'warn')
        return False

    ret = gtags_command.do_it()
    if not ret:
        msg = 'Gtags: Failed to run gtags.' 
        gtags_command.print_message(msg, 'warn')
        return False

args = []
args.append(vim.current.buffer.name)
argline = vim.eval('a:argline')

if argline == '':
    args.append(vim.eval('expand("<cword>")'))
else:
    arg_items = argline.split()
    if arg_items[0] == '-f':
        args.extend(arg_items)
    else:
        args.extend(arg_items)
        args.append(vim.eval('expand("<cword>")'))

main(args)

EOF
"------------------------------------------------------
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

