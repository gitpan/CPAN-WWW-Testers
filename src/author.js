[% comma = 0 -%]
var results = {
[% FOREACH d = distributions -%]
[% IF comma == 1 %],
[% END %][% comma = 1 -%]

"[% d.distribution %]": [
[% inner = 0 -%]
[% FOREACH report = d.reports -%]
[% IF inner == 1 %],
[% END %][% inner = 1 -%]
  {status:"[% report.status | html %]",id:"[% report.id %]",perl:"[% report.perl | html %]",osname:"[% report.osname | lower | html %]",ostext:"[% report.osname | html %]",osvers:"[% report.osvers | html %]",archname:"[% report.archname | trim | html %]",perlmat:"[% report.cssperl %]"}[% END -%]

][% END -%]

};

[% comma = 0 -%]
var distros = {
[% FOREACH d = distributions -%]
[% IF comma == 1 %],
[% END %][% comma = 1 -%]
  "[% d.distribution %]": [ {oncpan:"[% d.csscurrent %]", distmat:"[% d.cssrelease %]"} ][% END -%]

};

[% comma = 0 -%]
var versions = [
[% FOREACH d = distributions -%]
[% IF comma == 1 %],
[% END %][% comma = 1 -%]
"[% d.distribution %]"[% END -%]

];