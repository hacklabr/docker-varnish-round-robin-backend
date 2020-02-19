vcl 4.0;

import directors;
include "backends.vcl";

sub vcl_init {
	call backends_init;
}

sub vcl_recv {
    set req.backend_hint = vdir.backend();
}