package ax3;

import ax3.ParseTree;
import ax3.TypedTree;
import ax3.Token;
import ax3.TokenTools.*;
using ax3.WithMacro;

import ax3.TokenTools.mkSemicolon;

class TypedTreeTools {
	public static final tUntypedArray = TTArray(TTAny);
	public static final tUntypedObject = TTObject(TTAny);
	public static final tUntypedDictionary = TTDictionary(TTAny, TTAny);

	public static function isFieldStatic(field:TClassField):Bool {
		for (m in field.modifiers) {
			if (m.match(FMStatic(_))) return true;
		}
		return false;
	}

	static final singleTabIndent = [new Trivia(TrWhitespace, "\t")];

	public static function getInnerIndent(expr:TExpr):Array<Trivia> {
		return switch expr.kind {
			case TEBlock(block):
				if (block.exprs.length > 0) getIndent(block.exprs[0].expr)
				else getTokenIndent(block.syntax.closeBrace).concat(singleTabIndent); // assume closing brace on a separate line
			case _:
				[];
		}
	}

	static function getIndent(expr:TExpr):Array<Trivia> {
		return processLeadingToken(getTokenIndent, expr);
	}

	static function getTokenIndent(token:Token):Array<Trivia> {
		var result = [], hadOnlyWhitespace = true;
		for (trivia in token.leadTrivia) {
			switch trivia.kind {
				case TrBlockComment | TrLineComment:
					result = [];
					hadOnlyWhitespace = false;
				case TrNewline:
					result = [];
					hadOnlyWhitespace = true;
				case TrWhitespace:
					result.push(trivia);
			}
		}
		return if (hadOnlyWhitespace) result else [];
	}

	public static function getConstructor(cls:TClassOrInterfaceDecl):Null<TFunctionField> {
		var extend;
		switch (cls.kind) {
			case TInterface(_): return null;
			case TClass(info): extend = info.extend;
		}

		for (m in cls.members) {
			switch m {
				case TMField({kind: TFFun(f)}) if (f.name == cls.name):
					return f;
				case _:
			}
		}
		if (extend != null) {
			return getConstructor(extend.superClass);
		}
		return null;
	}

	public static function concatExprs(a:TExpr, b:TExpr):TExpr {
		return switch [a.kind, b.kind] {
			case [TEBlock(aBlock), TEBlock(bBlock)]:
				mk(TEBlock({
					syntax: {
						openBrace: aBlock.syntax.openBrace,
						closeBrace: bBlock.syntax.closeBrace,
					},
					exprs: aBlock.exprs.concat(bBlock.exprs)
				}), TTVoid, TTVoid);

			case [TEBlock(block), _]:
				a.with(
					kind = TEBlock(block.with(
						exprs = block.exprs.concat([{expr: b, semicolon: addTrailingNewline(mkSemicolon())}])
					))
				);

			case [_, TEBlock(block)]:
				b.with(
					kind = TEBlock(block.with(
						exprs = [{expr: a, semicolon: addTrailingNewline(mkSemicolon())}].concat(block.exprs)
					))
				);

			case _:
				var lead = removeLeadingTrivia(a);
				var trail = removeTrailingTrivia(b);
				mk(TEBlock({
						syntax: {
							openBrace: new Token(0, TkBraceOpen, "{", lead, []),
							closeBrace: new Token(0, TkBraceClose, "}", [], trail),
						},
						exprs: [
							{expr: a, semicolon: addTrailingNewline(mkSemicolon())},
							{expr: b, semicolon: addTrailingNewline(mkSemicolon())},
						]
				}), TTVoid, TTVoid);
		}
	}

