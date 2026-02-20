#!/usr/bin/env python3
"""
sigil.py - Variable parser for vim-sigil

Priority:
    Python files --> full AST parser (rich context)
    Else --> Universal Ctags (40+ languages)

Output format (Variable per line):
    context|name|line1,line2,...
"""

import ast
import sys
import os
import subprocess
import shutil

# Python parser

def parse_python(source, filter_text=''):
	tree = ast.parse(source)
	vars = {}

	parent_map = {}
	for node in ast.walk(tree):
		for child in ast.iter_child_nodes(node):
			parent_map[id(child)] = node

	def get_parents(node):
		parents = []
		current = parent_map.get(id(node))
		while current:
			parents.append(current)
			current = parent_map.get(id(current))
		return parents

	def get_context(node, parents):
		for p in reversed(parents):
			if isinstance(p, (ast.FunctionDef, ast.AsyncFunctionDef)):
				return 'local'
			if isinstance(p, ast.ClassDef):
				return 'class'
		return 'global'

	def add_var(name, lineno, context):
		if filter_text and filter_text.lower() not in name.lower():
			return
		if name.startswith('_') and name.endswith('_'):
			return
		key = (name, context)
		if key not in vars:
			vars[key] = []
		if lineno not in vars[key]:
			vars[key].append(lineno)

	for node in ast.walk(tree):
		parents = get_parents(node)
		context = get_context(node, parents)

		if isinstance(node, ast.Assign):
			for t in node.targets:
				if isinstance(t, ast.Name):
					add_var(t.id, node.lineno, context)
				elif isinstance(t, (ast.Tuple, ast.List)):
					for elt in t.elts:
						if isinstance(elt, ast.Name):
							add_var(elt.id, node.lineno, context)

		elif isinstance(node, ast.AnnAssign):
			if isinstance(node.target, ast.Name):
				add_var(node.target.id, node.lineno, context)

		elif isinstance(node, ast.AugAssign):
			if isinstance(node.target, ast.Name):
				add_var(node.target.id, node.lineno, context)

		elif isinstance(node, ast.For):
			if isinstance(node.target, ast.Name):
				add_var(node.target.id, node.lineno, 'loop')
			elif isinstance(node.target, (ast.Tuple, ast.List)):
				for elt in node.target.elts:
					if isinstance(elt, ast.Name):
						add_var(elt.id, node.lineno, 'loop')

		elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
			for arg in node.args.args + node.args.posonlyargs + node.args.kwonlyargs:
				add_var(arg.arg, arg.lineno, 'param')
			if node.args.vararg:
				add_var(node.args.vararg.arg, node.args.vararg.lineno, 'param')
			if node.args.kwarg:
				add_var(node.args.kwarg.arg, node.args.kwarg.lineno, 'param')

		elif isinstance(node, ast.With):
			for item in node.items:
				if item.optional_vars and isinstance(item.optional_vars, ast.Name):
					add_var(item.optional_vars.id, node.lineno, context)

		elif isinstance(node, ast.NamedExpr):
			add_var(node.target.id, node.lineno, context)

		elif isinstance(node, (ast.ListComp, ast.SetComp, ast.GeneratorExp)):
			for gen in node.generators:
				if isinstance(gen.target, ast.Name):
					add_var(gen.target.id, gen.target.lineno, 'comp')

		elif isinstance(node, ast.ExceptHandler):
			if node.name:
				add_var(node.name, node.lineno, 'except')

	return vars

# ctags language config
""" 
Skip functions/classes/methods (variables only by default this can be altered)
"""

CTAGS_LANGUAGES = {
	# Web
	'.js':   ('JavaScript', 'Cv'),
	'.jsx':  ('JavaScript', 'Cv'),
	'.ts':   ('TypeScript', 'Clvz'),
	'.tsx':  ('TypeScript', 'Clvz'),
	'.php':  ('PHP',        'dlv'),

	# Systems
	'.c':    ('C',          'lmvxz'),
	'.h':    ('C',          'lmvxz'),
	'.cpp':  ('C++',        'lmvxz'),
	'.cc':   ('C++',        'lmvxz'),
	'.cxx':  ('C++',        'lmvxz'),
	'.hpp':  ('C++',        'lmvxz'),
	'.cs':   ('C#',         'flp'),
	'.rs':   ('Rust',       'mv'),
	'.go':   ('Go',         'cmv'),

	# JVM
	'.java': ('Java',       'fl'),
	'.kt':   ('Kotlin',     'Cv'),
	'.kts':  ('Kotlin',     'Cv'),

	# Scripting
	'.rb':   ('Ruby',       'C'),
	'.lua':  ('Lua',        ''),
	'.pl':   ('Perl',       'v'),
	'.pm':   ('Perl',       'v'),
	'.r':    ('R',          'gvz'),
	'.R':    ('R',          'gvz'),
	'.jl':   ('Julia',      'cg'),

	# Shell
	'.sh':   ('Sh',         'a'),
	'.bash': ('Sh',         'a'),
	'.zsh':  ('Sh',         'a'),

	# Data / config
	'.sql':  ('SQL',        'lv'),
	'.vim':  ('Vim',        'v'),

	# Other
	'.f':    ('Fortran',    'v'),
	'.f90':  ('Fortran',    'v'),
	'.ml':   ('OCaml',      'v'),
	'.pas':  ('Pascal',     'v'),
}

