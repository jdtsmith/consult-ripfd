# consult-ripfd — a `ripgrep` + `fd` mashup in Emacs

<img width="548" height="65" alt="image" src="https://github.com/user-attachments/assets/ffd15ade-ad06-4fed-af97-7aa623c612c5" />

Ever needed to find a line of text in a small `.txt` file whose name and location you can't remember, but you know you modified in the past week?  

Enter `consult-ripfd`:

```
# search pat -- -n 1w -S -1k -e txt
```

(newer than 1 week old, smaller than 1kb, `txt` extension)

## Intro

`ripgrep` is one of the most widely used tools for rapidly searching through files for patterns.  `fd` is a super-fast descendant of `find`, and can tear through large directory hierarchies finding files which match a wide range of criteria (filename, extension, modtime, file type, size, owner etc.).

`consult-ripfd` brings these two super tools together into a _single command_, with all of the conveniences of [consult](https://github.com/minad/consult) you know and love: 

- dynamic live results with match count
- instant async updating
- grouping matches by files with quick navigation between them
- match highlighting
- easy export to a `grep` buffer using [`embark`](https://github.com/oantolin/embark)

## Install and configuration

Not yet in a package repository.  Just clone and:

```elisp
(use-package consult-ripfd
  :load-path "~/path/to/consult-ripfd/"
  :bind  ("s-F" . consult-ripfd)) ; or whatever you prefer
```

Install both [`ripgrep`](https://github.com/BurntSushi/ripgrep) and [`fd`](https://github.com/sharkdp/fd) however is convenient.

> [!WARNING]
> For sort options to work reliably, make sure your version of `ripgrep` is up to date. `v15` or later is recommended.

## Usage

There are two commands, both of which combine `fd` and `rg` into one search tool.  Check the docstrings for the full details.  Note, if no option flags are given, both commands fall back on plain `ripgrep` search.

### `consult-ripfd` 

The main command presents an simplified interface with a single curated list of the most useful options from both tools:

```
 RG-PATTERNS -- OPTION-FLAGS

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

   -F, -i, -v   As in default `rg' option flags (no values)

   -s[r] [macp] Sort `rg' matches by [m]odified/[a]ccess/[c]reated time
                or [p]ath name.  Use `r' in the flag to reverse the
                sort.  N.B.: this makes `rg' single-threaded.
```

> [!WARNING]
> Short options in this command do not necessarily correspond to valid flags in the relevant tool.

Examples:

- `#\beat\b -- -n 2025-12-31` : lines that contain the standalone word `eat` in files with modification times newer than new year's eve.
- `# ^[\ \t]*$ --  -v -e py -d 3` : non-blank lines in `py` files at most 3 directories below the search dir.  Note the escaping of the space for consult.
- `#[a-d]\{3\}$ -- -b 4w -S +100k -g org*.org` : lines ending 3 of the letters `a-d` in large (>100kb) `org*.org` files which were last modified prior to 4 weeks ago.


### `consult-ripfd-full`

For when you need _complete_ access to the full range of `rg` and `fd` options.  The "full" version provides complete access to the command line options of both `fd` and `rg`.  It does so by recognizing **two** `--` argument separators: 

```
    FD-OPTS -- RG-OPTS -- RG-PATTERNS 
```

Note that you can specify file pattern matches using the `fd` keyword argument `--and`.

Example:

- `#--changed-within 1w --  -A 2 -- macro def` : search for the word `macro` and `def` (any order) in files changed within the last week, and also to show two lines of context after each match.

## Thanks

The fantastic and highly flexible [consult](https://github.com/minad/consult) package does most of the work here.  Big thanks to Daniel Mendler for sharing it and making it so efficient and adaptable.

