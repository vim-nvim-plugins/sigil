/* sigil — variable finder behind sigil.vim. One path for every language: parse with
 * tree-sitter, run that language's locals query, resolve each reference to the nearest
 * definition of the same name, print one variable per line.
 *
 *   usage:  sigil [--scopes|--positions] <filetype|extension> <file>
 *           sigil --list                       supported languages and their aliases
 *   stdout: context|name|line,line,...         context = global | local | param | field
 *           --scopes: one line per variable per scope, with the scope's lines appended:
 *           context|name|line,line,...|first-last  (same-named variables never merged)
 *           --positions: as --scopes, with every occurrence as line:col (col = byte, 1-based):
 *           context|name|line:col,line:col,...|first-last
 *   exit:   0 ok · 1 error (message on stderr) · 2 no parser for this filetype
 */
#define _POSIX_C_SOURCE 200809L	/* strdup, strndup under -std=c11 */
#include <regex.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <tree_sitter/api.h>

typedef struct {
	const char *name;
	const TSLanguage *(*language)(void);
	const char *query;
	const char *aliases;	/* space separated: Vim filetypes and file extensions */
} Grammar;
extern const Grammar sigil_grammars[];
extern const int sigil_ngrammars;

enum { K_BARE, K_VAR, K_CONST, K_FIELD, K_PARAM, K_OTHER };	/* in rank order: a node captured twice keeps the higher */

typedef struct { uint32_t start, end; int global; uint32_t first, last; } Scope;
typedef struct { const char *name; uint32_t len, byte, row, col; int kind, up, scope, member; } Def;
typedef struct { const char *name; uint32_t len, byte, row, col; } Ref;
typedef struct { uint32_t row, col; } Pos;
typedef struct { int scope, kind, member; const char *name; uint32_t len; uint32_t *rows; int nrows, caprows; Pos *pos; int npos, cappos; } Var;

#define PUSH(arr, n, cap, v) do { \
	if ((n) == (cap)) { (cap) = (cap) ? (cap) * 2 : 64; (arr) = realloc((arr), (size_t)(cap) * sizeof *(arr)); \
		if (!(arr)) die("out of memory"); } \
	(arr)[(n)++] = (v); } while (0)

static const char *src;
static uint32_t srclen;
static Scope *scopes; static int nscopes, capscopes;
static Def *defs; static int ndefs, capdefs;
static Ref *refs; static int nrefs, caprefs;
static Ref *mrefs; static int nmrefs, capmrefs;	/* member uses: the `name` in `obj.name` */
static uint32_t *members; static int nmembers, capmembers;	/* bytes of @local.member nodes, sorted */
static Var *vars; static int nvars, capvars;

static void die(const char *msg) { fprintf(stderr, "sigil: %s\n", msg); exit(1); }

static const Grammar *find_grammar(const char *ft) {
	size_t n = strlen(ft);
	for (int i = 0; i < sigil_ngrammars; i++) {
		const char *a = sigil_grammars[i].aliases;
		if (!strcmp(sigil_grammars[i].name, ft)) return &sigil_grammars[i];
		while (*a) {
			size_t w = strcspn(a, " ");
			if (w == n && !strncmp(a, ft, n)) return &sigil_grammars[i];
			a += w; while (*a == ' ') a++;
		}
	}
	return NULL;
}

static char *read_file(const char *path, uint32_t *len) {
	FILE *f = fopen(path, "rb");
	if (!f) return NULL;
	size_t cap = 1 << 16, n = 0, r;
	char *buf = malloc(cap);
	while (buf && (r = fread(buf + n, 1, cap - n, f)) > 0) {
		n += r;
		if (n == cap) buf = realloc(buf, cap *= 2);
	}
	fclose(f);
	if (!buf) die("out of memory");
	*len = (uint32_t)n;
	return buf;
}

/* ── predicates ───────────────────────────────────────────────────────────── */

static TSNode capture_node(const TSQueryMatch *m, uint32_t id, int *ok) {
	for (uint16_t i = 0; i < m->capture_count; i++)
		if (m->captures[i].index == id) { *ok = 1; return m->captures[i].node; }
	*ok = 0;
	return m->captures[0].node;
}

static int node_eq(TSNode n, const char *s, uint32_t len) {
	uint32_t a = ts_node_start_byte(n), b = ts_node_end_byte(n);
	return b - a == len && !memcmp(src + a, s, len);
}

