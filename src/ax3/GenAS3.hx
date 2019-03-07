package ax3;

import ax3.ParseTree;
import ax3.TypedTree;

@:nullSafety
class GenAS3 extends PrinterBase {
	public function writeModule(m:TModule) {
		printPackage(m.pack);
		printTrivia(m.eof.leadTrivia);
	}

	function printPackage(p:TPackageDecl) {
		printTextWithTrivia("package", p.syntax.keyword);
		if (p.syntax.name != null) printDotPath(p.syntax.name);
		printOpenBrace(p.syntax.openBrace);
		printDecl(p.decl);
		printCloseBrace(p.syntax.closeBrace);
	}

	function printDecl(d:TDecl) {
		switch (d) {
			case TDClass(c): printClassClass(c);
		}
	}

	function printClassClass(c:TClassDecl) {
		for (m in c.modifiers) {
			switch (m) {
				case DMPublic(t): printTextWithTrivia(t.text, t);
				case DMInternal(t): printTextWithTrivia(t.text, t);
				case DMFinal(t): printTextWithTrivia(t.text, t);
				case DMDynamic(t): printTextWithTrivia(t.text, t);
			}
		}
		printTextWithTrivia("class", c.syntax.keyword);
		printTextWithTrivia(c.name, c.syntax.name);
		printOpenBrace(c.syntax.openBrace);
		for (m in c.members) {
			switch (m) {
				case TMField(f): printClassField(f);
			}
		}
		printCloseBrace(c.syntax.closeBrace);
	}

	function printClassField(f:TClassField) {
		switch (f.kind) {
			case TFVar:
			case TFProp:
			case TFFun(f):
				printTextWithTrivia("function", f.syntax.keyword);
				printTextWithTrivia(f.name, f.syntax.name);
				printSignature(f.fun.sig);
				printBlock(f.fun.block);
		}
	}

	function printSignature(sig:TFunctionSignature) {
		printOpenParen(sig.syntax.openParen);
		printCloseParen(sig.syntax.closeParen);
		printTypeHint(sig.ret);
	}

	function printTypeHint(hint:TTypeHint) {
		if (hint.syntax != null) {
			printColon(hint.syntax.colon);
		}
	}

	function printExpr(e:TExpr) {
		switch (e.kind) {
			case TEFunction(f):
			case TELiteral(l): printLiteral(l);
			case TELocal(syntax, v): printTextWithTrivia(syntax.text, syntax);
			case TEField(object, fieldName, fieldToken): printFieldAccess(object, fieldName, fieldToken);
			case TEBuiltin(syntax, name):
			case TEDeclRef(c):
			case TECall(syntax, eobj, args):
			case TEArrayDecl(syntax, elems):
			case TEVectorDecl(type, elems):
			case TEReturn(keyword, e): printTextWithTrivia("return", keyword); if (e != null) printExpr(e);
			case TEThrow(keyword, e): printTextWithTrivia("throw", keyword); printExpr(e);
			case TEDelete(keyword, e): printTextWithTrivia("delete", keyword); printExpr(e);
			case TEBreak(keyword): printTextWithTrivia("break", keyword);
			case TEContinue(keyword): printTextWithTrivia("continue", keyword);
			case TEVars(v):
			case TEObjectDecl(syntax, fields):
			case TEArrayAccess(eobj, eindex):
			case TEBlock(block): printBlock(block);
			case TETry(expr, catches):
			case TEVector(type):
			case TETernary(econd, ethen, eelse):
			case TEIf(econd, ethen, eelse):
			case TEWhile(econd, ebody):
			case TEDoWhile(ebody, econd):
			case TEFor(einit, econd, eincr, ebody):
			case TEForIn(eit, eobj, ebody):
			case TEBinop(a, op, b):
			case TEComma(a, b):
			case TEIs(e, etype):
			case TEAs(e, type):
			case TESwitch(esubj, cases, def):
			case TENew(eclass, args):
			case TECondCompBlock(ns, name, expr):
			case TEXmlAttr(e, name):
			case TEXmlAttrExpr(e, eattr):
			case TEXmlDescend(e, name):
			case TENothing:
		}
	}

	function printFieldAccess(obj:TFieldObject, name:String, token:Token) {
		switch (obj.kind) {
			case TOExplicit(dot, e):
				printExpr(e);
				printDot(dot);
			case TOImplicitThis(_):
			case TOImplicitClass(_):
		}
		printTextWithTrivia(name, token);
	}

	function printLiteral(l:TLiteral) {
		switch (l) {
			case TLSuper(syntax): printTextWithTrivia("super", syntax);
			case TLThis(syntax): printTextWithTrivia("this", syntax);
			case TLBool(syntax): printTextWithTrivia(syntax.text, syntax);
			case TLNull(syntax): printTextWithTrivia("null", syntax);
			case TLUndefined(syntax): printTextWithTrivia("undefined", syntax);
			case TLInt(syntax): printTextWithTrivia(syntax.text, syntax);
			case TLNumber(syntax): printTextWithTrivia(syntax.text, syntax);
			case TLString(syntax): printTextWithTrivia(syntax.text, syntax);
			case TLRegExp(syntax): printTextWithTrivia(syntax.text, syntax);
		}
	}

	function printBlock(block:TBlock) {
		printOpenBrace(block.syntax.openBrace);
		for (e in block.exprs) {
			printExpr(e.expr);
			if (e.semicolon != null) printSemicolon(e.semicolon);
		}
		printCloseBrace(block.syntax.closeBrace);
	}
}