	public static function exprPos(e:TExpr):Int {
		return switch e.kind {
			case TEParens(openParen, _): openParen.pos;
			case TELocalFunction(f): f.syntax.keyword.pos;
			case TELiteral(TLThis(t) | TLSuper(t) | TLBool(t) | TLNull(t) | TLUndefined(t) | TLInt(t) | TLNumber(t) | TLString(t) | TLRegExp(t)): t.pos;
			case TELocal(t, _): t.pos;
			case TEField(_, _, fieldToken): fieldToken.pos;
			case TEBuiltin(t, _): t.pos;
			case TEDeclRef(path, _): path.first.pos;
			case TECall(_, args): args.openParen.pos;
			case TECast(c): c.syntax.path.first.pos;
			case TEArrayDecl(a): a.syntax.openBracket.pos;
			case TEVectorDecl(v): v.syntax.newKeyword.pos;
			case TEReturn(keyword, _) | TEThrow(keyword, _) | TEDelete(keyword, _) | TEBreak(keyword) | TEContinue(keyword): keyword.pos;
			case TEVars(VVar(t) | VConst(t), _): t.pos;
			case TEObjectDecl(o): o.syntax.openBrace.pos;
			case TEArrayAccess(a): a.syntax.openBracket.pos;
			case TEBlock(block): block.syntax.openBrace.pos;
			case TETry(t): t.keyword.pos;
			case TEVector(syntax, _): syntax.name.pos;
			case TETernary(t): t.syntax.question.pos;
			case TEIf(i): i.syntax.keyword.pos;
			case TEWhile(w): w.syntax.keyword.pos;
			case TEDoWhile(w): w.syntax.doKeyword.pos;
			case TEFor(f): f.syntax.keyword.pos;
			case TEForIn(f): f.syntax.forKeyword.pos;
			case TEForEach(f): f.syntax.forKeyword.pos;
			case TEHaxeFor(f): f.syntax.forKeyword.pos;
			case TEBinop(a, OpAdd(t) | OpSub(t) | OpDiv(t) | OpMul(t) | OpMod(t) | OpAssign(t) | OpEquals(t) | OpNotEquals(t) | OpStrictEquals(t) | OpNotStrictEquals(t) | OpGt(t) | OpGte(t) | OpLt(t) | OpLte(t) | OpIn(t) | OpIs(t) | OpAnd(t) | OpOr(t) | OpShl(t) | OpShr(t) | OpUshr(t) | OpBitAnd(t) | OpBitOr(t) | OpBitXor(t) | OpComma(t), b): t.pos;
			case TEBinop(a, OpAssignOp(AOpAdd(t) | AOpSub(t) | AOpMul(t) | AOpDiv(t) | AOpMod(t) | AOpAnd(t) | AOpOr(t) | AOpBitAnd(t) | AOpBitOr(t) | AOpBitXor(t) | AOpShl(t) | AOpShr(t) | AOpUshr(t)), b): t.pos;
			case TEPreUnop(PreNot(t) | PreNeg(t) | PreIncr(t) | PreDecr(t) | PreBitNeg(t), e): t.pos;
			case TEPostUnop(e, PostIncr(t) | PostDecr(t)): t.pos;
			case TEAs(e, keyword, type): keyword.pos;
			case TESwitch(s): s.syntax.keyword.pos;
			case TENew(keyword, eclass, args): keyword.pos;
			case TECondCompValue(v): v.syntax.ns.pos;
			case TECondCompBlock(v, expr): v.syntax.ns.pos;
			case TEXmlChild(x): x.syntax.dot.pos;
			case TEXmlAttr(x): x.syntax.dot.pos;
			case TEXmlAttrExpr(x): x.syntax.openBracket.pos;
			case TEXmlDescend(x): x.syntax.dotDot.pos;
			case TEUseNamespace(ns): ns.useKeyword.pos;
			case TEHaxeRetype(e): exprPos(e);
			case TEHaxeIntIter(start, _): exprPos(start);
		}
	}

	public static function addParens(e:TExpr):TExpr {
		return switch (e.kind) {
			case TEParens(_):
				e;
			case _:
				var lead = removeLeadingTrivia(e);
				var trail = removeTrailingTrivia(e);
				var openParen = new Token(0, TkParenOpen, "(", lead, []);
				var closeParen = new Token(0, TkParenClose, ")", [], trail);
				e.with(
					kind = TEParens(openParen, e, closeParen),
					type = e.expectedType
				);
		}
	}

	/** Is it safe to repeat this expression a couple times :) **/
	public static function canBeRepeated(e:TExpr):Bool {
		return switch (e.kind) {
			case TEParens(_, e, _): canBeRepeated(e);

			case TELocal(_) | TELiteral(_) | TEBuiltin(_) | TEDeclRef(_): true;

			// TODO: check whether it's a getter
			case TEField({kind: TOExplicit(_, e)}, _, _): canBeRepeated(e);
			case TEField({kind: TOImplicitThis(_) | TOImplicitClass(_)}, _, _): true;

			case TEArrayAccess(a): canBeRepeated(a.eobj) && canBeRepeated(a.eindex);

			case _: false;
		}
	}