static int regex_match(TSNode n, const char *pat) {
	/* Queries were written for Vim/Lua regex; POSIX ERE covers what the locals queries use. */
	static char *last_pat; static regex_t last_re; static int last_ok;
	if (!last_pat || strcmp(last_pat, pat)) {
		if (last_pat) { if (last_ok) regfree(&last_re); free(last_pat); }
		last_pat = strdup(pat);
		last_ok = regcomp(&last_re, pat, REG_EXTENDED | REG_NOSUB) == 0;
	}
	if (!last_ok) return 1;
	uint32_t a = ts_node_start_byte(n), b = ts_node_end_byte(n);
	char *text = strndup(src + a, b - a);
	int r = regexec(&last_re, text, 0, NULL, 0) == 0;
	free(text);
	return r;
}

/* Evaluates the text predicates of one match. *up is set by `#set! definition.*.scope "parent"`. */
static int predicates_hold(const TSQuery *q, const TSQueryMatch *m, int *up) {
	uint32_t nsteps;
	const TSQueryPredicateStep *st = ts_query_predicates_for_pattern(q, m->pattern_index, &nsteps);
	*up = 0;
	for (uint32_t i = 0; i < nsteps;) {
		uint32_t j = i;
		while (j < nsteps && st[j].type != TSQueryPredicateStepTypeDone) j++;
		uint32_t nargs = j - i;
		if (nargs == 0 || st[i].type != TSQueryPredicateStepTypeString) { i = j + 1; continue; }
		uint32_t l;
		const char *op = ts_query_string_value_for_id(q, st[i].value_id, &l);
		int neg = !strncmp(op, "not-", 4), ok = 1, hit = 1;
		const char *base = neg ? op + 4 : op;
		TSNode n = m->captures[0].node;
		if (nargs >= 2 && st[i + 1].type == TSQueryPredicateStepTypeCapture)
			n = capture_node(m, st[i + 1].value_id, &ok);
		if (!strcmp(op, "set!")) {
			for (uint32_t k = i + 1; k + 1 < j; k++)
				if (st[k].type == TSQueryPredicateStepTypeString && st[k + 1].type == TSQueryPredicateStepTypeString) {
					const char *key = ts_query_string_value_for_id(q, st[k].value_id, &l);
					const char *val = ts_query_string_value_for_id(q, st[k + 1].value_id, &l);
					if (strlen(key) > 6 && !strcmp(key + strlen(key) - 6, ".scope") && !strcmp(val, "parent")) *up = 1;
				}
		} else if (!ok) {
			/* capture absent in this match (optional node): predicate does not apply */
		} else if (!strcmp(base, "eq?") && nargs == 3) {
			if (st[i + 2].type == TSQueryPredicateStepTypeCapture) {
				int ok2; TSNode o = capture_node(m, st[i + 2].value_id, &ok2);
				uint32_t a = ts_node_start_byte(o);
				hit = ok2 && node_eq(n, src + a, ts_node_end_byte(o) - a);
			} else {
				const char *s = ts_query_string_value_for_id(q, st[i + 2].value_id, &l);
				hit = node_eq(n, s, l);
			}
			if (neg ? hit : !hit) return 0;
		} else if (!strcmp(base, "any-of?")) {
			hit = 0;
			for (uint32_t k = i + 2; k < j && !hit; k++) {
				const char *s = ts_query_string_value_for_id(q, st[k].value_id, &l);
				hit = node_eq(n, s, l);
			}
			if (neg ? hit : !hit) return 0;
		} else if (strstr(base, "match?") && nargs == 3) {
			hit = regex_match(n, ts_query_string_value_for_id(q, st[i + 2].value_id, &l));
			if (neg ? hit : !hit) return 0;
		} else if (!strcmp(base, "has-ancestor?")) {
			hit = 0;
			for (TSNode p = ts_node_parent(n); !ts_node_is_null(p) && !hit; p = ts_node_parent(p))
				for (uint32_t k = i + 2; k < j && !hit; k++)
					hit = !strcmp(ts_node_type(p), ts_query_string_value_for_id(q, st[k].value_id, &l));
			if (neg ? hit : !hit) return 0;
		}
		/* anything else (is-not?, offset!, …) does not narrow what sigil shows */
		i = j + 1;
	}
	return 1;
}

/* ── scopes ───────────────────────────────────────────────────────────────── */

/* Last line a node covers; a node ending right after a newline ends on the line before. */
static uint32_t last_row(TSNode n) {
	TSPoint e = ts_node_end_point(n);
	return e.column == 0 && e.row > 0 ? e.row : e.row + 1;
}

