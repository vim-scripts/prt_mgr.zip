"=============================================================================
" Global plugin to provide more flexible printing in VIM.
" File:    prt_mgr.vim
" Author:  Mike Williams (mrw@eandem.co.uk)
" Changed: 27th January 2004 
"
" See ":help prt_mgr" for details on setting up and use. 
"
" History:
" 1.0 - Use at your own peril! :-) 
" 1.1 - Add Duplex Print entry and tip to File menu - controled by dprtNoMenu.
"       Use a confirm dialog where possible - removed dprtNoGuiDialg.
" 1.2 - Add message saying whether printing even or odd pages.
" 2.0 - Revamp into general PrintManager plugin, adding support for Nup
" 	printing to duplex or simplex output, and printing simplex in reverse
" 	page order.  Make functions available for use in other VIM scripts and
" 	printexpr.
" 2.0a - Change of domain for contact.
" 2.1 - Added support for printing to file.  Corrected menu shortcut letter
" 	clash with standard file menu entries.  Revised help file.  Ensured
" 	temporary files are removed.
" 2.2 - Fix call to substitute() to force A/B paper sizes to lower case.	
"

" Finish if plugin already loaded
if exists("loaded_printmanager")
	finish
endif
let loaded_printmanager = 1

"~~~
" s:WarningMsg() Function to display highlighted warning messages.
" - message: Message to be displayed.
"
function! s:WarningMsg(message)
	echohl WarningMsg
	echo "prt_mgr.vim: ".a:message
	echohl None
endfunc

" Need VIM version 6.0 or greater
if version < 600
	call s:WarningMsg("Error: PrintManager requires VIM 6.0 or later.")
	finish
endif

" Do not load if PS printing not present in VIM
if !has("postscript") 
	call s:WarningMsg("Error: PS printing not enabled, PrintManager not loaded.")
	finish
endif

" Do not load if psselect and psnup are not installed.
if executable("psselect") != 1 || executable("psnup") != 1
	call s:WarningMsg("Error: psselect or psnup not installed, PrintManager not loaded.")
	finish
endif

" Handle old duplex plugin settings
if exists("g:dprtReverseOddPages")
	call s:WarningMsg("Warning: Detected old configuration variable - please use pmgrReverseOddPages")
	let g:pmgrReverseOddPages = g:dprtReverseOddPages
endif

" Default is to print duplex odd pages in order
if !exists("g:pmgrReverseOddPages") 
	let g:pmgrReverseOddPages = 0
endif
" Default is to print simplex pages in order
if !exists("g:pmgrReversePages") 
	let g:pmgrReversePages = 0
endif
" Default is to add menu entry
if !exists("g:pmgrNoMenu")
	let g:pmgrNoMenu = 0
endif

" Setup DuplexPrint command
if !exists(':DuplexPrint')
	com -nargs=? DuplexPrint :call <SID>DuplexPrint(<f-args>)
endif
" Setup Nup command (only does 2-up)
if !exists(':NupPrint')
	com -nargs=? NupPrint :call <SID>NupPrint(<f-args>)
endif

" Add print manager menu entries
if !g:pmgrNoMenu
	amenu 10.520 &File.Print\ D&uplex :DuplexPrint<CR>
	tmenu File.Print\ Duplex Starts manual duplex printing.
	amenu 10.530 &File.Print\ &2-up :NupPrint<CR>
	tmenu File.Print\ 2-up Starts N-up printing.
endif

"~~~
" <SID>DuplexPrint() - Convenience function to get a duplex print without any
" N-up printing, optionally to file.
" - ...:	a:1 - 1 - prompt for filename
"		      2 - use automatically generated name 
"
function! <SID>DuplexPrint(...)
	if a:0 == 0
		let rc = DoPrint(0, 1)
	else
		if a:1 =~ "[12]"
			let rc = DoPrint(0, 1, a:1)
		else
			call s:WarningMsg("Error: Invalid fileoption to DuplexPrint - ".a:1)
		endif
	endif
	return rc
endfunc

