package ax3.filters;

import ax3.ParseTree.DotPath;

/**
	Haxe only resolves unqualified static field access in the current class,
	while AS3 also looks up in parent classes. So this filter rewrites these
	cases into qualified access.
**/
class UnqualifiedSuperStatics extends AbstractFilter {
	var thisClass:Null<TClassOrInterfaceDecl>;
	override function processClass(c:TClassOrInterfaceDecl) {
		thisClass = c;
		super.processClass(c);
		thisClass = null;
	}

	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TEField({kind: TOImplicitClass(c), type: tSuperRef}, fieldName, fieldToken) if (c != thisClass):
				var leadTrivia = fieldToken.leadTrivia;
				fieldToken.leadTrivia = [];
				var eSuperRef = mkDeclRef(thisClass, c, leadTrivia);
				e.with(kind = TEField({kind: TOExplicit(mkDot(), eSuperRef), type: tSuperRef}, fieldName, fieldToken));
			case _:
				mapExpr(processExpr, e);
		}
	}

	public static function mkDeclRef(thisClass:TClassOrInterfaceDecl, c:TClassOrInterfaceDecl, leadTrivia:Array<Trivia>):TExpr {
		var dotPath:DotPath = {
			var parts;
			if (!thisClass.parentModule.isImported(c) && c.parentModule.pack.name != "") {
				parts = c.parentModule.pack.name.split(".");
				parts.push(c.name);
			} else {
				parts = [c.name];
			}
			{
				first: new Token(0, TkIdent, parts[0], leadTrivia, []),
				rest: [for (i in 1...parts.length) {sep: mkDot(), element: mkIdent(parts[i])}]
			};
		};
		var tDeclRef = TTStatic(c);
		return mk(TEDeclRef(dotPath, {name: c.name, kind: TDClassOrInterface(c)}), tDeclRef, tDeclRef);
	}
}
