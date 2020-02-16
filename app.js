"use strict";

const fs = require('fs');
const exec = require('child_process').exec;
const dns = require('dns');

var _timeout,
    started = false,
    current_ips = '';

setInterval(function () {
    dns.resolve(process.env.BACKEND_HOST, function (err, ips) {
        let port = process.env.BACKEND_PORT || 80;
        let str_ips = JSON.stringify(ips);
        if (current_ips != str_ips) {
            current_ips = str_ips;

            let vcl = "";
            for (let i in ips) {
                let ip = ips[i];
                vcl += `\n backend b${i} {\n\t .host = "${ip}";\n\t .port = "${port}";\n}\n`;
            }

            vcl += `\nsub backends_init {\n\t new vdir = directors.round_robin();`;
            for (let i in ips) {
                let ip = ips[i];
                vcl += `\n\t vdir.add_backend(b${i});`;
            }

            vcl += `\n}\n`;

            vcl += `\nacl purge {`;
            for (let i in ips) {
                let ip = ips[i];
                vcl += `\n\t"${ip}";`;
            }
            vcl += `\n}`;

            fs.writeFile("/etc/varnish/backends.vcl", vcl, function(err) {
                if(err) {
                    return console.log(err);
                }

                if (!started) {
                    exec("varnishd -F -f /etc/varnish/default.vcl", function (err, stdout, stderr   ) {
                        console.log(err, stdout, stderr);
                    });
                }
            
                if (_timeout) {
                    clearTimeout(_timeout);
                    _timeout = undefined;
                }
            
                _timeout = setTimeout(() => {
                    console.log('reloading varnish');
                    exec('varnishreload');
                },1000);
            }); 
            

        }
    })
},500)