static int cmp_scope(const void *a, const void *b) {
	const Scope *x = a, *y = b;
	if (x->start != y->start) return x->start < y->start ? -1 : 1;
	return x->end == y->end ? 0 : x->end > y->end ? -1 : 1;
}

/* Scopes sorted by start, outer first: the last one containing `byte` is the innermost. */
static int innermost(uint32_t byte) {
	int best = 0;
	for (int i = 1; i < nscopes && scopes[i].start <= byte; i++)
		if (byte < scopes[i].end) best = i;
	return best;
}

static int contains(int s, int t) {
	return scopes[s].start <= scopes[t].start && scopes[t].end <= scopes[s].end;
}

static int parent_of(int s) {
	for (int i = s - 1; i >= 0; i--)
		if (scopes[i].start <= scopes[s].start && scopes[s].end <= scopes[i].end) return i;
	return 0;
}

/* ── variables, keyed by (scope, name) ────────────────────────────────────── */

static int *table; static int tabcap;

static uint32_t hash(int scope, int member, const char *s, uint32_t len) {
	uint32_t h = 2166136261u ^ (uint32_t)scope ^ (uint32_t)member << 31;
	for (uint32_t i = 0; i < len; i++) h = (h ^ (unsigned char)s[i]) * 16777619u;
	return h;
}

/* member: `obj.name` defined as a field. Kept apart from a plain `name` in the same scope. */
static int lookup(int scope, int member, const char *name, uint32_t len) {
	for (uint32_t h = hash(scope, member, name, len) & (tabcap - 1);; h = (h + 1) & (tabcap - 1)) {
		int v = table[h];
		if (v < 0) return -1;
		if (vars[v].scope == scope && vars[v].member == member && vars[v].len == len && !memcmp(vars[v].name, name, len)) return v;
	}
}

static void insert(int v) {
	uint32_t h = hash(vars[v].scope, vars[v].member, vars[v].name, vars[v].len) & (tabcap - 1);
	while (table[h] >= 0) h = (h + 1) & (tabcap - 1);
	table[h] = v;
}

static void add_row(Var *v, uint32_t row, uint32_t col) {
	PUSH(v->pos, v->npos, v->cappos, ((Pos){row, col}));
	if (v->nrows && v->rows[v->nrows - 1] == row) return;
	PUSH(v->rows, v->nrows, v->caprows, row);
}

static int cmp_u32(const void *a, const void *b) {
	uint32_t x = *(const uint32_t *)a, y = *(const uint32_t *)b;
	return x < y ? -1 : x > y;
}

static int cmp_pos(const void *a, const void *b) {
	const Pos *x = a, *y = b;
	if (x->row != y->row) return x->row < y->row ? -1 : 1;
	return x->col < y->col ? -1 : x->col > y->col;
}

static int cmp_def_byte(const void *a, const void *b) {
	const Def *x = a, *y = b;
	return x->byte < y->byte ? -1 : x->byte > y->byte;
}

static int is_member_byte(uint32_t byte) {
	return nmembers && bsearch(&byte, members, nmembers, sizeof *members, cmp_u32) != NULL;
}

static int is_def_byte(uint32_t byte) {
	int lo = 0, hi = ndefs - 1;
	while (lo <= hi) {
		int mid = (lo + hi) / 2;
		if (defs[mid].byte == byte) return 1;
		if (defs[mid].byte < byte) lo = mid + 1; else hi = mid - 1;
	}
	return 0;
}

/* `obj.name`: the name after the dot is a member, not a use of a variable called `name`.
   Grammars put it in a field named one of these (python attribute, ecma property, go field);
   for grammars that don't, queries/<lang>.scm marks it @local.member. */
static int is_member(TSNode n) {
	static const char *fields[] = {"attribute", "property", "field"};
	TSNode p = ts_node_parent(n);
	if (ts_node_is_null(p)) return 0;
	for (int i = 0; i < 3; i++) {
		TSNode c = ts_node_child_by_field_name(p, fields[i], (uint32_t)strlen(fields[i]));
		if (!ts_node_is_null(c) && ts_node_eq(c, n)) return 1;
	}
	return 0;
}

/* `obj.name` → the field `name` defined inside the nearest enclosing scope that has one (a method's
   `self.x` → the `x` its class's methods assign). Never at file level: there `obj` could be anything. */