"~~~
" <SID>NupPrint() - Convenience function to get 2-up printing without duplex,
" optionally to file.
" - ...:	a:1 - 1 - prompt for filename
"		      2 - use automatically generated name 
"
function! <SID>NupPrint(...)
	if a:0 == 0
		let rc = DoPrint(2, 0)
	else
		if a:1 =~ "[12]"
			let rc = DoPrint(2, 0, a:1)
		else
			call s:WarningMsg("Error: Invalid fileoption to NupPrint - ".a:1)
		endif
	endif
	return rc
endfunc

"~~~
" PrintManager - The main Print Manager control logic.
" - printfile:	name of VIM print file.
" - nup:	number of pages to print per page, only valid if > 1. 
" - duplex:	print duplex if not 0.
" - ...:    	a:1 0 - use name given in next arg (a:2)
"  		    1 - prompt for a filename
"  		    2 - use automatically generated name 
"   		a:2 File to print to. (Empty string is uses automatic name)
" Use this function if you want to use PrintManager from an expression used by
" printexpr.  For example, to always print 2-up duplex use the following
" expression:
"
" 	set printexpr=PrintManager(v:fname_in,2,1)
"
" To print 2-up duplex to a file with automatic naming use:	
"
" 	set printexpr=PrintManager(v:fname_in,2,1,2)
"
function! PrintManager(tempfile, nup, duplex, ...)
	let rc = 0

	" Catch empty file name
	if a:tempfile == ''
		let x = delete(a:tempfile)
		return 1
	endif
	let filename = a:tempfile

	" Handle printing to file
	let outfile = ''
	if a:0 > 0
		if a:1 !~ "[0-2]"
			call s:WarningMsg("Error: Unknown file print option - ".a:1)
			let x = delete(filename)
			return 1
		endif
		if a:1 == 0
			" Use given filename
			if a:0 != 2
				call s:WarningMsg("Error: No filename given when expected.")
				let x = delete(filename)
				return 1
			endif
			if a:2 =~ "^\\s*$"
				call s:WarningMsg("Error: Print filename is empty.")
				let x = delete(filename)
				return 1
			endif
			let outfile = a:2

		else
			" Build automagic print filename
			let outfile = expand("%:t")
			if outfile == ""
				let outfile = "no file"
			elseif outfile !~ "\.ps$"
				let outfile = expand("%:t:r")
			endif
			let outfile = outfile.".ps"
			if a:1 == 1
				" Use automagic name as example in user prompt
				let outfile = inputdialog("Enter filename to print to: ", outfile)
				if !has("dialog_gui")
					echo "\n"
				endif
			endif
		endif
	endif

	" Handle Nup printing
	if a:nup > 1
		" Work out current paper size from printoptions
		let idx = matchend(&popt, "paper:")
		if idx >= 0
			" VIM uses A3, A4, etc, while psnup uses a3, a4, etc.
			let paper = substitute(matchstr(&popt, "[^,]*", idx), "^\\([AB]\\)", "\\l\\1", "")
		else
			" No paper defined - VIM defaults to a4
			let paper = "a4"
		endif

		" Generate n-up PS in new file.
		let printnupfile = tempname()
		let rc = s:DoPrintNup(filename, paper, a:nup, printnupfile)
		let x = delete(filename)
		if rc
			return rc
		endif

		" Use new PS file for subsequent printing
		let filename = printnupfile
		unlet printnupfile
	endif

	" Handle duplex or simplex printing
	if a:duplex
		let rc = s:DoDuplexPrint(filename, g:pmgrReverseOddPages, outfile)
	else
		" Handle printing simplex files in reverse page order
		if g:pmgrReversePages 
			let reversefile = tempname()
			let rc = s:ReversePages(filename, reversefile)
			let x = delete(filename)
			if rc
				return rc
			endif
			
			" Use reversed PS file for printing
			let filename = reversefile
			unlet reversefile
		endif

		let rc = s:PrintFile(filename, "Printing ...", outfile)
	endif

	" Delete the PS file
	let x = delete(filename)

	return rc
