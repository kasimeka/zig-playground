<!-- markdownlint-disable line-length -->
# base64 cli in zig

## usage

to encode:

```console
$ echo -n 'Whereas recognition of the inherent dignity and of the equal and inalienable rights of all members of the human family is the foundation of freedom, justice and peace in the world' | zig build run
V2hlcmVhcyByZWNvZ25pdGlvbiBvZiB0aGUgaW5oZXJlbnQgZGlnbml0eSBhbmQgb2YgdGhlIGVxdWFsIGFuZCBpbmFsaWVuYWJsZSByaWdodHMgb2YgYWxsIG1lbWJlcnMgb2YgdGhlIGh1bWFuIGZhbWlseSBpcyB0aGUgZm91bmRhdGlvbiBvZiBmcmVlZG9tLCBqdXN0aWNlIGFuZCBwZWFjZSBpbiB0aGUgd29ybGQ=
```

to decode:

```console
$ echo -n 'V2hlcmVhcyByZWNvZ25pdGlvbiBvZiB0aGUgaW5oZXJlbnQgZGlnbml0eSBhbmQgb2YgdGhlIGVxdWFsIGFuZCBpbmFsaWVuYWJsZSByaWdodHMgb2YgYWxsIG1lbWJlcnMgb2YgdGhlIGh1bWFuIGZhbWlseSBpcyB0aGUgZm91bmRhdGlvbiBvZiBmcmVlZG9tLCBqdXN0aWNlIGFuZCBwZWFjZSBpbiB0aGUgd29ybGQ=' | zig build run -- -d
Whereas recognition of the inherent dignity and of the equal and inalienable rights of all members of the human family is the foundation of freedom, justice and peace in the world
```

run test cases:

```console
$ zig build test --summary all
test success
├─ run test 2 pass (2 total) 5ms MaxRSS:2M
│  └─ compile test Debug native success 1s MaxRSS:209M
└─ run test success 4ms MaxRSS:2M
   └─ compile test Debug native success 1s MaxRSS:215M
```