KIND_TO_CONTEXT = {
	'variable':    'global',
	'var':         'global',
	'globalvar':   'global',
	'externvar':   'global',
	'constant':    'global',
	'const':       'global',
	'define':      'global',
	'field':       'class',
	'member':      'class',
	'property':    'class',
	'local':       'local',
	'functionvar': 'local',
	'parameter':   'param',
	'param':       'param',
	'alias':       'global',
	'enumerator':  'global',
}

SKIP_KINDS = {
	'function', 'func', 'method', 'class', 'interface', 'module',
	'namespace', 'package', 'struct', 'enum', 'typedef', 'macro',
	'prototype', 'procedure', 'trigger', 'view', 'table', 'cursor',
	'event', 'heredoc', 'script', 'implementation', 'typealias',
	'object', 'nameattr', 'library', 'source', 'index', 'synonym',
}

# ctags parser 

def parse_ctags(filepath, lang, kinds_flag, filter_text):
	if not shutil.which('ctags'):
		return None

	cmd = ['ctags', '--fields=+n', '-x', '--sort=no']
	if kinds_flag:
		cmd.append('--kinds-' + lang + '=+' + kinds_flag)
	cmd.append('--language-force=' + lang)
	cmd.append(filepath)

	try:
		result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
	except (subprocess.TimeoutExpired, FileNotFoundError):
		return None

	vars = {}
	for line in result.stdout.splitlines():
		parts = line.split()
		if len(parts) < 3:
			continue

		name   = parts[0]
		kind   = parts[1].lower()
		try:
			lineno = int(parts[2])
		except ValueError:
			continue

		if kind in SKIP_KINDS:
			continue
		if name.startswith('_') and name.endswith('_'):
			continue
		if filter_text and filter_text.lower() not in name.lower():
			continue

		context = KIND_TO_CONTEXT.get(kind, 'global')
		key = (name, context)
		if key not in vars:
			vars[key] = []
		if lineno not in vars[key]:
			vars[key].append(lineno)

	return vars

# Output

def print_vars(vars):
	context_order = {
		'global': 0, 'param': 1, 'local': 2,
		'class': 3, 'loop': 4, 'comp': 5, 'except': 6
	}
	sorted_vars = sorted(
		vars.items(),
		key=lambda x: (context_order.get(x[0][1], 9), x[0][0])
	)
	for (name, context), lines in sorted_vars:
		print(context + '|' + name + '|' + ','.join(str(l) for l in sorted(lines)))

# Main 

def main():
	if len(sys.argv) < 2:
		print("Usage: sigil.py <file> [filter]", file=sys.stderr)
		sys.exit(1)

	filepath    = sys.argv[1]
	filter_text = sys.argv[2] if len(sys.argv) > 2 else ''
	ext         = os.path.splitext(filepath)[1].lower()

	if not os.path.isfile(filepath):
		print("error|File not found: " + filepath + "|0", file=sys.stderr)
		sys.exit(1)

	try:
		with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
			source = f.read()
	except Exception as e:
		print("error|Could not read file: " + str(e) + "|0", file=sys.stderr)
		sys.exit(1)

	if ext == '.py':
		try:
			print_vars(parse_python(source, filter_text))
		except SyntaxError as e:
			print("error|Syntax error: " + str(e) + "|0", file=sys.stderr)
			sys.exit(1)
		return

	lang_config = CTAGS_LANGUAGES.get(ext)
	if lang_config is None:
		print("error|Unsupported file type: " + ext + "|0", file=sys.stderr)
		sys.exit(1)

	lang, kinds_flag = lang_config
	vars = parse_ctags(filepath, lang, kinds_flag, filter_text)

	if vars is None:
		print("error|ctags not found — install universal-ctags to parse " + ext + " files.|0",
		      file=sys.stderr)
		sys.exit(1)

	print_vars(vars)

if __name__ == '__main__':
	try:
		main()
	except BrokenPipeError:
		sys.exit(0)
