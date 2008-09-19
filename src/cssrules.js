function makeVis(theStyle,show) {
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

function gPASSShow(show)	{makeVis('gPASS'	,show)}
function gFAILShow(show)	{makeVis('gFAIL'	,show)}
function gNAShow(show)		{makeVis('gNA'		,show)}
function gUNKNOWNShow(show) {makeVis('gUNKNOWN'	,show)}

function oncpanShow(show)   {makeVis('oncpan'	,show)}
function backpanShow(show)  {makeVis('backpan'	,show)}
function develrelShow(show) {makeVis('develrel'	,show)}
function officalShow(show)  {makeVis('official'	,show)}
function perldevShow(show)  {makeVis('perldev'	,show)}
function perlfullShow(show) {makeVis('perlfull'	,show)}
function patchShow(show)    {makeVis('patch'	,show)}
function regularShow(show)  {makeVis('regular'	,show)}

function check_grade(item) {	     if (item[0].selected) { gPASSShow('block');    gFAILShow('block'); gNAShow('block');	gUNKNOWNShow('block')  }
								else if (item[1].selected) { gPASSShow('block');    gFAILShow('none');  gNAShow('none');    gUNKNOWNShow('none')   }
								else if (item[2].selected) { gPASSShow('none');     gFAILShow('block');	gNAShow('none');    gUNKNOWNShow('none')   }
								else if (item[3].selected) { gPASSShow('none');     gFAILShow('none');  gNAShow('block');   gUNKNOWNShow('none')   }
								else if (item[4].selected) { gPASSShow('none');     gFAILShow('none');  gNAShow('none');    gUNKNOWNShow('block')  } }
function check_oncpan(item) {	     if (item[0].selected) { oncpanShow('block');   backpanShow('block')  }
								else if (item[1].selected) { oncpanShow('block');   backpanShow('none')   }
								else if (item[2].selected) { oncpanShow('none');    backpanShow('block')  } }
function check_distmat(item) {	     if (item[0].selected) { officalShow('block');  develrelShow('block') }
								else if (item[1].selected) { officalShow('block');  develrelShow('none')  }
								else if (item[2].selected) { officalShow('none');   develrelShow('block') } }
function check_perlmat(item) {	     if (item[0].selected) { perlfullShow('block'); perldevShow('block')  }
								else if (item[1].selected) { perlfullShow('block'); perldevShow('none')   }
								else if (item[2].selected) { perlfullShow('none');  perldevShow('block')  } }
function check_patches(item) {	     if (item[0].selected) { regularShow('block');  patchShow('block')    }
								else if (item[1].selected) { regularShow('block');  patchShow('none')     }
								else if (item[2].selected) { regularShow('none');   patchShow('block')    } }
