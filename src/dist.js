var results = {
[% FOREACH version = versions -%]
"[% distribution %]-[% version %]": [
  [% FOREACH report = byversion.$version -%]
  {status:"[% report.status | html %]",id:"[% report.id %]",perl:"[% report.perl | html %]",osname:"[% report.osname | lower | html %]",ostext:"[% report.osname | html %]",osvers:"[% report.osvers | html %]",archname:"[% report.archname | trim | html %]",perlmat:"[% report.cssperl %]"},
  [% END -%]
],
[% END %]
};

var distros = {
[% FOREACH version = versions -%]
"[% distribution %]-[% version %]": [
  {oncpan:"[% release.$version.csscurrent %]", distmat:"[% release.$version.cssrelease %]"},
],
[% END %]
};

var versions = [
[% FOREACH version = versions -%]
"[% distribution %]-[% version %]",
[% END -%]
];


var stats = [
[% FOREACH p = stats_perl -%]
  {perl: "[% p %]", counts: [ [% FOREACH os IN stats_oses %]"[% stats.$p.$os %]",[% END -%] ] },
[% END -%]
];

