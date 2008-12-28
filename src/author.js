var results = {
[% FOREACH d = distributions -%]
"[% d.distribution %]": [
  [% FOREACH report = d.reports -%]
  {status:"[% report.status | html %]",id:"[% report.id %]",perl:"[% report.perl | html %]",osname:"[% report.osname | lower | html %]",ostext:"[% report.osname | html %]",osvers:"[% report.osvers | html %]",archname:"[% report.archname | trim | html %]",perlmat:"[% report.cssperl %]"},
  [% END -%]
],
[% END -%]
};

var distros = {
[% FOREACH d = distributions -%]
"[% d.distribution %]": [
  {oncpan:"[% d.csscurrent %]", distmat:"[% d.cssrelease %]"},
],
[% END %]
};

var versions = [
[% FOREACH d = distributions -%]
"[% d.distribution %]",
[% END -%]
];