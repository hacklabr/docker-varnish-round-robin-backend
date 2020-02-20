# A heavily customized VCL to support WordPress
# Some items of note:
# Supports https
# Supports admin cookies for wp-admin
# Caches everything
# Support for custom error html page
vcl 4.0;

import directors;
import std;
include "backends.vcl";

sub vcl_init {
	call backends_init;
}

sub vcl_recv {
    set req.backend_hint = vdir.backend();
    
    # Setting http headers for backend
    set req.http.X-Forwarded-For = client.ip;
    # set req.http.X-Forwarded-Proto = "https";

    # Unset headers that might cause us to cache duplicate infos
    unset req.http.Accept-Language;

    # The purge...no idea if this works
    if (req.method == "PURGE") {
        if (!client.ip ~ purge) {
            return(synth(405,"Not allowed."));
        }
        ban("req.url ~ /");
        return (purge);
    }

    # drop cookies from static assets
    if (req.url ~ "\.(gif|jpg|jpeg|swf|ttf|css|js|flv|mp3|mp4|pdf|ico|png)(\?.*|)$") {
        unset req.http.cookie;
    }

    # drop params from static assets
    if (req.url ~ "\.(gif|jpg|jpeg|swf|ttf|flv|mp3|mp4|pdf|ico|png)(\?.*|)$") {
        set req.url = regsub(req.url, "\?.*$", "");
    }


    # drop cookies from static assets
    if (req.url ~ "wp-content\/(mu-plugins|plugins|themes|uploads)") {
        unset req.http.cookie;
    }

    # drop params from static assets
    if (req.url ~ "\.(gif|jpg|jpeg|swf|ttf|flv|mp3|mp4|pdf|ico|png)(\?.*|)$") {
        set req.url = regsub(req.url, "\?.*$", "");
    }

    # drop tracking params
    if (req.url ~ "\?(utm_(campaign|medium|source|term)|adParams|client|cx|eid|fbid|feed|ref(id|src)?|v(er|iew))=") {
        set req.url = regsub(req.url, "\?.*$", "");
    }

    # pass wp-admin urls
    if (req.url ~ "(wp-login|wp-admin)" || req.url ~ "preview=true" || req.url ~ "xmlrpc.php") {
        return (pass);
    }

    # pass wp-admin cookies
    if (req.http.cookie) {
        if (req.http.cookie ~ "(wordpress_|wp-settings-)") {
                return(pass);
        } else {
            unset req.http.cookie;
        }
    }

}



sub vcl_backend_response {
    # retry a few times if backend is down
    if (beresp.status == 503 && bereq.retries < 3 ) {
        return(retry);
    }

    if (bereq.http.Cookie ~ "(UserID|_session)") {
        # if we get a session cookie...caching is a no-go
        set beresp.http.X-Cacheable = "NO:Got Session";
        set beresp.uncacheable = true;
        return (deliver);

    } elsif (beresp.ttl <= 0s) {
        # Varnish determined the object was not cacheable
        set beresp.http.X-Cacheable = "NO:Not Cacheable";

    } elsif (beresp.http.set-cookie) {
        # You don't wish to cache content for logged in users
        set beresp.http.X-Cacheable = "NO:Set-Cookie";
        set beresp.uncacheable = true;
        return (deliver);

    } elsif (beresp.http.Cache-Control ~ "private") {
        # You are respecting the Cache-Control=private header from the backend
        set beresp.http.X-Cacheable = "NO:Cache-Control=private";
        set beresp.uncacheable = true;
        return (deliver);

    } else {
        # Varnish determined the object was cacheable
        set beresp.http.X-Cacheable = "YES";

        # Remove Expires from backend, it's not long enough
        unset beresp.http.expires;

        # Set the clients TTL on this object
        set beresp.http.cache-control = "max-age=900";

        # Set how long Varnish will keep it
        set beresp.ttl = 1w;

        # marker for vcl_deliver to reset Age:
        set beresp.http.magicmarker = "1";
    }

    # unset cookies from backendresponse
    if (!(bereq.url ~ "(wp-login|wp-admin)"))  {
        set beresp.http.X-UnsetCookies = "TRUE";
        unset beresp.http.set-cookie;
        set beresp.ttl = 1h;
    }

    # long ttl for assets
    if (bereq.url ~ "\.(gif|jpg|jpeg|swf|ttf|css|js|flv|mp3|mp4|pdf|ico|png)(\?.*|)$") {
        set beresp.ttl = 365d;
    }

    set beresp.grace = 1w;
}

sub vcl_hash {
    if ( req.http.X-Forwarded-Proto ) {
        hash_data( req.http.X-Forwarded-Proto );
    }
}

sub vcl_backend_error {
    # display custom error page if backend down
    if (beresp.status == 503 && bereq.retries == 3) {
        synthetic(std.fileread("/etc/varnish/error503.html"));
        return(deliver);
    }
}

sub vcl_synth {
    # display custom error page if backend down
    if (resp.status == 503) {
        synthetic(std.fileread("/etc/varnish/error503.html"));
        return(deliver);
    }
}


sub vcl_deliver {
    # oh noes backend is down
    if (resp.status == 503) {
        return(restart);
    }
    if (resp.http.magicmarker) {
        # Remove the magic marker
        unset resp.http.magicmarker;

        # By definition we have a fresh object
        set resp.http.age = "0";
    }
    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
    } else {
        set resp.http.X-Cache = "MISS";
    }

    # yset resp.http.Access-Control-Allow-Origin = "*";
}

sub vcl_hit {
    if (req.method == "PURGE") {
        return(synth(200,"OK"));
    }
}

sub vcl_miss {
    if (req.method == "PURGE") {
        return(synth(404,"Not cached"));
    }
}