	public static inline function mk(kind:TExprKind, type:TType, expectedType:TType):TExpr {
		return {kind: kind, type: type, expectedType: expectedType};
	}

	public static function getFunctionTypeFromSignature(f:TFunctionSignature):TType {
		var args = [], rest:Null<TRestKind> = null;
		for (a in f.args) {
			switch a.kind {
				case TArgNormal(_): args.push(a.type);
				case TArgRest(_, kind): rest = kind;
			}
		}
		return TTFun(args, f.ret.type, rest);
	}

	public static function mkDeclRef(path:DotPath, decl:TDecl, expectedType:Null<TType>):TExpr {
		var type = switch (decl.kind) {
			case TDVar(v): v.vars[0].type; // TODO: it shouldn't be an array in the typed AST actually
			case TDFunction(f): getFunctionTypeFromSignature(f.fun.sig);
			case TDClassOrInterface(c): TTStatic(c);
			case TDNamespace(_): throw "assert"; // should NOT happen :)
		};
		if (expectedType == null) expectedType = type;
		return mk(TEDeclRef(path, decl), type, expectedType);
	}

	public static inline function mkNullExpr(t = TTAny, ?lead, ?trail):TExpr {
		return mk(TELiteral(TLNull(new Token(0, TkIdent, "null", if (lead != null) lead else [], if (trail != null) trail else []))), t, t);
	}

	public static function mkBuiltin(n:String, t:TType, ?leadTrivia, ?trailTrivia):TExpr {
		if (leadTrivia == null) leadTrivia = [];
		if (trailTrivia == null) trailTrivia = [];
		return mk(TEBuiltin(new Token(0, TkIdent, n, leadTrivia, trailTrivia), n), t, t);
	}

	public static function mkCall(obj:TExpr, args:Array<TExpr>, ?t:TType, ?trail:Array<Trivia>):TExpr {
		if (t == null) {
			t = switch obj.type {
				case TTFun(_, ret): ret;
				case _: TTAny;
			}
		}
		var closeParen = mkCloseParen();
		if (trail != null) closeParen.trailTrivia = trail;
		return mk(TECall(obj, {
			openParen: mkOpenParen(),
			args: [for (i in 0...args.length) {expr: args[i], comma: if (i == args.length - 1) null else commaWithSpace}],
			closeParen: closeParen,
		}), t, t);
	}

	public static function skipParens(e:TExpr):TExpr {
		return switch e.kind {
			case TEParens(_, einner, _): einner;
			case _: e;
		};
	}

	/** remove and return the leading trivia of an expression **/
	public static function removeLeadingTrivia(e:TExpr):Array<Trivia> {
		return processLeadingToken(function(t) {
			var trivia = t.leadTrivia;
			t.leadTrivia = [];
			return trivia;
		}, e);
	}