static int resolve_field(uint32_t byte, const char *name, uint32_t len) {
	for (int s = innermost(byte); !scopes[s].global; s = parent_of(s))
		for (int v = 0; v < nvars; v++)
			if (vars[v].kind == K_FIELD && vars[v].len == len && !memcmp(vars[v].name, name, len) && contains(s, vars[v].scope))
				return v;
	return -1;
}

static int def_kind(const char *cap) {
	const char *k = cap + strlen("local.definition");
	if (!strcmp(k, ".var")) return K_VAR;
	if (!strcmp(k, ".parameter")) return K_PARAM;
	if (!strcmp(k, ".constant")) return K_CONST;
	if (!strcmp(k, ".field")) return K_FIELD;
	if (!*k) return K_BARE;	/* no kind given: never printed unless another pattern gives one */
	return K_OTHER;	/* functions, types, imports, …: kept so they shadow, never printed */
}

static const char *context(const Var *v) {
	switch (v->kind) {
	case K_PARAM: return "param";
	case K_FIELD: return "field";
	default: return scopes[v->scope].global ? "global" : "local";
	}
}

int main(int argc, char **argv) {
	if (argc == 2 && !strcmp(argv[1], "--list")) {
		for (int i = 0; i < sigil_ngrammars; i++) printf("%s: %s\n", sigil_grammars[i].name, sigil_grammars[i].aliases);
		return 0;
	}
	int positions = argc == 4 && !strcmp(argv[1], "--positions");
	int by_scope = positions || (argc == 4 && !strcmp(argv[1], "--scopes"));
	if (by_scope) argv++, argc--;
	if (argc != 3) { fprintf(stderr, "usage: sigil [--scopes|--positions] <filetype|extension> <file>   |   sigil --list\n"); return 1; }
	const Grammar *g = find_grammar(argv[1]);
	if (!g) { fprintf(stderr, "sigil: no parser for '%s'\n", argv[1]); return 2; }
	char *buf = read_file(argv[2], &srclen);
	if (!buf) { fprintf(stderr, "sigil: cannot read %s\n", argv[2]); return 1; }
	src = buf;

	TSParser *parser = ts_parser_new();
	if (!ts_parser_set_language(parser, g->language())) die("grammar ABI not supported by this tree-sitter");
	TSTree *tree = ts_parser_parse_string(parser, NULL, src, srclen);
	TSNode root = ts_tree_root_node(tree);

	uint32_t err_off; TSQueryError err;
	TSQuery *q = ts_query_new(g->language(), g->query, (uint32_t)strlen(g->query), &err_off, &err);
	if (!q) { fprintf(stderr, "sigil: %s locals query is invalid at byte %u (error %d)\n", g->name, err_off, err); return 1; }

	/* scope 0 is the whole file; so is the tree's root node when the query marks it */
	PUSH(scopes, nscopes, capscopes, ((Scope){0, UINT32_MAX, 1, 1, last_row(root)}));

	TSQueryCursor *cur = ts_query_cursor_new();
	ts_query_cursor_exec(cur, q, root);
	TSQueryMatch m;
	while (ts_query_cursor_next_match(cur, &m)) {
		int up;
		if (!predicates_hold(q, &m, &up)) continue;
		for (uint16_t i = 0; i < m.capture_count; i++) {
			uint32_t l;
			const char *cap = ts_query_capture_name_for_id(q, m.captures[i].index, &l);
			TSNode n = m.captures[i].node;
			uint32_t a = ts_node_start_byte(n), b = ts_node_end_byte(n);
			uint32_t row = ts_node_start_point(n).row + 1, col = ts_node_start_point(n).column + 1;
			if (!strcmp(cap, "local.scope")) {
				/* the whole file is scope 0 already; a second one would split its variables */
				if (a == ts_node_start_byte(root) && b == ts_node_end_byte(root)) continue;
				PUSH(scopes, nscopes, capscopes, ((Scope){a, b, 0, row, last_row(n)}));
			} else if (!strcmp(cap, "local.member")) {
				PUSH(members, nmembers, capmembers, a);
			} else if (!strcmp(cap, "local.reference")) {
				if (is_member(n)) PUSH(mrefs, nmrefs, capmrefs, ((Ref){src + a, b - a, a, row, col}));
				else PUSH(refs, nrefs, caprefs, ((Ref){src + a, b - a, a, row, col}));
			} else if (!strncmp(cap, "local.definition", 16) && (cap[16] == '\0' || cap[16] == '.')) {
				PUSH(defs, ndefs, capdefs, ((Def){src + a, b - a, a, row, col, def_kind(cap), up, 0, is_member(n)}));
			}
		}
	}

	qsort(scopes + 1, nscopes - 1, sizeof *scopes, cmp_scope);
	qsort(defs, ndefs, sizeof *defs, cmp_def_byte);
	qsort(members, nmembers, sizeof *members, cmp_u32);
	/* One node captured by several patterns is one definition: the highest-ranked kind wins,
	   and "parent" holds if any pattern said so. */
	int nd = 0;
	for (int i = 0; i < ndefs; i++) {
		Def *d = &defs[i], *p = nd ? &defs[nd - 1] : NULL;
		if (p && d->byte == p->byte && d->len == p->len) {
			if (d->kind > p->kind) p->kind = d->kind;
			p->up |= d->up;
		} else defs[nd++] = *d;
	}
	ndefs = nd;
	for (int i = 0; i < ndefs; i++) defs[i].member |= is_member_byte(defs[i].byte);
	for (int i = 0; i < nrefs;)
		if (is_member_byte(refs[i].byte)) { PUSH(mrefs, nmrefs, capmrefs, refs[i]); refs[i] = refs[--nrefs]; }
		else i++;
	for (tabcap = 64; tabcap < 2 * (ndefs + 1); tabcap *= 2) {}
	table = malloc(sizeof *table * tabcap);
	memset(table, -1, sizeof *table * tabcap);

	for (int i = 0; i < ndefs; i++) {
		Def *d = &defs[i];
		int s = innermost(d->byte);
		/* a definition whose own node is the scope (a function's name) belongs to the scope outside */
		if (d->up && s) s = parent_of(s);
		int v = d->member && d->kind == K_FIELD ? resolve_field(d->byte, d->name, d->len) : -1;
		if (v < 0) v = lookup(s, d->member, d->name, d->len);
		if (v < 0) {
			PUSH(vars, nvars, capvars, ((Var){s, d->kind, d->member, d->name, d->len, NULL, 0, 0, NULL, 0, 0}));
			v = nvars - 1;
			insert(v);
		}
		if (vars[v].kind == K_BARE) vars[v].kind = d->kind;	/* a later pattern may name what it is */
		add_row(&vars[v], d->row, d->col);
	}
	for (int i = 0; i < nrefs; i++) {
		Ref *r = &refs[i];
		if (is_def_byte(r->byte)) continue;
		for (int s = innermost(r->byte);; s = parent_of(s)) {
			int v = lookup(s, 0, r->name, r->len);
			if (v >= 0) { add_row(&vars[v], r->row, r->col); break; }
			if (s == 0) break;	/* never defined in this file: a builtin or an import */
		}
	}

	for (int i = 0; i < nmrefs; i++) {
		Ref *r = &mrefs[i];
		if (is_def_byte(r->byte)) continue;
		int v = resolve_field(r->byte, r->name, r->len);
		if (v >= 0) add_row(&vars[v], r->row, r->col);
	}

	/* One line per (context, name): the panel shows a name once even if several scopes define it.
	   --scopes keeps them apart, for callers that edit (a rename must not cross scopes). */
	for (int i = 0; i < nvars; i++) {
		Var *v = &vars[i];
		if (v->kind == K_OTHER || v->kind == K_BARE || !v->nrows) continue;
		const char *ctx = context(v);
		for (int j = i + 1; j < nvars && !by_scope; j++) {
			Var *w = &vars[j];
			if (w->kind == K_OTHER || w->kind == K_BARE || !w->nrows || w->len != v->len || memcmp(w->name, v->name, v->len) || strcmp(context(w), ctx)) continue;
			for (int k = 0; k < w->nrows; k++) PUSH(v->rows, v->nrows, v->caprows, w->rows[k]);
			w->nrows = 0;
		}
		qsort(v->rows, v->nrows, sizeof *v->rows, cmp_u32);
		printf("%s|%.*s|", ctx, (int)v->len, v->name);
		if (positions) {
			qsort(v->pos, v->npos, sizeof *v->pos, cmp_pos);
			for (int k = 0; k < v->npos; k++)
				if (!k || cmp_pos(&v->pos[k], &v->pos[k - 1])) printf(k ? ",%u:%u" : "%u:%u", v->pos[k].row, v->pos[k].col);
		} else {
			for (int k = 0; k < v->nrows; k++)
				if (!k || v->rows[k] != v->rows[k - 1]) printf(k ? ",%u" : "%u", v->rows[k]);
		}
		if (by_scope) printf("|%u-%u", scopes[v->scope].first, scopes[v->scope].last);
		putchar('\n');
	}
	return 0;
}