endfunc

"~~~
" DoPrint() - Function that can be used in other functions to print jobs using
" the Print Manager.
" - nup:	number of pages to print per page, only valid if > 1. 
" - duplex:	print duplex if not 0.
" - ...:    	a:1 0 - use name given in next arg (a:2)
"  		    1 - prompt for a filename
"  		    2 - use automatically generate name 
"   		a:2 File to redirect output to. (Empty string is ignored)
" It first turns duplex printing off before getting VIM to generate PS output
" to a temporary file.
"
function! DoPrint(nup, duplex, ...)
	" Get current printoptions but turn duplex off.
	let popt_save = &popt
	set popt-=duplex:long
	set popt-=duplex:short
	set popt+=duplex:off
	let popt = &popt
	let &popt = popt_save

	" Generate a PS file first.
	let printfile = tempname()
	let rc = s:PrintToFile(printfile, popt)
	if rc
		let x = delete(printfile)
		return rc
	endif

	" Print the file using nup and duplex settings.
	if a:0 == 0 || a:1 !~ "[0-2]"
		let rc = PrintManager(printfile, a:nup, a:duplex)
	elseif a:1 == 0 && a:0 > 1
		let rc = PrintManager(printfile, a:nup, a:duplex, 0, a:2)
	else
		let mode = a:1
		" If file named but not given, use automagic name
		if mode == 0 && a:0 == 1
			let mode = 2
		endif
		let rc = PrintManager(printfile, a:nup, a:duplex, mode)
	endif

	return rc
endfunc

"~~~
" s:PrintToFile() - Send print PS to given file with the given printoptions.
" - filename: name of file to redirect PS to.
" - popt:     printoptions to use when generating file 
"
function! s:PrintToFile(filename, popt)
	let rc = 0

	" Save current printoptions around generating output
	let popt_save = &popt
	let &popt = a:popt

	" Catch any errors generating output
	let v:errmsg = ""
	silent! execute "hardcopy! > ".a:filename
	if v:errmsg != ""
		call s:WarningMsg("Error. hardcopy command failed.")
		let rc = 1
	endif

	" Restore original printoptions
	let &popt = popt_save
	return rc
endfunc

"~~~
" s:DoPrintNup() - convert the given PS file to print with n-up pages.
" - filename:	name of file to be converted.
" - paper:	size of paper pages printed on, and to do n-up on. 
" - nup:	number of pages to appear on each page.
" - outputfile:	name of file to put N-up version in. 
function! s:DoPrintNup(filename, paper, nup, outputfile)
	" Generate n-up output
	let x = system('psnup -q -p'.a:paper.' -'.a:nup.' '.a:filename.' '.a:outputfile)
	let rc = v:shell_error

	if rc
		call s:WarningMsg("Error. Failed to generate ".a:nup."-up pages.")
	endif

	return rc
endfunc

"~~~
" s:DoDuplexPrint() - function to do poor man's duplex printing.
" - printfile:		name of PostScript file to duplex print
" - reverseoddpages:	0 if odd pages are to be printed in ascending order,
"   			non-zero to be printed in descending order.
" - outfile:    	file to redirect output to (use empty string to print). 
" The odd pagres are first printed, then waits for confirmation from the user
" that the printed odd pages have been put back into the printer's input tray
" before printing the even pages on the back of the odd pages.
"
function! s:DoDuplexPrint(printfile, reverseoddpages, outfile)
	" First print the odd pages
	let rc = s:PrintEvenOdd(a:printfile, 'o', a:reverseoddpages, a:outfile)
	if rc
		return rc
	endif

	if a:outfile == ""
		" Get user to ok printing of even pages
		let rc = s:ConfirmProceed()
		if rc 
			call s:WarningMsg("Warning. Printing of even numbered sides aborted.")
			return 0
		endif
	else
		" Force newline between duplex printing messages
		echo 
	endif

	" And then print the even pages.
	let rc = s:PrintEvenOdd(a:printfile, 'e', 0, a:outfile)

	return rc