	public static function processLeadingToken<T>(r:Token->T, e:TExpr):T {
		inline function fromDotPath(p:DotPath) return r(p.first);
		return switch e.kind {
			case TEParens(openParen, _, _): r(openParen);
			case TELocalFunction(f): r(f.syntax.keyword);
			case TELiteral(TLThis(t) | TLSuper(t)| TLBool(t)| TLNull(t)| TLUndefined(t)| TLInt(t)| TLNumber(t)| TLString(t)| TLRegExp(t)): r(t);
			case TELocal(t, _): r(t);
			case TEField({kind: TOImplicitThis(_) | TOImplicitClass(_)}, _, fieldToken): r(fieldToken);
			case TEField({kind: TOExplicit(_, obj)}, _, _): processLeadingToken(r, obj);
			case TEBuiltin(t, _): r(t);
			case TEDeclRef(path, _): fromDotPath(path);
			case TECall(eobj, _): processLeadingToken(r, eobj);
			case TECast(c): fromDotPath(c.syntax.path);
			case TEArrayDecl(a): r(a.syntax.openBracket);
			case TEVectorDecl(v): r(v.syntax.newKeyword);
			case TEReturn(keyword, _) | TEThrow(keyword, _) | TEDelete(keyword, _) | TEBreak(keyword) | TEContinue(keyword): r(keyword);
			case TEVars(VVar(t) | VConst(t), _): r(t);
			case TEObjectDecl(o): r(o.syntax.openBrace);
			case TEArrayAccess(a): processLeadingToken(r, a.eobj);
			case TEBlock(block): r(block.syntax.openBrace);
			case TETry(t): r(t.keyword);
			case TEVector(syntax, _): r(syntax.name);
			case TETernary(t): processLeadingToken(r, t.econd);
			case TEIf(i): r(i.syntax.keyword);
			case TEWhile(w): r(w.syntax.keyword);
			case TEDoWhile(w): r(w.syntax.doKeyword);
			case TEFor(f): r(f.syntax.keyword);
			case TEForIn(f): r(f.syntax.forKeyword);
			case TEForEach(f): r(f.syntax.forKeyword);
			case TEHaxeFor(f): r(f.syntax.forKeyword);
			case TEBinop(a, _, _): processLeadingToken(r, a);
			case TEPreUnop(PreNot(t) | PreNeg(t) | PreIncr(t) | PreDecr(t) | PreBitNeg(t), _): r(t);
			case TEPostUnop(e, _): processLeadingToken(r, e);
			case TEAs(e, _, _): processLeadingToken(r, e);
			case TESwitch(s): r(s.syntax.keyword);
			case TENew(keyword, _, _): r(keyword);
			case TECondCompValue(v) | TECondCompBlock(v, _): r(v.syntax.ns);
			case TEXmlChild(x): processLeadingToken(r, x.eobj);
			case TEXmlAttr(x): processLeadingToken(r, x.eobj);
			case TEXmlAttrExpr(x): processLeadingToken(r, x.eobj);
			case TEXmlDescend(x): processLeadingToken(r, x.eobj);
			case TEUseNamespace(ns): r(ns.useKeyword);
			case TEHaxeRetype(e): processLeadingToken(r, e);
			case TEHaxeIntIter(start, _): processLeadingToken(r, start);
		}
	}

	/** remove and return the trailing trivia of an expression **/
	public static function removeTrailingTrivia(e:TExpr):Array<Trivia> {
		return processTrailingToken(function(token) {
			var trivia = token.trailTrivia;
			token.trailTrivia = [];
			return trivia;
		}, e);
	}

	public static function processTrailingToken<T>(r:Token->T, e:TExpr):T {
		function fromDotPath(p:DotPath) {
			return
				if (p.rest.length == 0) r(p.first)
				else r(p.rest[p.rest.length - 1].element);
		}

		function fromSyntaxType(t:SyntaxType) {
			return switch (t) {
				case TAny(star): r(star);
				case TPath(path): fromDotPath(path);
				case TVector(v): r(v.t.gt);
			}
		}

		return switch e.kind {
			case TEParens(_, _, closeParen): r(closeParen);
			case TELocalFunction(f): processTrailingToken(r, f.fun.expr);
			case TELiteral(TLThis(t) | TLSuper(t)| TLBool(t)| TLNull(t)| TLUndefined(t)| TLInt(t)| TLNumber(t)| TLString(t)| TLRegExp(t)): r(t);
			case TELocal(t, _): r(t);
			case TEField(_, _, t): r(t);
			case TEBuiltin(t, _): r(t);
			case TEDeclRef(path, _): fromDotPath(path);
			case TECall(_, args): r(args.closeParen);
			case TECast(c): r(c.syntax.closeParen);
			case TEArrayDecl(a): r(a.syntax.closeBracket);
			case TEVectorDecl(v): r(v.elements.syntax.closeBracket);
			case TEBreak(keyword) | TEContinue(keyword) | TEReturn(keyword, null): r(keyword);
			case TEReturn(_, e) | TEThrow(_, e) | TEDelete(_, e): processTrailingToken(r, e);
			case TEObjectDecl(o): r(o.syntax.closeBrace);
			case TEArrayAccess(a): r(a.syntax.closeBracket);
			case TEBlock(block): r(block.syntax.closeBrace);
			case TETry(t): processTrailingToken(r, t.catches[t.catches.length - 1].expr);
			case TEIf(i): processTrailingToken(r, if (i.eelse == null) i.ethen else i.eelse.expr);
			case TEVars(_, vars):
				var v = vars[vars.length - 1];
				if (v.init != null) processTrailingToken(r, v.init.expr)
				else if (v.syntax.type != null) fromSyntaxType(v.syntax.type.type)
				else r(v.syntax.name);
			case TEVector(syntax, type): r(syntax.t.gt);
			case TETernary(t): processTrailingToken(r, t.eelse);
			case TEWhile(w): processTrailingToken(r, w.body);
			case TEDoWhile(w): r(w.syntax.closeParen);
			case TEHaxeFor(f): processTrailingToken(r, f.body);
			case TEFor(f): processTrailingToken(r, f.body);
			case TEForIn(f): processTrailingToken(r, f.body);
			case TEForEach(f): processTrailingToken(r, f.body);
			case TEBinop(_, _, b): processTrailingToken(r, b);
			case TEPreUnop(_, e): processTrailingToken(r, e);
			case TEPostUnop(_, PostIncr(t) | PostDecr(t)): r(t);
			case TEAs(_, _, type): fromSyntaxType(type.syntax);
			case TESwitch(s): r(s.syntax.closeBrace);
			case TENew(_, eclass, args):
				if (args == null) processTrailingToken(r, eclass)
				else r(args.closeParen);
			case TECondCompValue(v): r(v.syntax.name);
			case TECondCompBlock(_, expr): processTrailingToken(r, expr);
			case TEXmlChild(x): r(x.syntax.name);
			case TEXmlAttr(x): r(x.syntax.name);
			case TEXmlAttrExpr(x): r(x.syntax.closeBracket);
			case TEXmlDescend(x): r(x.syntax.name);
			case TEUseNamespace(ns): r(ns.name);
			case TEHaxeRetype(e): processTrailingToken(r, e);
			case TEHaxeIntIter(_, end): processTrailingToken(r, end);
		}
	}

