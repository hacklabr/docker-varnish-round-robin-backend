"use strict";

const fs = require('fs');
const exec = require('child_process').exec;
const dns = require('dns');
const mustache = require('mustache');

let beckends_template = `
{{#backends}}
    backend {{name}} {
        .host = "{{host}}";
        .port = "{{port}}";
    }
{{/backends}}

sub backends_init {
    new vdir = directors.round_robin();
    {{#backends}}
        vdir.add_backend({{name}});
    {{/backends}}
}
acl purge {
    {{#backends}}
        "{{host}}";
    {{/backends}}
}
`;

var reload_timeout;
var nslookup_interval = process.env.NSLOOKUP_INTERVAL
var current_backends = '';
var default_port = process.env.BACKEND_PORT || 80;

function varnish_reload() {
    console.log('reloading varnish');
    exec('varnishreload');
}

fs.watchFile(process.env.VCL_FILE || '/etc/varnish/default.vcl', function () {
    varnish_reload();
});

function create_backends_vcl_file() {
    dns.resolve(process.env.BACKEND_HOST, function (err, backend_ips) {
        backend_ips.sort();
        let port = default_port;
        let backends_json = JSON.stringify(backend_ips);
        
        if (current_backends != backends_json) {
            console.log('varnish backends: ' + backends_json);
            current_backends = backends_json;

            let backends = backend_ips.map(function(ip, index) {
                return {
                    name: `backend_${index}`,
                    host: ip,
                    port: port
                }
            });

            let vcl_file_content = mustache.render(beckends_template, { backends: backends });
            console.log(vcl_file_content);
            fs.writeFile("/etc/varnish/backends.vcl", vcl_file_content, function (err) {
                if (err) {
                    return console.log(err);
                }
            
                if (reload_timeout) {
                    clearTimeout(reload_timeout);
                    reload_timeout = undefined;
                }
            
                reload_timeout = setTimeout(() => {
                    varnish_reload();
                }, 1000);
            });
        }
    });
}

create_backends_vcl_file();

setTimeout(function () {
    setInterval(create_backends_vcl_file, nslookup_interval);
}, 5000)