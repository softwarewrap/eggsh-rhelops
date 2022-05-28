if exists("did_load_filetypes")
  finish
endif
augroup filetypedetect
   au! BufNewFile,BufRead *.conf call SetFileTypeSH("sh")
augroup END