	public static function mapExpr(f:TExpr->TExpr, e1:TExpr):TExpr {
		return switch (e1.kind) {
			case TEVector(_) | TELiteral(_) | TEUseNamespace(_) | TELocal(_) | TEBuiltin(_) | TEDeclRef(_) | TEReturn(_, null) | TEBreak(_) | TEContinue(_) | TECondCompValue(_):
				e1;

			case TEField({kind: TOImplicitThis(_) | TOImplicitClass(_)}, _, _):
				e1;

			case TEField(obj = {kind: TOExplicit(dot, e)}, fieldName, fieldToken):
				var mapped = f(e);
				if (mapped == e) e1 else e1.with(kind = TEField(obj.with(kind = TOExplicit(dot, mapped)), fieldName, fieldToken));

			case TECast(c):
				var mapped = f(c.expr);
				if (mapped == c.expr) e1 else e1.with(kind = TECast(c.with(expr = mapped)));

			case TEParens(openParen, e, closeParen):
				var mapped = f(e);
				if (mapped == e)
					e1
				else
					e1.with(
						kind = TEParens(openParen, mapped, closeParen),
						// also update the type of parens as they are pure wrapper
						type = mapped.type,
						expectedType = mapped.expectedType
					);

			case TECall(eobj, args):
				var mappedObj = f(eobj);
				var mappedArgs = mapCallArgs(f, args);
				if (mappedObj == eobj && mappedArgs == args) e1 else e1.with(kind = TECall(mappedObj, mappedArgs));

			case TEArrayDecl(a):
				e1.with(kind = TEArrayDecl(mapArrayDecl(f, a)));

			case TEReturn(keyword, e):
				var mapped = f(e);
				if (mapped == e) e1 else e1.with(kind = TEReturn(keyword, mapped));

			case TEThrow(keyword, e):
				var mapped = f(e);
				if (mapped == e) e1 else e1.with(kind = TEThrow(keyword, mapped));

			case TEDelete(keyword, e):
				var mapped = f(e);
				if (mapped == e) e1 else e1.with(kind = TEDelete(keyword, mapped));

			case TEBlock(block):
				var mapped = mapBlock(f, block);
				if (mapped == block) e1 else e1.with(kind = TEBlock(mapped));

			case TEIf(e):
				var mappedCond = f(e.econd);
				var mappedThen = f(e.ethen);
				var mappedElse =
					if (e.eelse == null) {
						null;
					} else {
						var mapped = f(e.eelse.expr);
						if (mapped == e.eelse.expr) e.eelse else e.eelse.with(expr = mapped);
					};

				if (mappedCond == e.econd && mappedThen == e.ethen && mappedElse == e.eelse)
					e1
				else
					e1.with(kind = TEIf(e.with(econd = mappedCond, ethen = mappedThen, eelse = mappedElse)));

			case TETry(t):
				e1.with(kind = TETry(t.with(
					expr = f(t.expr),
					catches = [for (c in t.catches) c.with(expr = f(c.expr))]
				)));

			case TELocalFunction(fun):
				e1.with(kind = TELocalFunction(fun.with(
					fun = fun.fun.with(expr = f(fun.fun.expr))
				)));

			case TEVectorDecl(v):
				e1.with(kind = TEVectorDecl(v.with(elements = mapArrayDecl(f, v.elements))));

			case TEArrayAccess(a):
				var mappedObj = f(a.eobj);
				var mappedIdx = f(a.eindex);
				if (mappedObj == a.eobj && mappedIdx == a.eindex) e1 else e1.with(kind = TEArrayAccess(a.with(eobj = mappedObj, eindex = mappedIdx)));

			case TEVars(kind, vars):
				var mappedVars = mapVarDecls(f, vars);
				if (mappedVars == vars) e1 else e1.with(kind = TEVars(kind, mappedVars));

			case TEObjectDecl(o):
				e1.with(kind = TEObjectDecl(o.with(
					fields = [for (field in o.fields) field.with(expr = f(field.expr))]
				)));

			case TETernary(t):
				e1.with(kind = TETernary(t.with(
					econd = f(t.econd),
					ethen = f(t.ethen),
					eelse = f(t.eelse)
				)));

			case TEWhile(w):
				e1.with(kind = TEWhile(w.with(
					cond = f(w.cond),
					body = f(w.body)
				)));

			case TEDoWhile(w):
				e1.with(kind = TEDoWhile(w.with(
					body = f(w.body),
					cond = f(w.cond)
				)));

			case TEHaxeFor(l):
				e1.with(kind = TEHaxeFor(l.with(
					iter = f(l.iter),
					body = f(l.body)
				)));

			case TEFor(l):
				e1.with(kind = TEFor(l.with(
					einit = if (l.einit == null) null else f(l.einit),
					econd = if (l.econd == null) null else f(l.econd),
					eincr = if (l.eincr == null) null else f(l.eincr),
					body = f(l.body)
				)));

			case TEForIn(l):
				e1.with(kind = TEForIn(l.with(
					iter = l.iter.with(eit = f(l.iter.eit), eobj = f(l.iter.eobj)),
					body = f(l.body)
				)));

			case TEForEach(l):
				e1.with(kind = TEForEach(l.with(
					iter = l.iter.with(eit = f(l.iter.eit), eobj = f(l.iter.eobj)),
					body = f(l.body)
				)));

			case TEBinop(a, op, b):
				var mappedA = f(a);
				var mappedB = f(b);
				if (mappedA == a && mappedB == b) e1 else e1.with(kind = TEBinop(mappedA, op, mappedB));

			case TEPreUnop(op, e):
				var mapped = f(e);
				if (mapped == e) e1 else e1.with(kind = TEPreUnop(op, mapped));

			case TEPostUnop(e, op):
				var mapped = f(e);
				if (mapped == e) e1 else e1.with(kind = TEPostUnop(mapped, op));

			case TEAs(e, keyword, type):
				var mapped = f(e);
				if (mapped == e) e1 else e1.with(kind = TEAs(mapped, keyword, type));

			case TESwitch(s):
				e1.with(kind = TESwitch(s.with(
					subj = f(s.subj),
					cases = [
						for (c in s.cases)
							c.with(values = [for (e in c.values) f(e)], body = mapBlockExprs(f, c.body))
					],
					def = if (s.def == null) null else s.def.with(body = mapBlockExprs(f, s.def.body))
				)));

			case TENew(keyword, eclass, args):
				var mappedClass = f(eclass);
				var mappedArgs = if (args == null) null else mapCallArgs(f, args);
				if (mappedClass == eclass && mappedArgs == args) e1 else e1.with(kind = TENew(keyword, mappedClass, mappedArgs));

			case TECondCompBlock(v, expr):
				e1.with(kind = TECondCompBlock(v, f(expr)));

			case TEXmlAttr(x):
				e1.with(kind = TEXmlAttr(x.with(eobj = f(x.eobj))));

			case TEXmlChild(x):
				e1.with(kind = TEXmlChild(x.with(eobj = f(x.eobj))));

			case TEXmlAttrExpr(x):
				e1.with(kind = TEXmlAttrExpr(x.with(
					eobj = f(x.eobj),
					eattr = f(x.eattr)
				)));

			case TEXmlDescend(x):
				e1.with(kind = TEXmlDescend(x.with(eobj = f(x.eobj))));

			case TEHaxeRetype(e):
				var mapped = f(e);
				if (mapped == e) e1 else e1.with(kind = TEHaxeRetype(mapped));

			case TEHaxeIntIter(start, end):
				var mappedStart = f(start);
				var mappedEnd = f(end);
				if (mappedStart == start && mappedEnd == end) e1 else e1.with(kind = TEHaxeIntIter(mappedStart, mappedEnd));
		}
	}

