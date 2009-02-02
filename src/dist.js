[% comma = 0 -%]
var results = {
[% FOREACH version = versions -%]
[% IF comma == 1 %],
[% END %][% comma = 1 -%]

"[% distribution %]-[% version %]": [
[% inner = 0 -%]
[% FOREACH report = byversion.$version -%]
[% IF inner == 1 %],
[% END %][% inner = 1 -%]
  {status:"[% report.status | html %]",id:"[% report.id %]",perl:"[% report.perl | html %]",osname:"[% report.osname | lower | html %]",ostext:"[% report.ostext | html %]",osvers:"[% report.osvers | html %]",archname:"[% report.archname | trim | html %]",perlmat:"[% report.cssperl %]"}[% END -%]

][% END -%]

};

[% comma = 0 %]
var distros = {
[% FOREACH version = versions -%]
[% IF comma == 1 %],
[% END %][% comma = 1 -%]
  "[% distribution %]-[% version %]": [ {oncpan:"[% release.$version.csscurrent %]", distmat:"[% release.$version.cssrelease %]"} ][% END -%]

};

[% comma = 0 %]
var versions = [
[% FOREACH version = versions -%]
[% IF comma == 1 %],
[% END %][% comma = 1 -%]
  "[% distribution %]-[% version %]"[% END -%]

];


[% comma = 0 -%]
var stats = [
[% FOREACH p = stats_perl -%]
[% IF comma == 1 %],
[% END %][% comma = 1 -%]
  {perl: "[% p %]", counts: [ [% inner = 0; FOREACH os IN stats_oses; IF inner == 1 %], [% END; inner = 1 %]"[% stats.$p.$os %]"[% END -%] ] }[% END -%]

];

