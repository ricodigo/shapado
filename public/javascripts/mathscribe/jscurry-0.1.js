/*  jscurry.js:  a JavaScript module for functional programming; requires ECMAScript 3.  These
	definitions are based on Haskell's, but allow side effects, and do not use automatic lazy
	evaluation, compile-time type checking, or automatic Currying.
	
	We believe that "member functions" are the wrong technique in general for implementing
	function closures or passing functions to polymorphic algorithms.
	
	Suffixes (in this and other modules):
		F:  function
		P ("Possible" or "Pointer"):  null/undefined treated specially
		Q ("Question"):  value effectively converted to a boolean when used
		S:  string
		_:  a non-constant variable with a large scope
		$:  a jQuery() result or "wrapped set"
	
	These library modules aim to be small, efficient, compatible with standards, and hopefully
	elegant.
	
	Copyright 2011, Mathscribe, Inc.  Dual licensed under the MIT or GPL Version 2 licenses.
	See e.g. http://jquery.org/license for an explanation of these licenses.  */


var jsCurry = function() {
	var sliceMF = Array.prototype.slice;	// slice "Member Function"
	
	// provide a few basic ECMAScript 5 functions if they are missing:
	if (! Function.prototype.bind)
		Function.prototype.bind = function(thisArg /* , ... */) {
			var f = this, args0 = sliceMF.call(arguments, 1);
			return function(/* ... */) {
				return f.apply(thisArg, args0.concat(sliceMF.call(arguments, 0)));
			};
		};
	if (! String.prototype.trim)
		String.prototype.trim = function() { return String(this).replace(/^\s+|\s+$/g, ''); };
	if (! Array.isArray)
		Array.isArray = function(x) {
			return typeof x == 'object' && x !== null &&
				Object.prototype.toString.call(x) === '[object Array]';
		};
	if (! Object.keys)
		Object.keys = function(obj) {
			var res = [];
			for (var p in obj)	if (obj.hasOwnProperty(p))	res.push(p);
			return res;
		};
	if (! Date.now)	Date.now = function() { return (new Date()).getTime(); };
	
	function F(x /* , ... */) {	// F() shorthand notation for some basic operations
		if (typeof x == 'function')	return F.curry.apply(undefined, arguments);
		if (arguments.length == 2 && typeof arguments[1] == 'function')
			return (typeof x == 'number' ? F.aritize : F.partial)(x, arguments[1]);
		arguments.length == 1 || F.err(err_F_1_);
		if (typeof x == 'number' || typeof x == 'string')	return F.p2f(x);
		if (x && typeof x == 'object')	return F.a2f(x);
		F.err(err_F_2_);
	}
	
	F.err = function() { throw Error('Assertion failed'); };
		// usually argument evaluation intentionally fails, to report its line number
	
	F.id = function(x) { return x; };
	F.constant = function(x) { return function(/* ... */) { return x; }; };
		// "const" is a reserved word in ECMAScript 3
	F.applyF = function(f, args) { return f.apply(undefined, args); }
	F.curry = function(f /* , ... */)
		{ var g = f; arguments[0] = undefined; return g.bind.apply(g, arguments); };
	F._ = {};	// needed since e.g. (0 in [ , 3]) is apparently wrong in e.g. Firefox 3.0
	F.partial = function(a, f) {	// 'a' supplies some arguments to 'f'
		var n = a.length;
		return function(/* ... */) {
			var args = sliceMF.call(arguments, 0);
			for (var i = 0; i < n; i++)	if (a[i] !== F._)	args.splice(i, 0, a[i]);
			return f.apply(this, args);
		};
	};
	F.uncurry = function(f) { return function(x, y) { return f(x)(y); }; };
	F.o = function(/* ... */) {	// composition of 1 or more functions
		var fs = arguments;
		return function(/* ... */) {
			var n = fs.length, res = fs[--n].apply(undefined, arguments);
			while (n > 0)	res = fs[--n](res);
			return res;
		};
	};
	F.oMap = function(f, g)	// composition, using F.map(g, <arguments>)
		{ return function(/* ... */) { return F.applyF(f, F.map(g, arguments)); }; };
	F.flip = function(f) { return function(x, y) { return f(y, x); }; };
	F.cor = function(/* ... */) {	// conditional or
		var fs = arguments;
		return function(/* ... */) { return F.any(F([F._, arguments], F.applyF), fs); };
	};
	F.aritize = function(n, f)	// for discarding optional trailing arguments
		{ return function(/* ... */) { return F.applyF(f, sliceMF.call(arguments, 0, n)); }; };
	
	F.bind0 = function(obj, p) { return obj[p].bind(obj); };
	
	F.not = function(x) { return ! x; };
	
	/*  The following functions that act on arrays also work on "array-like" objects (with a
		'length' property), including array-like host objects.  The functions may or may not
		skip missing elements.  */
	
	// A "cmp" function returns 0, < 0, or > 0 for ==, <, or > respectively.
	F.cmpX = function(x, y) { return x - y; };	// for finite numbers, or Dates
	F.cmpJS = function(s, t) { return s < t ? -1 : s > t ? 1 : 0; };
		// JavaScript built-in comparison; for numbers, strings, or Dates
	F.cmpLex = function(cmpE, v, w)	// "lexicographic order"; cmpE need not return a number
		{ return F.any(function(e, i) { return i == w.length ? 1 : cmpE(e, w[i]); }, v) ||
			v.length - w.length; };
	F.eqTo = function(x, cmpP) {
		if (! cmpP)	cmpP = function(y, z) { return y !== z; };
		return F.o(F.not, F(cmpP, x));
	};
	
	F.p2f = function(p) { return function(obj) { return obj[p]; }; };
	F.a2f = function(obj) { return function(p) { return obj[p]; }; };
	F.f2a = function(f, n) {
		var a = new Array(n);
		for (var i = 0; i < n; i++)	a[i] = f(i);
		return a;
	};
	F.memoF = function(f, memo) {
		if (! memo)	memo = {};
		return function(p) { return memo.hasOwnProperty(p) ? memo[p] : (memo[p] = f(p)); };
	};
	
	F.slice = function(a, startP, endP) {
		if (startP == null)	startP = 0;
		if (Array.isArray(a))
			return arguments.length < 3 ? a.slice(startP) : a.slice(startP, endP);
		var n = a.length;
		startP = startP < 0 ? Math.max(0, n + startP) : Math.min(n, startP);
		endP = endP == null ? n : endP < 0 ? Math.max(0, n + endP) : Math.min(n, endP);
		var res = [];
		while (startP < endP)	res.push(a[startP++]);
		return res;
	};
	F.array = function(/* ... */) { return sliceMF.call(arguments, 0); };
	F.concatArgs = F.oMap(F.bind0([], 'concat'),
		function(a) { return Array.isArray(a) ? a : F.slice(a); });
	F.concatMap = function(f, a) { return F.applyF(F.concatArgs, F.map(f, a)); };
	
	F.findIndex = function(qF, a) {
		var n = a.length;
		for (var i = 0; i < n; i++)	if (qF(a[i], i, a))	return i;
		return -1;
	};
	F.findLastIndex = function(qF, a) {
		for (var i = a.length; --i >= 0; )	if (qF(a[i], i, a))	return i;
		return -1;
	};
	F.find = function(qF, a) {
		var j = F.findIndex(qF, a);
		return j == -1 ? undefined : a[j];
	};
	F.elemIndex = function(e, a, cmpP) {
		if (a.indexOf && ! cmpP && Array.isArray(a))	return a.indexOf(e);
		return F.findIndex(F.eqTo(e, cmpP), a);
	};
	F.elemLastIndex = function(e, a, cmpP) {
		if (a.lastIndexOf && ! cmpP && Array.isArray(a))	return a.lastIndexOf(e);
		return F.findLastIndex(F.eqTo(e, cmpP), a);
	};
	F.elem = function(e, a, cmpP) { return F.elemIndex(e, a, cmpP) != -1; };
	F.all = function(qF, a) {
		if (a.every && Array.isArray(a))	return a.every(qF);
		var n = a.length;
		for (var i = 0; i < n; i++)	if (! qF(a[i], i, a))	return false;
		return true;
	};
	F.any = function(f, a) /* note result may be non-boolean */ {
		var n = a.length;
		for (var i = 0; i < n; i++) {
			var y = f(a[i], i, a);
			if (y)	return y;
		}
		return false;
	};
	F.iter = function(f, a /* , ... */) {
		if (arguments.length == 2) {	// for speed
			if (a.forEach && Array.isArray(a))	return a.forEach(f);
			var n = a.length;
			for (var i = 0; i < n; i++)	f(a[i], i, a);
		} else {
			arguments.length > 2 || F.err(err_iter_);
			var args = sliceMF.call(arguments, 1),
				n = F.applyF(Math.min, F.map(F('length'), args));
			for (var i = 0; i < n; i++)	F.applyF(f, F.map(F(i), args).concat(i, args));
		}
	};
	F.map = function(f, a) {
		if (a.map && Array.isArray(a))	return a.map(f);
		var n = a.length, res = new Array(n);
		for (var i = 0; i < n; i++)	res[i] = f(a[i], i, a);
		return res;
	};
	F.zipWith = function(f /* , ... */) {
		arguments.length > 1 || F.err(err_zipWith_);
		var res = [];
		for (var i = 0; ; i++) {
			var args = [];
			for (var j = 1; j < arguments.length; j++) {
				var a = arguments[j];
				if (i < a.length)	args.push(a[i]);
				else	return res;
			}
			res.push(F.applyF(f, args));
		}
		return res;
	};
	F.zip = F(F.zipWith, F.array);
	F.unzip =	// matrix transpose
		function(zs) { return zs.length ? F.applyF(F.zip, zs) : []; };
	F.filter = function(qF, a) {
		if (a.filter && Array.isArray(a))	return a.filter(qF);
		return F.fold(function(y, e, i, a) { if (qF(e, i, a)) y.push(e); return y; }, a, []);
	};
	F.fold = function(op, a, xOpt) {
		if (a.reduce && Array.isArray(a))
			return arguments.length < 3 ? a.reduce(op) : a.reduce(op, xOpt);
		var n = a.length, i = 0;
		if (arguments.length < 3)	xOpt = n ? a[i++] : F.err(err_fold_);
		for ( ; i < n; i++)	xOpt = op(xOpt, a[i], i, a);
		return xOpt;
	};
	F.foldR = function(op, a, xOpt) {	// similar to Haskell (foldr (flip op) xOpt a)
		if (a.reduceRight && Array.isArray(a))
			return arguments.length < 3 ? a.reduceRight(op) : a.reduceRight(op, xOpt);
		var n = a.length;
		if (arguments.length < 3)	xOpt = n ? a[--n] : F.err(err_foldR_);
		while (--n >= 0)	xOpt = op(xOpt, a[n], n, a);
		return xOpt;
	};
	
	F.sum = function(a) {
		var n = a.length, res = 0;
		for (var i = 0; i < n; i++)	res += a[i];
		return res;
	};
	
	F.test = function(t) {	// e.g. for dynamic type checking when appropriate
		if (t === 0 || t === '')	t = typeof t;
		if (typeof t == 'string')	return function(x) { return typeof x == t; };
		if (t === Array || t === Date || t === RegExp)	// assumes same frame
			return function(x) { return x != null && x.constructor == t; };
		if (t === null)	return F.eqTo(null);
		if (t.constructor == RegExp)	return F.bind0(t, 'test');	// assumes same frame
		if (typeof t == 'function')	return t;
		if (Array.isArray(t)) {
			if (t.length == 1) {
				t = F.test(t[0]);
				return function(x) { return Array.isArray(x) && F.all(t, x); };
			} else {	// "or" of tests
				t = F.map(F.test, t);
				return function(x) { return F.any(function(qF) { return qF(x); }, t); };
			}
		}
		if (typeof t == 'object') {
			var ks = Object.keys(t), fs = F.map(F.o(F.test, F(t)), ks);
			return function(x)
				{ return x != null && F.all(function(k, i) { return fs[i](x[k]); }, ks); };
		}
		F.err(err_test_);
	};
	
	return F;
}();
var F;	if (F === undefined)	F = jsCurry;
