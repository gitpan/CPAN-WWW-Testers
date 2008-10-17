var results = {
[% FOREACH version = versions -%]
"[% distribution %]-[% version %]": [
  [% FOREACH report = byversion.$version -%]
  {status:"[% report.status %]",id:"[% report.id %]",perl:"[% report.perl %]",osname:"[% report.osname %]",osvers:"[% report.osvers %]",archname:"[% report.archname %]",oncpan:"[% release.$version.csscurrent %]"},
  [% END -%]
],
[% END %]
};

var versions = [
[% FOREACH version = versions -%]
"[% distribution %]-[% version %]",
[% END -%]
];