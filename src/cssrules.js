/* ** PREFERENCES ** */

function makeVis(theStyle,show) {
	//alert("style="+theStyle+", show="+show);

	var myclass = new RegExp('\\b'+theStyle+'\\b');
    var elem = document.getElementsByTagName('*');
    for (var i = 0; i < elem.length; i++) {
		if (myclass.test(elem[i].className)){
			elem[i].style.display = show;
        } else if (elem[i].className.search('number') != -1){
            elem[i].style.display = show;
		}
	}
}

/* CSS/JS code for grades, perl and patch preferences */

var NEWPREFS1 = 250;	// all grades, no devs or patches
var OLDPREFS1 = 255;	// all on

function checkCSS1(val,css) {
	if((NEWPREFS1 & val) == val)		{ makeVis(css, 'block'); }
	else if((OLDPREFS1 & val) == val)   { makeVis(css, 'none');  }
}

function checkVis1() {
	checkCSS1(133,'gPASSdevpat');
	checkCSS1(134,'gPASSdevunp');
	checkCSS1(137,'gPASSrelpat');
	checkCSS1(138,'gPASSrelunp');

	checkCSS1(69,'gFAILdevpat');
	checkCSS1(70,'gFAILdevunp');
	checkCSS1(73,'gFAILrelpat');
	checkCSS1(74,'gFAILrelunp');

	checkCSS1(37,'gNAdevpat');
	checkCSS1(38,'gNAdevunp');
	checkCSS1(41,'gNArelpat');
	checkCSS1(42,'gNArelunp');

	checkCSS1(21,'gUNKNOWNdevpat');
	checkCSS1(22,'gUNKNOWNdevunp');
	checkCSS1(25,'gUNKNOWNrelpat');
	checkCSS1(26,'gUNKNOWNrelunp');

	OLDPREFS1 = NEWPREFS1;
}

function reset_grade(item) {	     if (item[0].selected) { NEWPREFS1 = (NEWPREFS1 & 15) + 240  } // ALL
								else if (item[1].selected) { NEWPREFS1 = (NEWPREFS1 & 15) + 128  } // PASS
								else if (item[2].selected) { NEWPREFS1 = (NEWPREFS1 & 15) +  64  } // FAIL
								else if (item[3].selected) { NEWPREFS1 = (NEWPREFS1 & 15) +  32  } // NA
								else if (item[4].selected) { NEWPREFS1 = (NEWPREFS1 & 15) +  16  } // UNKNOWN
}
function reset_perlmat(item) {	     if (item[0].selected) { NEWPREFS1 = (NEWPREFS1 & 243) + 12  } // All
								else if (item[1].selected) { NEWPREFS1 = (NEWPREFS1 & 243) +  8  } // Offical Only
								else if (item[2].selected) { NEWPREFS1 = (NEWPREFS1 & 243) +  4  } // Development Only
}
function reset_patches(item) {	     if (item[0].selected) { NEWPREFS1 = (NEWPREFS1 & 252) + 3  }  // All
								else if (item[1].selected) { NEWPREFS1 = (NEWPREFS1 & 252) + 2  }  // Exclude Patches
								else if (item[2].selected) { NEWPREFS1 = (NEWPREFS1 & 252) + 1  }  // Patches Only
}

function check_grade(item)	 {	reset_grade(item);   checkVis1(); permlink(); }
function check_perlmat(item) {	reset_perlmat(item); checkVis1(); permlink(); }
function check_patches(item) {	reset_patches(item); checkVis1(); permlink(); }


/* CSS/JS code for CPAN/BACKPAN availability and distribution release type */

var NEWPREFS2 = 10;	// On CPAN and Offical releases only
var OLDPREFS2 = 15;	// all

function checkCSS2(val,css) {
	if((NEWPREFS2 & val) == val)		{ makeVis(css, 'block'); }
	else if((OLDPREFS2 & val) == val)   { makeVis(css, 'none');  }
}


function checkVis2() {
	checkCSS2( 5,'backdev');
	checkCSS2( 6,'backoff');
	checkCSS2( 9,'cpandev');
	checkCSS2(10,'cpanoff');

	OLDPREFS2 = NEWPREFS2;
}

function reset_oncpan(item) {	     if (item[0].selected) { NEWPREFS2 = (NEWPREFS2 & 3) + 12  } // All
								else if (item[1].selected) { NEWPREFS2 = (NEWPREFS2 & 3) +  8  } // CPAN
								else if (item[2].selected) { NEWPREFS2 = (NEWPREFS2 & 3) +  4  } // Backpan
}
function reset_distmat(item) {	     if (item[0].selected) { NEWPREFS2 = (NEWPREFS2 & 12) + 3  } // All
								else if (item[1].selected) { NEWPREFS2 = (NEWPREFS2 & 12) + 2  } // Official Only
								else if (item[2].selected) { NEWPREFS2 = (NEWPREFS2 & 12) + 1  } // Development Only
}