	static function mapArrayDecl(f:TExpr->TExpr, a:TArrayDecl):TArrayDecl {
		return a.with(elements = [for (e in a.elements) e.with(expr = f(e.expr))]);
	}

	public static function mapCallArgs(f:TExpr->TExpr, a:TCallArgs):TCallArgs {
		var r:Null<Array<{expr:TExpr, comma:Null<Token>}>> = null;
		for (i in 0...a.args.length) {
			var arg = a.args[i];
			var mapped = f(arg.expr);
			if (mapped != arg.expr) {
				if (r == null) r = a.args.slice(0, i);
				r.push(arg.with(expr = mapped));
			} else if (r != null) {
				r.push(arg);
			}
		}
		return if (r == null) a else a.with(args = r);
	}

	public static function mapBlock(f:TExpr->TExpr, b:TBlock):TBlock {
		var mapped = mapBlockExprs(f, b.exprs);
		return if (mapped == b.exprs) b else b.with(exprs = mapped);
	}

	static function mapVarDecls(f:TExpr->TExpr, decls:Array<TVarDecl>):Array<TVarDecl> {
		var r:Null<Array<TVarDecl>> = null;
		for (i in 0...decls.length) {
			var v = decls[i];
			var mapped;
			if (v.init == null) {
				mapped = v;
			} else {
				var mappedInitExpr = f(v.init.expr);
				if (mappedInitExpr != v.init.expr) {
					mapped = v.with(init = v.init.with(expr = mappedInitExpr));
				} else {
					mapped = v;
				}
			}
			if (mapped != v) {
				if (r == null) r = decls.slice(0, i);
				r.push(mapped);
			} else if (r != null) {
				r.push(v);
			}
		}
		return if (r == null) decls else r;
	}

