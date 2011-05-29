/*  jqmath.js:  a JavaScript module for symbolic expressions, e.g. formatted mathematical
	formulas.  This file uses charset UTF-8, and requires jQuery 1.0+, jsCurry, and jqmath.css.
	By default, we use MathML when available, else simple HTML and CSS.  Expressions may be
	constructed programmatically, or using a simple TeX-like syntax.
	
	To use symbolic expressions in a web page or problem domain, one must choose a set of
	symbols, ensure they can be viewed by users, and specify precedences for the operator
	symbols.  We use Unicode character numbers for encoding, and fonts for display.  Normally
	standard characters and fonts suffice, but "private use" character numbers and custom fonts
	can be used when necessary.  By default, this module currently uses standard MathML 3
	precedences for operator symbols, except we omit "multiple character operator"s like && or
	<=, and choose a single precedence for each of |, ^, and _.
	
	The algorithm to detect MathML only works after some document.body is defined and available.
	Thus it should probably not be used during document loading.
	
	See http://mathscribe.com/author/jqmath.html for usage documentation and examples, and
	jscurry.js for some coding conventions and goals.
	
	Copyright 2011, Mathscribe, Inc.  Dual licensed under the MIT or GPL Version 2 licenses.
	See e.g. http://jquery.org/license for an explanation of these licenses.  */


