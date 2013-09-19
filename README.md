alt-gtags.vim
============

alt-gtags.vim is a plugin that enables you to use GNU GLOBAL (gtags) in a Vim.  
if_pyth is required as it is written in Python.

Installation
-------------

When using NeoBundle, add this in your .vimrc.

    NeoBundle '5t111111/alt-gtags.vim'

Usage
-------------

The tags are displayed in a QuickFix window by running the below commands. 

* AltGtags -f  
  Display the list of the objects of the current buffer on QuickFix window.
* AltGtags  
  Display the definition of the object where the cursor is positioned.
* AltGtags -r  
  Display the reference of the object where the cursor is positioned.
* AltGtags -s  
  Display the reference of the symbol where the cursor is positioned.