	public static function mapBlockExprs(f:TExpr->TExpr, exprs:Array<TBlockExpr>):Array<TBlockExpr> {
		var r:Null<Array<TBlockExpr>> = null;
		for (i in 0...exprs.length) {
			var e = exprs[i];
			var mapped = f(e.expr);
			if (mapped != e.expr) {
				if (r == null) r = exprs.slice(0, i);
				r.push(e.with(expr = mapped));
			} else if (r != null) {
				r.push(e);
			}
		}
		return if (r == null) exprs else r;
	}

	public static function determineCastKind(valueType:TType, asClass:TClassOrInterfaceDecl):CastKind {
		return switch valueType {
			// TODO: support sameclass/upcast for interfaces since we don't need to generate Std.instance here
			case TTInst(valueClass = {kind: TClass(_)}):
				if (valueClass == asClass)
					CKSameClass
				else if (isChildClass(valueClass, asClass))
					CKUpcast
				else if (isChildClass(asClass, valueClass))
					CKDowncast
				else
					CKUnknown;
			case _:
				CKUnknown;
		}
	}

	static function isChildClass(cls:TClassOrInterfaceDecl, base:TClassOrInterfaceDecl):Bool {
		while (true) {
			if (cls == base) {
				return true;
			}
			switch cls.kind {
				case TInterface(_):
					return false;
				case TClass(classInfo):
					if (classInfo.extend == null) {
						return false;
					} else {
						cls = classInfo.extend.superClass;
					}
			}
		}
		return false;
	}
}

enum CastKind {
	CKSameClass;
	CKDowncast;
	CKUpcast;
	CKUnknown;
}