var jqMath = function() {
	var $ = jQuery, F = jsCurry;
	
	function M(s, blockQ, docP) { return M.s2mathE(s, blockQ, docP); }
	
	M.mathmlNS = "http://www.w3.org/1998/Math/MathML";	// MathML namespace
	
	if ($.browser.msie)
		document.write(
			'<object id=MathPlayer classid="clsid:32F66A20-7614-11D4-BD11-00104BD3F987">',
			'</object><?IMPORT namespace="m" implementation="#MathPlayer" ?>');
	var MathPlayerQ_ = false;
	function newMENS(tag, args$P /* for jQuery append() if != null */, docP)
			/* tries to use the MathML namespace, perhaps with prefix 'm' */ {
		if (! docP)	docP = document;
		var e = MathPlayerQ_ ? docP.createElement('m:'+tag) :
			docP.createElementNS(M.mathmlNS, tag);
		if (args$P != null)	$(e).append(args$P);
		return e;
	}
	// M.mathmlQP_ controls whether MathML is used.
	M.checkMathML = function(doc) /* requires doc.body; computes M.mathmlQP_ if nec. */ {
		if ($.browser.msie)
			try {
				new ActiveXObject("MathPlayer.Factory.1");
				MathPlayerQ_ = true;
			} catch(exc) {}
		if (! MathPlayerQ_ && typeof doc.createElementNS == 'undefined')	M.mathmlQP_ = false;
		if (M.mathmlQP_ != null)	return;
		
		var e1 = newMENS('math', newMENS('mn', '1', doc), doc),
			e2 = newMENS('math',
				newMENS('mfrac', $([newMENS('mn', '1', doc), newMENS('mn', '2', doc)]), doc),
				doc),
			es$ = $(F.map(function(e) { return $('<div/>', doc).append(e)[0]; },
					$([e1, e2]).attr('display', 'block')));
		es$.css('visibility', 'hidden').appendTo(doc.body);
		M.mathmlQP_ = $(es$[1]).height() > $(es$[0]).height() + 2;
		es$.remove();
	};
	
	// fmUp is mid-x to outer top, fmDn is mid-x to outer bottom, both approx. & in parent ems
	function checkVertStretch(up, dn, g) /* non-MathML */ {
		if (g.nodeName.toLowerCase() == 'mo' && g.childNodes.length == 1) {
			var c = g.firstChild, s = c.data;
			if (c.nodeType == 3 /* Text */ && (up > 0.9 || dn > 0.9)
			&& (M.prefix_[s] < 25 || M.postfix_[s] < 25
					|| '|\u2016\u221A' /* ‖ &radic; */.indexOf(s) != -1)) {
				var r = (up + dn) / 1.2, radicQ = s == '\u221A',
					v = (radicQ ? 0.26 : 0.35) + ((radicQ ? 0.15 : 0.25) - dn) / r;
				g.style.fontSize = r.toFixed(3)+'em';
				g.style.verticalAlign = v.toFixed(3)+'em';
			}
		}
	}
	function vertAlignE$(up, dn, fmVert) /* non-MathML */ {
		var e$ = $('<span/>').append(fmVert);
		e$[0].fmUp = up;
		e$[0].fmDn = dn;
		e$[0].style.verticalAlign = (0.5 * (up - dn)).toFixed(3)+'em';
		return e$;
	}
	M.newME = function(tag, args$P /* for jQuery append() if != null */, docP) {
		if (! docP)	docP = document;
		M.mathmlQP_ != null || F.err(err_newME_mathmlQP_);
		
		if (M.mathmlQP_)	return newMENS(tag, args$P, docP);
		
		var e$ = $(docP.createElement(tag));
		if (args$P != null)	e$.append(args$P);
		var a = F.slice(e$[0].childNodes),	// partly because e$[0].childNodes is dynamic
			ups = F.map(function(g) { return Number(g.fmUp || 0.6); }, a),
			dns = F.map(function(g) { return Number(g.fmDn || 0.6); }, a);
		
		if (tag == 'math')	e$.addClass('fm');
		else if (tag == 'mn' || tag == 'mo' || tag == 'mtext'
		|| tag == 'mspace' /* note its width/etc. attributes won't work */)
			;
		else if (tag == 'mi') {
			a.length == 1 || F.err(err_newME_mi_);
			var c = a[0];
			if (c.nodeType == 3 /* Text */ && c.data.length == 1) {
				e$.addClass('fm-mi-length-1');
				if ('EFHIJKMNTUVWXYZdfl'.indexOf(c.data) != -1)
					e$.css('padding-right', '0.44ex');
			}
		} else if (tag == 'mrow') {
			var up = F.applyF(Math.max, ups), dn = F.applyF(Math.max, dns);
			if (up > 0.65 || dn > 0.65) {
				e$[0].fmUp = up;
				e$[0].fmDn = dn;
				F.iter(F(checkVertStretch, up, dn), a);
			}
		} else if (tag == 'mfrac') {
			a.length == 2 || F.err(err_newME_mfrac_);
			var num$ = $('<td class="fm-num-frac fm-inline"></td>', docP).append(a[0]),
				den$ = $('<td class="fm-den-frac fm-inline"></td>', docP).append(a[1]);
			e$ = vertAlignE$(ups[0] + dns[0] + 0.03, ups[1] + dns[1] + 0.03,
				$('<span class="fm-vert fm-frac"></span>', docP).	// partly for IE6,
						// see www.quirksmode.org/css/display.html
					append($('<table/>', docP).
						append($('<tbody/>', docP).
							append($('<tr/>', docP).append(num$)).
							append($('<tr/>', docP).append(den$)))));
		} else if (tag == 'msqrt' || tag == 'mroot') {
			a.length == (tag == 'msqrt' ? 1 : 2) || F.err(err_newME_root_);
			e$ = $('<mrow/>', docP);
			var t = 0.06*(ups[0] + dns[0]), up = ups[0] + t + 0.1, dn = dns[0],
				mo$ = $('<mo/>', docP).addClass('fm-radic').append('\u221A' /* &radic; */),
					// IE8 doesn't like $('<mo class="fm-radic"></mo>').append(...)
				y$ = vertAlignE$(up, dn,
					$('<span class="fm-vert fm-radicand"></span>', docP).append(a[0]).
						css('borderTopWidth', t.toFixed(3)+'em'));
			checkVertStretch(up, dn, mo$[0]);
			if (tag == 'mroot') {
				var ht = 0.6 * (ups[1] + dns[1]), d = 0.25/0.6 - 0.25;
				if (up > ht)	d += up/0.6 - ups[1];
				else {
					d += dns[1];
					up = ht;
				}
				e$.append($('<sup class="fm-root fm-inline"></sup>', docP).append(a[1]).
						css('verticalAlign', d.toFixed(2)+'em'));
			}
			e$.append(mo$).append(y$);
			e$[0].fmUp = up;
			e$[0].fmDn = dn;
		} else if (tag == 'msub' || tag == 'msup' || tag == 'msubsup') {
			a.length == (tag == 'msubsup' ? 3 : 2) || F.err(err_newME_sub_sup_);
			var up = ups[0], dn = dns[0];
			for (var i = 1; i < a.length; i++) {
				var ht = 0.71 * (ups[i] + dns[i]), d = 0.25/0.71 - 0.25;
				if (i == 1 && tag != 'msup') {
					if (dn > ht)	d -= dn/0.71 - dns[i];
					else {
						d -= ups[i];
						dn = ht;
					}
				} else {
					if (up > ht)	d += up/0.71 - ups[i];
					else {
						d += dns[i];
						up = ht;
					}
				}
				$(a[i]).wrap('<span class="fm-script fm-inline"></span>').parent().
					css('verticalAlign', d.toFixed(2)+'em');
				if ($.browser.msie && (document.documentMode || $.browser.version) < 8)
					a[i].style.zoom = 1;	// to set hasLayout
			}
			e$[0].fmUp = up;
			e$[0].fmDn = dn;
		} else if (tag == 'munder' || tag == 'mover' || tag == 'munderover') {
			a.length == (tag == 'munderover' ? 3 : 2) || F.err(err_newME_under_over_);
			var tbody$ = $('<tbody/>', docP), td$, up = 0.85 * ups[0], dn = 0.85 * dns[0];
			if (tag != 'munder') {
				td$ = $('<td class="fm-script fm-inline"></td>', docP).append(a[a.length - 1]);
				tbody$.append($('<tr/>', docP).append(td$));
				up += 0.71 * (ups[a.length - 1] + dns[a.length - 1]);
			}
			td$ = $('<td class="fm-underover-base"></td>', docP).append(a[0]);
			tbody$.append($('<tr/>', docP).append(td$));
			if (tag != 'mover') {
				td$ = $('<td class="fm-script fm-inline"></td>', docP).append(a[1]);
				tbody$.append($('<tr/>', docP).append(td$));
				dn += 0.71 * (ups[1] + dns[1]);
			}
			e$ = vertAlignE$(up, dn, $('<span class="fm-vert"></span>', docP).
					append($('<table/>', docP).append(tbody$)));
		} else if (tag == 'mtable') {
			var tbody$ = $('<tbody/>', docP).append($(a));
			e$ = $('<span class="fm-vert"></span>', docP).append($('<table/>', docP).
				append(tbody$));
			var r = F.sum(ups) + F.sum(dns);
			e$[0].fmUp = e$[0].fmDn = 0.5 * r;
		} else if (tag == 'mtr') {
			e$ = $('<tr class="fm-mtr"></tr>', docP).append($(a));
			e$[0].fmUp = (a.length ? F.applyF(Math.max, ups) : 0.6) + 0.25;
			e$[0].fmDn = (a.length ? F.applyF(Math.max, dns) : 0.6) + 0.25;
		} else if (tag == 'mtd') {
			e$ = $('<td class="fm-mtd"></td>', docP).append($(a));
			if (ups[0] > 0.65)	e$[0].fmUp = ups[0];
			if (dns[0] > 0.65)	e$[0].fmDn = dns[0];
		} else	F.err(err_newME_);
		return e$[0];
	};
	M.thinSpaceME = function(docP) /* partly to avoid bad font support for \u2009 &thinsp; */ {
		/* E.g. in Firefox 3.6.12, the DOM/jQuery don't like '' as a <mi>/<mo>/<mtext> child,
			and also padding doesn't seem to work on e.g. <mn>/<mrow>/<mspace> elements: */
		var e = M.newME('mspace', null, docP);
		if (M.mathmlQP_)	$(e).attr('width', '0.17em');	// since padding may not work
		else	$(e).addClass('fm-thin-space');
		return e;
	}
	M.fenceME = function(me1, leftP, rightP, docP)
		{ return M.newME('mrow',
			$([M.newME('mo', leftP || '(', docP), me1, M.newME('mo', rightP || ')', docP)]),
			docP); };
	
	M.decsE = function(s, docP) /* converts the numeric string 's' to an HTML or XML 'math'
			element */ {
		if (! docP)	docP = document;
		
		M.checkMathML(docP);
		var negQ = false;
		if (s.charAt(0) == '-') {
			s = s.substring(1);
			negQ = true;
		}
		var e = M.newME('mn', s, docP);
		if (negQ)	e = M.newME('mrow', $([M.newME('mo', '\u2212', docP), e]), docP);
		return M.newME('math', e, docP);
	};
	
	/*  Like TeX, we use ^ for superscripts, _ for subscripts, {} for grouping, and \ (or `) as
		an escape character.  Spaces and newline characters are ignored.  We also use ↖ (\u2196)
		and ↙ (\u2199) to put limits above and below an operator or expression.  You can
		$.extend() or even replace M.infix_, M.prefix_, M.postfix_, M.macros_, M.macro1s_, and
		M.alias_ as needed.  */
	M.combiningChar_ = '[\u0300-\u036F\u1DC0-\u1DFF\u20D0-\u20FF\uFE20-\uFE2F]';
	M.surrPair_ = '[\uD800-\uDBFF][\uDC00-\uDFFF]';
	var numPat_ = '\\d+\\.?\\d*|\\.\\d+', escPat_ = '[\\\\`]([A-Za-z]+|.)';
	M.re_ /* .lastIndex set during use */ =
		RegExp('('+numPat_+')|'+escPat_+'|'+M.surrPair_+'|\\S'+M.combiningChar_+'*', 'g');
	M.infix_ = {	// operator precedences, see http://www.w3.org/TR/MathML3/appendixc.html
		'⊂⃒': 240, '⊃⃒': 240,
		'≪̸': 260, '≫̸': 260, '⪯̸': 260, '⪰̸': 260,
		'∽̱': 265, '≂̸': 265, '≎̸': 265, '≏̸': 265, '≦̸': 265, '≿̸': 265, '⊏̸': 265, '⊐̸': 265, '⧏̸': 265,
		'⧐̸': 265, '⩽̸': 265, '⩾̸': 265, '⪡̸': 265, '⪢̸': 265,
		
		// if non-MathML and precedence <= 270, then class is 'fm-infix-loose' not 'fm-infix'
		
		/* '-' is converted to '\u2212' &minus; − */
		'\u2009' /* &thinsp; ' ', currently generates an <mspace> */: 390,
		
		'' /* no <mo> is generated */: 500 /* not 390 or 850 */
		
		/* \^ or `^  880 not 780, \_ or `_ 880 not 900 */
		
		// unescaped ^ _ ↖ (\u2196) ↙ (\u2199) have precedence 999
	};
	// If an infix op is also prefix or postfix, it must use the same precedence in each form.
	// Also, we omit "multiple character operator"s like && or <=.
	M.prefix_ = {};
		// prefix precedence < 25 => thin space not inserted between multi-letter <mi> and it;
		//	(prefix or postfix precedence < 25) and non-MathML => <mo> stretchy;
		//	precedence < 25 => can be a fence
		
		// can use {|...|} for absolute value
		
		// + - % and other infix ops can automatically be used as prefix and postfix ops
		
		// if non-MathML and prefix and 290 <= precedence <= 350, then 'fm-large-op'
	M.postfix_ = {
		// (unquoted) ' is converted to '\u2032' &prime; ′
	};
	function setPrecs(precs, precCharsA) {
		F.iter(function(prec_chars) {
				var prec = prec_chars[0];
				F.iter(function(c) { precs[c] = prec; }, prec_chars[1].split(''));
			}, precCharsA);
	}
	setPrecs(M.infix_, [
			[21, '|'],	// | not 20 or 270
			[30, ';'],
			[40, ',\u2063'],
			[70, '∴∵'],
			[100, ':'],
			[110, '϶'],
			[150, '…⋮⋯⋱'],
			[160, '∋'],
			[170, '⊢⊣⊤⊨⊩⊬⊭⊮⊯'],
			[190, '∨'],
			[200, '∧'],
			[240, '∁∈∉∌⊂⊃⊄⊅⊆⊇⊈⊉⊊⊋'],
			[241, '≤'],
			[242, '≥'],
			[243, '>'],
			[244, '≯'],
			[245, '<'],
			[246, '≮'],
			[247, '≈'],
			[250, '∼≉'],
			[252, '≢'],
			[255, '≠'],
			[260, '=∝∤∥∦≁≃≄≅≆≇≍≔≗≙≚≜≟≡≨≩≪≫≭≰≱≺≻≼≽⊀⊁⊥⊴⊵⋉⋊⋋⋌⋔⋖⋗⋘⋙⋪⋫⋬⋭■□▪▫▭▮▯▰▱△▴▵▶▷▸▹▼▽▾▿◀◁◂◃'+
				'◄◅◆◇◈◉◌◍◎●◖◗◦⧀⧁⧣⧤⧥⧦⧳⪇⪈⪯⪰'],
			[265, '⁄∆∊∍∎∕∗∘∙∟∣∶∷∸∹∺∻∽∾∿≂≊≋≌≎≏≐≑≒≓≕≖≘≝≞≣≦≧≬≲≳≴≵≶≷≸≹≾≿⊌⊍⊎⊏⊐⊑⊒⊓⊔⊚⊛⊜⊝⊦⊧⊪⊫⊰⊱⊲⊳⊶⊷⊹⊺⊻⊼⊽⊾⊿⋄⋆⋇'+
				'⋈⋍⋎⋏⋐⋑⋒⋓⋕⋚⋛⋜⋝⋞⋟⋠⋡⋢⋣⋤⋥⋦⋧⋨⋩⋰⋲⋳⋴⋵⋶⋷⋸⋹⋺⋻⋼⋽⋾⋿▲❘⦁⦂⦠⦡⦢⦣⦤⦥⦦⦧⦨⦩⦪⦫⦬⦭⦮⦯⦰⦱⦲⦳⦴⦵⦶⦷⦸⦹⦺⦻⦼⦽⦾⦿⧂⧃⧄'+
				'⧅⧆⧇⧈⧉⧊⧋⧌⧍⧎⧏⧐⧑⧒⧓⧔⧕⧖⧗⧘⧙⧛⧜⧝⧞⧠⧡⧢⧧⧨⧩⧪⧫⧬⧭⧮⧰⧱⧲⧵⧶⧷⧸⧹⧺⧻⧾⧿⨝⨞⨟⨠⨡⨢⨣⨤⨥⨦⨧⨨⨩⨪⨫⨬⨭⨮⨰⨱⨲⨳⨴⨵⨶⨷⨸⨹'+
				'⨺⨻⨼⨽⨾⩀⩁⩂⩃⩄⩅⩆⩇⩈⩉⩊⩋⩌⩍⩎⩏⩐⩑⩒⩓⩔⩕⩖⩗⩘⩙⩚⩛⩜⩝⩞⩟⩠⩡⩢⩣⩤⩥⩦⩧⩨⩩⩪⩫⩬⩭⩮⩯⩰⩱⩲⩳⩴⩵⩶⩷⩸⩹⩺⩻⩼⩽⩾⩿⪀⪁⪂⪃⪄⪅⪆⪉⪊⪋⪌⪍⪎⪏'+
				'⪐⪑⪒⪓⪔⪕⪖⪗⪘⪙⪚⪛⪜⪝⪞⪟⪠⪡⪢⪣⪤⪥⪦⪧⪨⪩⪪⪫⪬⪭⪮⪱⪲⪳⪴⪵⪶⪷⪸⪹⪺⪻⪼⪽⪾⪿⫀⫁⫂⫃⫄⫅⫆⫇⫈⫉⫊⫋⫌⫍⫎⫏⫐⫑⫒⫓⫔⫕⫖⫗⫘⫙⫚⫛⫝⫝⫞⫟⫠⫡⫢⫣⫤⫥⫦'+
				'⫧⫨⫩⫪⫫⫬⫭⫮⫯⫰⫱⫲⫳⫴⫵⫶⫷⫸⫹⫺⫻⫽⫾'],
			[270, '←↑→↓↔↕↖↗↘↙↚↛↜↝↞↟↠↡↢↣↤↥↦↧↨↩↪↫↬↭↮↯↰↱↲↳↴↵↶↷↸↹↺↻↼↽↾↿⇀⇁⇂⇃⇄⇅⇆⇇⇈⇉⇊⇋⇌⇍⇎⇏⇐⇑'+
				'⇒⇓⇔⇕⇖⇗⇘⇙⇚⇛⇜⇝⇞⇟⇠⇡⇢⇣⇤⇥⇦⇧⇨⇩⇪⇫⇬⇭⇮⇯⇰⇱⇲⇳⇴⇵⇶⇷⇸⇹⇺⇻⇼⇽⇾⇿⊸⟰⟱⟵⟶⟷⟸⟹⟺⟻⟼⟽⟾⟿⤀⤁⤂⤃⤄'+
				'⤅⤆⤇⤈⤉⤊⤋⤌⤍⤎⤏⤐⤑⤒⤓⤔⤕⤖⤗⤘⤙⤚⤛⤜⤝⤞⤟⤠⤡⤢⤣⤤⤥⤦⤧⤨⤩⤪⤫⤬⤭⤮⤯⤰⤱⤲⤳⤴⤵⤶⤷⤸⤹⤺⤻⤼⤽⤾⤿⥀⥁⥂⥃⥄⥅⥆⥇⥈⥉⥊⥋⥌⥍⥎⥏⥐⥑⥒'+
				'⥓⥔⥕⥖⥗⥘⥙⥚⥛⥜⥝⥞⥟⥠⥡⥢⥣⥤⥥⥦⥧⥨⥩⥪⥫⥬⥭⥮⥯⥰⥱⥲⥳⥴⥵⥶⥷⥸⥹⥺⥻⥼⥽⥾⥿⦙⦚⦛⦜⦝⦞⦟⧟⧯⧴⭅⭆'],
			[275, '+-±−∓∔⊞⊟'],
			[300, '⊕⊖⊘'],
			[340, '≀'],
			[350, '∩∪'],
			[390, '*.×•\u2062⊠⊡⋅⨯⨿'],
			[400, '·'],
			[410, '⊗'],
			[640, '%'],
			[650, '\\∖'],
			[660, '/÷'],
			[710, '⊙'],
			[825, '@'],
			[835, '?'],
			[850, '\u2061'],
			[880, '^_\u2064']]);
	setPrecs(M.prefix_, [
			[10, '‘“'],
			[20, '([{‖⌈⌊❲⟦⟨⟪⟬⟮⦀⦃⦅⦇⦉⦋⦍⦏⦑⦓⦕⦗⧼'],
			[230, '∀∃∄'],
			[290, '∑⨊⨋'],
			[300, '∬∭⨁'],
			[310, '∫∮∯∰∱∲∳⨌⨍⨎⨏⨐⨑⨒⨓⨔⨕⨖⨗⨘⨙⨚⨛⨜'],
			[320, '⋃⨃⨄'],
			[330, '⋀⋁⋂⨀⨂⨅⨆⨇⨈⨉⫼⫿'],
			[350, '∏∐'],
			[670, '∠∡∢'],
			[680, '¬'],
			[740, '∂∇'],
			[845, 'ⅅⅆ√∛∜']]);
	setPrecs(M.postfix_, [
			[10, '’”'],
			[20, ')]}‖⌉⌋❳⟧⟩⟫⟭⟯⦀⦄⦆⦈⦊⦌⦎⦐⦒⦔⦖⦘⧽'],
			[800, '′♭♮♯'],
			[810, '!'],
			[880, '&\'`~¨¯°´¸ˆˇˉˊˋˍ˘˙˚˜˝˷\u0302\u0311‾\u20db\u20dc⎴⎵⏜⏝⏞⏟⏠⏡']]);
	
	var s_, docP_, precAdj_;
	
	function scan_word(descP) {
		var re = /\S+/g;
		re.lastIndex = M.re_.lastIndex;
		var match = re.exec(s_);
		if (! match)	throw 'Missing '+(descP || 'word');
		M.re_.lastIndex = re.lastIndex;
		return match[0];
	}
	function braceParseMxTok() {
		var mxP_tokP = parse_mxP_tokP(0);
		tokP = mxP_tokP[1];
		if (! tokP)	throw 'Missing "}"';
		tokP[1] == '}' && ! tokP[0] || F.err(err_braceParseMx_);
		return [mxP_tokP[0] || M.newME('mspace', null, docP_), null];
	}
	function scan_meTok(afterP) {
		var tokP = scan_tokP();
		if (tokP && ! tokP[0] && tokP[1] == '{')	return braceParseMxTok();
		if (! tokP || ! tokP[0])
			throw 'Missing expression'+(afterP ? ' after '+afterP : '')+', at position '+
				re.lastIndex;
		return tokP;
	}
	function addClass(e, w) {
		// $(e).addClass(w) doesn't seem to work for XML elements
		if (typeof e.className != 'undefined') {	// needed for old IE, works for non-XML
			var classes = e.className;
			e.className = (classes ? classes+' ' : '')+w;
		} else {	// needed for XML, would work for non-IE
			var classes = e.getAttribute('class');
			e.setAttribute('class', (classes ? classes+' ' : '')+w);
		}
		return e;
	}
	function clScan() {	// note currently ignored by MathPlayer
		var desc = 'CSS class name', w = scan_word(desc), tok = scan_meTok(desc);
		addClass(tok[0], w);
		return tok;
	}
	// see http://www.w3.org/TR/MathML3/chapter3.html#presm.commatt for mathvariant attr
	function mvScan(wP) {
		var desc = 'mathvariant', w = wP || scan_word(desc), tok = scan_meTok(desc),
			me = tok[0];
		if (! F.elem(me.tagName.toLowerCase(),
				['mi', 'mn', 'mo', 'mtext', 'mspace', 'ms',
					'm:mi', 'm:mn', 'm:mo', 'm:mtext', 'm:mspace', 'm:ms']))
			throw 'Can only apply a mathvariant to a MathML token (atomic) element, at '+
				'position '+re.lastIndex;
		
		me.setAttribute('mathvariant', w);
		
		if (/bold/.test(w))	addClass(me, 'ma-bold');
		else if (w == 'normal' || w == 'italic')	addClass(me, 'ma-nonbold');
		
		addClass(me, /italic/.test(w) ? 'ma-italic' : 'ma-upright');
		
		if (/double-struck/.test(w))	addClass(me, 'ma-double-struck');
		else if (/fraktur/.test(w))	addClass(me, 'ma-fraktur');
		else if (/script/.test(w))	addClass(me, 'ma-script');
		else if (/sans-serif/.test(w))	addClass(me, 'ma-sans-serif');
		
		// (monospace, initial, tailed, looped, stretched) are currently ignored
		
		return tok;
	}
	function frScan() {
		var tok = scan_meTok('\\fr'), me = tok[0];
		if (! F.elem(me.tagName.toLowerCase(), ['mi', 'm:mi']))
			throw 'Can only apply \\fr to an identifier, at position '+re.lastIndex;
		
		me.setAttribute('mathvariant', 'fraktur');
		addClass(me, 'ma-upright');	// use \mv italic-fraktur for italic fraktur
		addClass(me, 'ma-fraktur');
		
		return tok;
	}
	function scScan() {
		var tok = scan_meTok('\\sc'), me = tok[0];
		if (! F.elem(me.tagName.toLowerCase(), ['mi', 'm:mi']))
			throw 'Can only apply \\sc to an identifier, at position '+re.lastIndex;
		
		me.setAttribute('mathvariant', 'script');
		addClass(me, 'ma-upright');	// use \mv italic-script for italic script
		addClass(me, 'ma-script');
		
		return tok;
	}
	// A "tok" (scanner token) here is an [meP, opSP].
	M.macros_ /* each returns a tokP */ = {
		cl: clScan, mv: F(0, mvScan), bo: F(mvScan, 'bold'), it: F(mvScan, 'italic'),
		bi: F(mvScan, 'bold-italic'), fr: frScan, sc: scScan
	};
	
	M.alias_ = { '-': '\u2212' /* &minus; */, '\'': '\u2032' /* &prime; */,
		'\u212D': ['C', 'fraktur'], '\u210C': ['H', 'fraktur'], '\u2111': ['I', 'fraktur'],
		'\u211C': ['R', 'fraktur'], '\u2128': ['Z', 'fraktur'],
		'\u212C': ['B', 'script'], '\u2130': ['E', 'script'], '\u2131': ['F', 'script'],
		'\u210B': ['H', 'script'], '\u2110': ['I', 'script'], '\u2112': ['L', 'script'],
		'\u2133': ['M', 'script'], '\u211B': ['R', 'script'], '\u212F': ['e', 'script'],
		'\u210A': ['g', 'script'], /* '\u2113': ['l', 'script'], */ '\u2134': ['o', 'script']
	};
	function scan_tokP() {
		var match = M.re_.exec(s_);
		if (! match) {
			M.re_.lastIndex = s_.length;
			return null;
		}
		var s1 = match[2] || match[0], mvP = null;
		if (/^[_^{}\u2196\u2199]$/.test(match[0]) || match[2] && M.macro1s_[s1])
			return [null, s1];
		if (match[2] && M.macros_[s1])	return M.macros_[s1]();
		if (match[1])	return [M.newME('mn', s1, docP_), null];
		if (match[2] == ',')	s1 = '\u2009' /* &thinsp; */;
		else if (M.alias_[s1] && ! match[2]) {
			var t = M.alias_[s1];
			if (typeof t == 'string')	s1 = t;
			else {
				s1 = t[0];
				mvP = t[1];	// 'double-struck', 'fraktur', or 'script'
			}
		}
		var opSP = M.infix_[s1] || M.prefix_[s1] || M.postfix_[s1] ? s1 : null, e;
		if (s1 == '\u2009' /* &thinsp; */)
			e = M.thinSpaceME(docP_);	// avoid bad font support, incl. in MathML
		else if (opSP)	e = M.newME('mo', docP_.createTextNode(s1), docP_);
			// createTextNode() apparently needed for '<' in Safari
		else {
			e = M.newME('mi', s1, docP_);
			if (match[2]) {
				e.setAttribute('mathvariant', 'normal');
				addClass(e, 'ma-upright');
			} else if (mvP) {
				e.setAttribute('mathvariant', mvP);
				addClass(e, 'ma-upright');
				addClass(e, 'ma-'+mvP);
			}
			if (/\w\w/.test(s1))	$(e).addClass('ma-repel-adj');
		}
		return [e, opSP];
	}
	
	function parse_table_tokP() {
		var mtrs = [], tokP = null, prec = M.infix_[','];
		while (true) {
			var mtds = [];
			while (true) {
				var mxP_tokP = parse_mxP_tokP(prec), mxP = mxP_tokP[0];
				tokP = mxP_tokP[1] || scan_tokP();
				if (mxP || tokP && tokP[1] == ',')
					mtds.push(M.newME('mtd', mxP || M.newME('mspace', null, docP_), docP_));
				if (! (tokP && tokP[1] == ','))	break;
			}
			if (mtds.length || tokP && tokP[1] == ';')
				mtrs.push(M.newME('mtr', $(mtds), docP_));
			if (! (tokP && tokP[1] == ';'))	break;
		}
		return [M.newME('mtable', $(mtrs), docP_), tokP];
	}
	// An "mx" here is an "me" that is not just a bare operator.
	M.macro1s_ /* each returns mxP_tokP, so can do precedence-based look-ahead */ =
		{ table: parse_table_tokP };
	
	/*+ Add an "@" macro for saving references to subexpressions, or an "id" macro and/or "data"
		macro, or a syntax to insert scanned expressions? +*/
	
	function checkSubSup(me, tokP) /* returns [me, tokP] */ {
		var subP = null, supP = null, underP = null, overP = null, anyQ = false;
		while (true) {
			if (! tokP)	tokP = scan_tokP();
			if (! tokP || tokP[0])	break;
			var op = tokP[1];
			if (op == '_' ? anyQ && ! supP :
				op == '^' ? anyQ && ! subP :
				op == '\u2199' /* ↙ */ ? anyQ && ! overP :
				op == '\u2196' /* ↖ */ ? anyQ && ! underP :
					true)	break;
			var mxP_tokP = parse_mxP_tokP(999);
			if (op == '_')				subP = mxP_tokP[0];
			else if (op == '^')			supP = mxP_tokP[0];
			else if (op == '\u2199')	underP = mxP_tokP[0];
			else						overP = mxP_tokP[0];
			tokP = mxP_tokP[1];
			if (anyQ)	break;
			anyQ = mxP_tokP[0];
		}
		if (subP && supP)	me = M.newME('msubsup', $([me, subP, supP]), docP_);
		else if (subP)	me = M.newME('msub', $([me, subP]), docP_);
		else if (supP)	me = M.newME('msup', $([me, supP]), docP_);
		else if (underP && overP)	me = M.newME('munderover', $([me, underP, overP]), docP_);
		else if (underP)	me = M.newME('munder', $([me, underP]), docP_);
		else if (overP)	me = M.newME('mover', $([me, overP]), docP_);
		return [me, tokP];
	}
	function parse_mxP_tokP(prec, tokP) /* tokP may be non-atomic */ {
		var mx0p = null;
		while (true) {
			if (! tokP) {
				tokP = scan_tokP();
				if (! tokP)	break;
			}
			var op = tokP[1];	// may be null/undefined
			if (! op
			|| mx0p && (tokP[0] ? ! (M.infix_[op] || M.postfix_[op]) : M.macro1s_[op])) {
				if (! mx0p) {
					mx0p = tokP[0];
					tokP = null;
				} else {
					if (prec >= precAdj_)	break;
					var mxP_tokP = parse_mxP_tokP(precAdj_, tokP), mx1 = mxP_tokP[0];
					mx1 || F.err(err_parse_mxP_tokP_1_);
					var e = M.newME('mrow', $([mx0p, mx1]), docP_);
					if ($(mx0p).hasClass('ma-repel-adj') || $(mx1).hasClass('ma-repel-adj')) {
						/* setting padding on mx0p or mx1 doesn't work on e.g. <mn> or <mrow>
							elements in Firefox 3.6.12 */
						if (! (op && tokP[0] && M.prefix_[op] < 25))
							$(mx0p).after(M.thinSpaceME(docP_));
						$(e).addClass('ma-repel-adj');
					}
					mx0p = e;
					tokP = mxP_tokP[1];
				}
			} else {
				var moP = tokP[0];
				if (moP) {
					var precL = M.infix_[op] || M.postfix_[op];
					if (precL && prec >= precL)	break;
					var precROpt = M.infix_[op] || ! (mx0p && M.postfix_[op]) && M.prefix_[op];
					if (! M.mathmlQP_ && ! mx0p && 290 <= precROpt && precROpt <= 350) {
						$(moP).addClass('fm-large-op');
						//+ omit if fm-inline:
						moP.fmUp = 0.85*1.3 - 0.25;
						moP.fmDn = 0.35*1.3 + 0.25;
					}
					var me_tokP = checkSubSup(moP), a = [];
					tokP = me_tokP[1];
					if (mx0p)	a.push(mx0p);
					a.push(me_tokP[0]);
					if (precROpt) {
						var mxP_tokP = parse_mxP_tokP(precROpt, tokP);
						if (mxP_tokP[0])	a.push(mxP_tokP[0]);
						tokP = mxP_tokP[1];
						if (precROpt && precROpt < 25 && ! mx0p) {	// check for fences
							if (! tokP)	tokP = scan_tokP();
							if (tokP && tokP[1] && tokP[0]
							&& (M.postfix_[tokP[1]] || M.infix_[tokP[1]]) == precROpt) {
								// don't checkSubSup() here [after fences]
								a.push(tokP[0]);
								tokP = null;
							}
						}
					}
					if (op == '/' && mx0p && a.length == 3
					|| op == '\u221A' /* &radic; */ && ! mx0p && a.length == 2) {
						a.splice(a.length - 2, 1);
						mx0p = M.newME(op == '/' ? 'mfrac' : 'msqrt', $(a), docP_);
					} else {
						var e = M.newME('mrow', $(a), docP_);
						if (op == '\u2009' /* &thinsp; */ || (precL || precROpt) >= precAdj_)
							;
						else {
							var k = '';
							if (a.length == 2) {
								k = mx0p ? 'postfix' : 'prefix';
								if (M.infix_[op])	k += '-tight';
								else	$(e).addClass('ma-repel-adj');
							} else if (mx0p)
								k = op == ',' || op == ';' ? 'separator' :
									precL <= 270 ? 'infix-loose' : 'infix';
							if (! M.mathmlQP_ && k)	$(me_tokP[0]).addClass('fm-'+k);
						}
						mx0p = e;
					}
				} else if (op == '}')	break;
				else if (op == '{')	tokP = braceParseMxTok();
				else if (M.macro1s_[op]) {
					! mx0p || F.err(err_parse_mxP_tokP_macro_);
					var mxP_tokP = M.macro1s_[op]();
					mx0p = mxP_tokP[0];
					tokP = mxP_tokP[1];
				} else {
					/^[_^\u2196\u2199]$/.test(op) || F.err(err_parse_mxP_tokP_script_);
					if (prec >= 999)	break;
					var me_tokP = checkSubSup(mx0p || M.newME('mspace', null, docP_), tokP);
					mx0p = me_tokP[0];
					tokP = me_tokP[1];
				}
			}
		}
		return [mx0p, tokP];
	}
	M.s2mathE = function(s, blockQ, docP) /* converts the formula 's' to an HTML or XML 'math'
			element */ {
		typeof s == 'string' && M.infix_[''] && M.infix_[','] || F.err(err_s2mathE_1_);
		if (! docP)	docP = document;
		
		M.checkMathML(docP);
		M.re_.lastIndex = 0;
		s_ = s;
		docP_ = docP;
		precAdj_ = M.infix_[''];
		
		var mxP_tokP = parse_mxP_tokP(0);
		if (mxP_tokP[1])	throw 'Extra input:  '+mxP_tokP[1][1]+s.substring(M.re_.lastIndex);
		else if (M.re_.lastIndex < s.length)	F.err(err_s2mathE_2_);
		var res = M.newME('math', mxP_tokP[0], docP);
		if (blockQ)	$(res).attr('display', 'block').addClass('ma-block');
		else if (! M.mathmlQP_)	$(res).addClass('fm-inline');
		return res;
	};
	
	/*  Like TeX, we use $ and $$ to delimit inline and block ("display") mathematics,
		respectively.  Use \$ for an actual $ instead, or \\ for \ if necessary.  */
	M.replace$s = function(nod) {
		if (nod.nodeType == 1 /* Element */ && nod.tagName != 'SCRIPT')
			for (var p = nod.firstChild; p; ) {
				var restP = p.nextSibling;	// do before splitting 'p'
				M.replace$s(p);
				p = restP;
			}
		else if (nod.nodeType == 3 /* Text */ && /[$\\]/.test(nod.data) /* for speed */) {
			var doc = nod.ownerDocument, a = [], t = '', re = /\\([$\\])|(\${1,2})([^$]+)\2/g,
				s = nod.data;
			while (true) {
				var j = re.lastIndex, m = re.exec(s), k = m ? m.index : s.length;
				if (j < k)	t += s.substring(j, k);
				if (m && m[1])	t += m[1];
				else {
					if (t) {
						a.push(doc.createTextNode(t));
						t = '';
					}
					if (! m)	break;
					a.push(M.s2mathE(m[3], m[2] == '$$', doc));
				}
			}
			F.iter(function(x) { nod.parentNode.insertBefore(x, nod); }, a);
			nod.parentNode.removeChild(nod);
		}
	};
	$(function() { if (! M.noReplace$s) M.replace$s(document.body); });
	
	return M;
}();
var M;	if (M === undefined)	M = jqMath;
