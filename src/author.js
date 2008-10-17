var results = {
[% FOREACH d = distributions -%]
"[% d.distribution %]-[% d.version %]": [
  [% FOREACH report = d.reports -%]
  {status:"[% report.status %]",id:"[% report.id %]",perl:"[% report.perl %]",osname:"[% report.osname %]",osvers:"[% report.osvers %]",archname:"[% report.archname %]",oncpan:"[% d.csscurrent %]"},
  [% END -%]
],
[% END -%]
};

var versions = [
[% FOREACH d = distributions -%]
"[% d.distribution %]-[% d.version %]",
[% END -%]
];