# Splits a shell command into simple commands, for protect-branch.sh. Each
# simple command is printed as its items, one per line, then a terminator:
#   w<word>   a word, after quote removal
#   r<word>   a redirection target (the checks ignore it)
#   i<word>   a here-string (<<<), which the command reads as stdin
#   h<line>   a heredoc body line, printed only when the pipeline runs a shell
#   |<n>      end of a command whose output is piped to the next one
#   ;<n>      end of any other command
# <n> is the nesting level: a $(...), `...` or <(...) is printed as its own
# commands one level deeper, and leaves a $ in the word it was part of, so the
# checks treat that word as unknown. A newline inside an item is printed as
# \001. Comments are dropped. POSIX awk, so it runs the same on macOS.
{ L[NR] = $0 }

END {
  ctx = 0; ctype[0] = "top"; segbuf[0] = ""; pdepth[0] = 0; pshell[0] = 0
  word = ""; inword = 0; redir = ""; mode = ""; hqn = 0
  for (ln = 1; ln <= NR; ln++) {
    s = L[ln] "\n"; m = length(s)
    for (i = 1; i <= m; i++) {
      c = substr(s, i, 1)
      # Text is read in windows of at most 256 characters, so long lines stay fast.
      if (mode == "sq") { # '...': up to the next quote, maybe on a later line
        t = substr(s, i, 256); j = index(t, "'")
        if (j == 0) { word = word t; i += length(t) - 1; continue }
        word = word substr(t, 1, j - 1); i += j - 1; mode = ""; continue
      }
      if (mode == "ansi") { # $'...'
        if (c == "\\") { i++; word = word substr(s, i, 1) }
        else if (c == "'") mode = ""
        else word = word c
        continue
      }
      if (mode == "dq") { # "...": \ escapes only $ ` " \ and newline
        if (c == "\"") { mode = ""; continue }
        if (c == "\\") {
          d = substr(s, i + 1, 1)
          if (d == "\n") { i++; continue }
          if (index("$`\"\\", d)) { word = word d; i++; continue }
          word = word c; continue
        }
        if (c == "$" && substr(s, i + 1, 1) == "(") { i++; push("sub"); continue }
        if (c == "`") { push("bq"); continue }
        if (match(substr(s, i, 256), /^[^"\\$`]+/)) { word = word substr(s, i, RLENGTH); i += RLENGTH - 1; continue }
        word = word c; continue
      }
      # Unquoted
      if (c == " " || c == "\t") { endword(); continue }
      if (c == "\n") { endword(); heredocs(); endseg(";"); continue }
      if (c == "\\") { d = substr(s, i + 1, 1); i++; if (d != "\n") { word = word d; inword = 1 } continue }
      if (c == "'") { mode = "sq"; inword = 1; continue }
      if (c == "\"") { mode = "dq"; inword = 1; continue }
      if (c == "$") {
        d = substr(s, i + 1, 1); inword = 1
        if (d == "(") { i++; push("sub"); continue }
        if (d == "'") { i++; mode = "ansi"; continue }
        if (d == "\"") { i++; mode = "dq"; continue }
        word = word c; continue
      }
      if (c == "`") { if (ctype[ctx] == "bq") pop(); else { inword = 1; push("bq") } continue }
      if (c == "#" && !inword) { i = m - 1; continue } # a comment runs to the end of the line
      if (c == ";") { endseg(";"); continue }
      if (c == "&") {
        d = substr(s, i + 1, 1)
        if (d == "&") { i++; endseg(";"); continue }
        if (d == ">") { endword(); i++; if (substr(s, i + 1, 1) == ">") i++; redir = "r"; continue }
        endseg(";"); continue
      }
      if (c == "|") {
        d = substr(s, i + 1, 1)
        if (d == "|") { i++; endseg(";"); continue }
        if (d == "&") i++
        endseg("|"); continue
      }
      if (c == "(") { endseg(";"); pdepth[ctx]++; continue }
      if (c == ")") {
        if (pdepth[ctx] == 0 && (ctype[ctx] == "sub" || ctype[ctx] == "ps")) pop()
        else { endseg(";"); if (pdepth[ctx] > 0) pdepth[ctx]-- }
        continue
      }
      if (c == "<" || c == ">") {
        if (inword && word ~ /^[0-9]+$/) { word = ""; inword = 0 } # a file descriptor, as in 2>&1
        endword()
        d = substr(s, i + 1, 1)
        if (d == "(") { i++; inword = 1; push("ps"); continue }
        redir = "r"
        if (c == "<" && d == "<") {
          i++; d = substr(s, i + 1, 1)
          if (d == "<") { i++; redir = "i" }
          else if (d == "-") { i++; redir = "hds" }
          else redir = "hd"
        } else if (d == ">" || d == "&" || d == "|" || (c == "<" && d == ">")) i++
        continue
      }
      if (match(substr(s, i, 256), /^[^ \t\n;&|()<>'"\\$`]+/)) { word = word substr(s, i, RLENGTH); i += RLENGTH - 1; inword = 1; continue }
      word = word c; inword = 1
    }
  }
  endseg(";")
  while (ctx > 0) pop()
  endseg(";")
}

function endword() {
  if (!inword) return
  if (redir == "hd" || redir == "hds") { hq[++hqn] = word; hs[hqn] = (redir == "hds") }
  else {
    emit((redir == "" ? "w" : redir) word)
    if (redir == "" && length(word) < 256 && word ~ /(^|\/)(bash|sh|zsh|dash|ksh)$/) pshell[ctx] = 1
  }
  word = ""; inword = 0; redir = ""
}

function emit(item) { gsub(/\n/, "\001", item); segbuf[ctx] = segbuf[ctx] item "\n" }

function endseg(t) {
  endword()
  if (segbuf[ctx] != "") { printf "%s%s%d\n", segbuf[ctx], t, ctx; segbuf[ctx] = "" }
  if (t == ";") pshell[ctx] = 0
}

# Entering $(...), `...` or <(...): save the word being built around it.
function push(t) {
  sw[ctx] = word; sr[ctx] = redir; sm[ctx] = mode
  ctx++; ctype[ctx] = t; pdepth[ctx] = 0; segbuf[ctx] = ""; pshell[ctx] = 0
  word = ""; inword = 0; redir = ""; mode = ""
}

function pop() {
  endseg(";"); ctx--
  word = sw[ctx] "$"; inword = 1; redir = sr[ctx]; mode = sm[ctx]
}

# At the end of a line with heredocs: read their bodies from the next lines.
function heredocs(   k, t) {
  for (k = 1; k <= hqn; k++) {
    while (ln < NR) {
      ln++; t = L[ln]
      if (hs[k]) sub(/^\t+/, "", t)
      if (t == hq[k]) break
      if (pshell[ctx]) emit("h" L[ln])
    }
  }
  hqn = 0
}