endfunc

"~~~
" s:ConfirmProceed() - Prompt user to indicate when safe to start printing of
" the next set of pages.  Returns 0 if ok to proceed, else non-zero.
"
function! s:ConfirmProceed()
	if has("dialog_gui") || has("dialog_con")
		let action = confirm("Select OK when ready to print the reverse sides -\nselect Cancel to abort.", "&OK\n&Cancel", 1)
		let rc = (action == 1) ? 0 : 1
	else
		let action = input("Press RETURN when ready to print the reverse sides -\ndelete OK to abort printing.\n", "OK")
		let rc = (action =~ "\s*OK\s*") ? 0 : 1
	endif
	return rc
endfunc

"~~~
" s:PrintEvenOdd() - print the even or odd pages from the given PS file,
" optionally reversing the page order.
" - filename:	name of file to print even/odd pages from
" - evenodd:	'e' to print even pages, 'o' to print odd pages
" - reverse:	1 to print pages in reverse order, anything else in ascending
"             	order
" - outfile:	name of file to send output to, or empty string	
"
function! s:PrintEvenOdd(filename, evenodd, reverse, outfile)
	" Tag filename with type of pages being printed
	let tmp = a:filename.'.'.a:evenodd.'.ps'
	let pages = (a:evenodd == 'e' ? "even" : "odd")

	let outfile = a:outfile
	if outfile != ""
		" Add even/odd indicator before extension if present, else at end
		if outfile =~ "\\.[^.]\\+$"
			let outfile = substitute(outfile, "\\(\\.[^.]\\+\\)$", ".".a:evenodd."\\1", "")
		else
			let outfile = outfile.".".a:evenodd
		endif
	endif

	" Extract the even/odd pages and print them
	let x = system('psselect -q'.(a:reverse ? ' -r' : '').' -'.a:evenodd.' '.a:filename.' '.tmp)
	let rc = v:shell_error
	if rc == 0
		let rc = s:PrintFile(tmp, "Duplex printing ... (".pages." pages)", outfile)
	else
		call s:WarningMsg("Error. Failed to print ".pages." pages.")
	endif

	" Delete the print file whatever happens
	let status = delete(tmp)

	return rc
endfunc

"~~~
" s:ReversePages() - print the even or odd pages from the given PS file,
" optionally reversing the page order.
" - filename:	name of file to reverse page order
" - reversefile: name of file to put reversed page order in
"
function! s:ReversePages(filename, reversefile)
	" Extract the even/odd pages and print them
	let x = system('psselect -q -r '.a:filename.' '.a:reversefile)
	return v:shell_error
endfunc

"~~~
" s:PrintFile() - print the given file depending on the host system.
" - filename: 	name of file to print.
" - message:	message to display when printing. 
" - outfile:	name of file for print data, or empty string 
"
function! s:PrintFile(filename, message, outfile)
	if a:outfile == ""
		" Use print command appropriate to the host system
		if has("vms")
			let tmp = system('print'.(&printdevice == '' ? '' : ' /queue='.&printdevice).' '.a:filename)
		elseif has("dos16") || has("dos32") || has("win16") || has("win32")
			let tmp = system('copy '.a:filename.' "'.&printdevice.'" ')
		else
			let tmp = system('lpr'.(&printdevice == '' ? '' : ' -P'.&printdevice).' '.a:filename)
		endif

		let rc = v:shell_error
	else
		" Check that printfile is not actual file or directory
		if has("modify_fname") && fnamemodify(a:outfile, ":p") == expand("%:p")
			call s:WarningMsg("Error: Print file '".a:outfile."' would overwrite buffer.")
			return 1
		elseif isdirectory(a:outfile)
			call s:WarningMsg("Error: Print file '".a:outfile."' is a directory.")
			return 1
		endif
		" Redirect print output to requested file
		let rc = rename(a:filename, a:outfile) 
	endif

	if rc == 0  
		" Echo printing message
		echon a:message
	endif
	return rc
endfunc

" eof prt_mgr.vim
