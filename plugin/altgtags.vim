if exists('g:loaded_altgtags')
  finish
endif
let g:loaded_altgtags = 1

" Define the set of AltGtags commands
command! -nargs=* AltGtags call altgtags#AltGtags(<q-args>)