function check_oncpan(item) {	reset_oncpan(item);  checkVis2(); permlink(); }
function check_distmat(item) {	reset_distmat(item); checkVis2(); permlink(); }



/* ** COOKIE CONTROL ** */

function createCookie(name,value,days) {
	if (days) {
		var date = new Date();
		date.setTime(date.getTime()+(days*24*60*60*1000));
		var expires = "; expires="+date.toGMTString();
	}
	else var expires = "";
	document.cookie = name+"="+value+expires+"; path=/";
}

function readCookie(name) {
	var nameEQ = name + "=";
	var ca = document.cookie.split(';');
	for(var i=0;i < ca.length;i++) {
		var c = ca[i];
		while (c.charAt(0)==' ') c = c.substring(1,c.length);
		if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length,c.length);
	}
	return null;
}

function eraseCookie(name) {
	createCookie(name,"",-1);
}



function readCookies() {
	var rs = getparam('grade');
	if(!rs) { rs = readCookie('grade'); }
	if(!rs) { rs = 1; }
	var elem = document.getElementById('grade_pref');
	elem.selectedIndex = rs-1;
	reset_grade(elem);

	rs = getparam('perlmat');
	if(!rs) { rs = readCookie('perlmat'); }
	if(!rs) { rs = 2; }
	elem = document.getElementById('perlmat_pref');
	elem.selectedIndex = rs-1;
	reset_perlmat(elem);

	rs = getparam('patches');
	if(!rs) { rs = readCookie('patches'); }
	if(!rs) { rs = 2; }
	elem = document.getElementById('patches_pref');
	elem.selectedIndex = rs-1;
	reset_patches(elem);

	rs = getparam('oncpan');
	if(!rs) { rs = readCookie('oncpan'); }
	if(!rs) { rs = 2; }
	elem = document.getElementById('oncpan_pref');
	elem.selectedIndex = rs-1;
	reset_oncpan(elem);

	rs = getparam('distmat');
	if(!rs) { rs = readCookie('distmat'); }
	if(!rs) { rs = 2; }
	elem = document.getElementById('distmat_pref');
	elem.selectedIndex = rs-1;
	reset_distmat(elem);

	checkVis1();
	checkVis2();
	permlink();
}

function savePrefs() {
	var elem = document.getElementById('grade_pref');
	createCookie('grade',elem.selectedIndex+1,1000);

	elem = document.getElementById('perlmat_pref');
	createCookie('perlmat',elem.selectedIndex+1,1000);

	elem = document.getElementById('patches_pref');
	createCookie('patches',elem.selectedIndex+1,1000);

	elem = document.getElementById('oncpan_pref');
	createCookie('oncpan',elem.selectedIndex+1,1000);

	elem = document.getElementById('distmat_pref');
	createCookie('distmat',elem.selectedIndex+1,1000);
}

function resetPrefs() {
	var rs = readCookie('grade');
	var elem = document.getElementById('grade_pref');
	if(!rs) { rs = 1; }
	elem.selectedIndex = rs-1;

	rs = readCookie('perlmat');
	elem = document.getElementById('perlmat_pref');
	if(!rs) { rs = 2; }
	elem.selectedIndex = rs-1;

	rs = readCookie('patches');
	elem = document.getElementById('patches_pref');
	if(!rs) { rs = 2; }
	elem.selectedIndex = rs-1;

	rs = readCookie('oncpan');
	elem = document.getElementById('oncpan_pref');
	if(!rs) { rs = 2; }
	elem.selectedIndex = rs-1;

	rs = readCookie('distmat');
	elem = document.getElementById('distmat_pref');
	if(!rs) { rs = 2; }
	elem.selectedIndex = rs-1;
}

function getparam( name ) {
	name = name.replace(/[\[]/,"\\\[").replace(/[\]]/,"\\\]");
	var regexS = "[\\?&]"+name+"=([^&#]*)";
	var regex = new RegExp( regexS );
	var results = regex.exec( window.location.href );
	if( results == null )
		return "";
	else
		return results[1];
}

function permlink() {
	var link = parent.location + "";
	if(link.indexOf('?') != -1) {
		link = link.substring(0,link.indexOf('?'));
	}

	var elem = document.getElementById('grade_pref');
	link += '?grade='+(elem.selectedIndex+1);

	elem = document.getElementById('perlmat_pref');
	link += '&amp;perlmat='+(elem.selectedIndex+1);

	elem = document.getElementById('patches_pref');
	link += '&amp;patches='+(elem.selectedIndex+1);

	elem = document.getElementById('oncpan_pref');
	link += '&amp;oncpan='+(elem.selectedIndex+1);

	elem = document.getElementById('distmat_pref');
	link += '&amp;distmat='+(elem.selectedIndex+1);

	elem = document.getElementById('PermLink');
	elem.href = link;
}
