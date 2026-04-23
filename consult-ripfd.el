;;; consult-ripfd.el --- Consult mashup of ripgrep + fd -*- lexical-binding: t; -*-
;; Copyright (C) 2025-2026 J.D. Smith

;; Author: J.D. Smith <jdtsmith@gmail.com>
;; Homepage: https://github.com/jdtsmith/consult-ripfd
;; Package-Requires: ((emacs "29.1") (consult "3.3"))
;; Version: 0.2.1
;; Keywords: convenience

;; consult-ripfd is free software: you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.

;; consult-ripfd is distributed in the hope that it will be
;; useful, but WITHOUT ANY WARRANTY; without even the implied warranty
;; of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Uses `consult' to combine ripgrep and fd file search into a single
;; dynamic command.  There are two commands:
;; 
;;  consult-ripfd: search with a single simplified option flag set for
;;                 easy access to common options, including dates,
;;                 sizes, sorting, etc.
;; 
;;  consult-ripfd-full: full flexibility to specify the complete set
;;                 of both `fd' and `rg' option flags, using two `--'
;;                 separators.

;;; Code:
(require 'consult)
(eval-when-compile (require 'cl-lib))

(defcustom consult-ripfd-fd-args
  '((if (executable-find "fdfind" 'remote) "fdfind" "fd")
    "--color=never")
  "Command line arguments for `fd' in `ripfd'.  See `consult-fd-args'."
  :type '(choice string (repeat (choice string sexp)))
  :group 'consult)

(defun consult-ripfd--full-make-builder (paths)
  "Make builder for `ripgrep' + `fd' with PATHS."
  (let* ((opt-pat (rx (+ space) (group "--") (or (+ space) eos)))
         (fd-builder (consult--fd-make-builder paths))
         (rg-builder (consult--ripgrep-make-builder nil))
         (rg-builder-with-paths (consult--ripgrep-make-builder paths)))
    (lambda (input)
      (let* ((start (string-match opt-pat input))
	     (end (and start (match-end 0)))
             (start2 (and start (string-match opt-pat input end))))
        (if (null start)
            (funcall rg-builder-with-paths input) ; rg-only search
          (let ((fd-cmd (funcall fd-builder (concat (substring input 0 start) " .")))
                (rg-cmd (funcall rg-builder (substring input end))))
            (cons (append (car fd-cmd)
                          (unless (or (member "-t" (car fd-cmd))
                                      (member "--type" (car fd-cmd)))
                            '("--type" "f"))
                          (and (car rg-cmd) `("-X" ,@(car rg-cmd))))
                  (cdr rg-cmd))))))))

(defun consult-ripfd-full (&optional dir initial)
  "Search with `rg' in files found by `fd' in DIR with INITIAL input.
Uses `rg' to finds matching lines within `fd'-selected files with full
REGEXP-style file matching.  Note that this full command uses the
default `consult-fd-args'.

Input is composed using the full complement of `fd' and `rg' flags, with
up to two `--' option separators:

    RG-PATTERNS              (simple `rg'-only search for RG-PATTERNS)

    FD-OPTS -- RG-PATTERNS  (`rg' search for RG-PATTERNS over files matching
                              FD-OPTS for `fd'; see `rg(1)')

    FD-OPTS -- RG-OPTS -- RG-PATTERNS (`rg' search for RG-PATTERNS using
                                        RG-OPTS over files matching
                                        FD-OPTS for `fd'; see `fd(1)')

Hint: to specify one or more `fd' file regexp patterns to match, use
FD-OPTS that include `--and PATTERN'."
  (interactive "P")
  (consult--grep "RipFd+" #'consult-ripfd--full-make-builder dir initial))

(defun consult-ripfd--parse-simple-opts (opts)
  "Parse the list of simple options OPTS and return new options.
The returned option strings are (RG-OPTS FD-OPTS)."
  (let (opt val fd-opts rg-opts)
    (while opts
      (setq opt (car opts) opts (cdr opts))
      (if (member opt '("-F" "-i" "-v")) ; rg: fixed strings, ignore case, invert match
	  (push opt rg-opts) ; no value
	(setq val (car opts) opts (cdr opts)) ; all others take values
	(when (and (string-prefix-p "-" opt) val)
	  (pcase opt
	    ((or "-S" "-t" "-e" "-d" "-o" "-E") ; fd: size, type, extension, max-depth, owner: as-is
	     (dolist (x `(,opt ,val)) (push x fd-opts)))
	    ((or "-n" "-b")	      ; fd: changed within/before date
	     (dolist (x (list (if (equal opt "-b") "--older" "--newer") val))
	       (push x fd-opts)))
	    ((or "-s" "-sr")		; rg sort
	     (dolist (x (list (if (equal opt "-sr") "--sortr" "--sort")
			      (cl-case (aref val 0)
				(?m "modified") (?a "accessed")
				(?c "created") (?p "path"))))
	       (push x rg-opts)))
	    ("-g"		; fd file match glob (can be multiple)
	     (unless (member opt fd-opts) (push opt fd-opts))
	     (dolist (x (list "--and" val)) (push x fd-opts)))
	    (_ (user-error
		(format  "[RipFD] Unrecognized opt %s (options: -bdeFginos[r]Stv)"
			 opt)))))))
    (list (nreverse rg-opts) (nreverse fd-opts))))

(defun consult-ripfd--make-builder (paths)
  "Simplified make builder for ripgrep + fd (simple) with PATHS."
  (let* ((fd-cmd (consult--build-args consult-ripfd-fd-args))
         (rg-builder (consult--ripgrep-make-builder nil))
         (rg-builder-with-paths (consult--ripgrep-make-builder paths))
	 (path-flags (mapcan (lambda (x) `("--search-path" ,x)) paths)))
    (lambda (input)
      (pcase-let* ((`(,args . ,opts) (consult--command-split input))
		   (`(,rg-opts ,fd-opts) (consult-ripfd--parse-simple-opts opts)))
	(if (null fd-opts)
	    (funcall rg-builder-with-paths input) ; no fd: rg-only search
	  (when-let* ((fd-cmd (append fd-cmd fd-opts
				      (unless (member "-t" fd-opts) '("-t" "f"))
				      path-flags))
		      (rg-cmd (funcall rg-builder
				       (concat (combine-and-quote-strings rg-opts) " -- "
					       args))))
	    (cons (append fd-cmd (and (car rg-cmd) `("-X" ,@(car rg-cmd))))
		  (cdr rg-cmd))))))))

(defun consult-ripfd (&optional dir initial)
  "Simple find + search using `fd' and `rg'.

Uses `rg' to finds matching lines within `fd'-selected files, with a
simplified interface and glob-style file matching to select desired
files.  INITIAL input and DIR are as in `consult-grep'.  Multiple search
directories can be specified by calling with a prefix argument.  Uses
`consult-ripfd-fd-args' as the basic args for `fd'.

Input is composed like:

    RG-PATTERNS          (simple `rg'-only search)
    RG-PATTERNS -- OPTS  (`rg' + `fd' search using simplified option flags)

The search terms RG-PATTERNS are as in `consult-ripgrep'.  Available
simplified option flags (OPTS) are as follows.  Note that these do not
all correspond to valid `rg' or `fd' command line options.  Unless
otherwise noted, all options take values.  Ganging options together is
not permitted.

 `fd'-relevant option flags:

   -n DATE      Newer than date - see fd(1) for date/duration syntax

   -b DATE      Before (older than) date

   -S SIZE      As in default `fd' option flags (see `fd(1)')
   -t TYPE
   -e EXT
   -d MAX-DEPTH
   -o OWNER
   -E EXCLUDE-GLOB

   -g GLOB      Search filenames matching GLOB.  May be provided multiple
                times to match additional files.  See also -E.

 `rg'-relevant option flags:

   -F, -i, -v   As in default `rg' option flags (no values; see `rg(1)')

   -s[r] [macp] Sort `rg' matches by [m]odified/[a]ccess/[c]reated time
                or [p]ath name.  Use `r' in the flag to reverse the
                sort.  N.B.: this makes `rg' single-threaded.

Passing any other option flag will generate an error."
  (interactive "P")
  (consult--grep "RipFd" #'consult-ripfd--make-builder dir initial))

(provide 'consult-ripfd)
;;; consult-ripfd.el ends here
