# File Embedding in Go

> Talk at [Golang Leipzig November Meetup][meetup]

## What is File Embedding?

- packing arbitrary resources into a binary/executable
- a resource can be anything, e.g. HTML templates, CSS or Javascript files, a favicon, translations...
- example layout of a typical web application:

```sh
├── assets
│   ├── base.css
│   ├── base.js
│   ├── ...
│   └── favicon.svg
├── migrations
│   ├── 01_initial_setup.down.sql
│   └── ...
├── notes.go
├── storage.go
├── storage_test.go
└── views
    ├── index.gohtml
    ├── ...
    └── layouts
        └── base.gohtml
```

## Advantages :thumbsup:

- only a single file needs to be distributed/deployed
- embedded data is "immutable" (at least from outside the process)

## Disadvantages :thumbsdown:

- binary size grows with each resource that gets embedded → increased memory usage
- space efficiency depends on the encoding of the embedded content
    - [base64 wastes about 1/3](https://en.wikipedia.org/wiki/Base64#Output_padding) for encoding
- large files are not suitable for embedding

If the resources are compressable---e.g. most plain text files are---then a binary packer like [upx][upx] can reduce the file size dramatically:

```sh
$ upx -o notes.upx notes
$ du -sh notes notes.upx 
24M     notes
9.7M    notes.upx
```

## Available Implementations

- [go-bindata][bindata] most popular but now deprecated, recommends `pkger`
- [pkger][pkger]
    - requires a Go modules project
    - API simulates `os.File`
    - :thumbsdown: stores a lot of redundant metadata, e.g. [absolute paths to files](https://github.com/markbates/pkger#how-it-works-module-aware-pathing) :policewoman: or imported packages
- [statik][statik]
    - simulates an [`http.FileSystem`](https://pkg.go.dev/net/http#FileSystem)---ok for some use cases but pretty otherwise inconvenient
    - :thumbsdown: can only include a single directory
- [go.rice][gorice]
    - :thumbsdown: complicated to use, scans your source code for `rice.FindBox("/path")` calls and includes them
    - :thumbsdown: weird limitations, e.g. paths cannot be constant strings or undefined behaviour when called in `init()`
    - failed to set it up for my example application, I really wonder why this got popular :man_shrugging:

## It's Time for Yet Another File Embedding Tool

- [embed][embed] treats [Not Invented Here syndrome][NIH] and enforces [dogfooding][dogfooding]
- [tiny prototype implementation][embed-gist] (still a single Go file)

### Design

- [very simple API][embed-API] that provides methods for:
    - listing embedded files
    - get file as bytes
    - get file as string
- no error return values
    - if a file is not found the default value is returned (`[]byte{}` or `""`)
    - it is very easy to test if the expected files were actually embedded
- `embed` generates a single `embeds.go` file that implements [the API][embed-API] ([example](https://github.com/klingtnet/embed/blob/78fc802c58e27bec29607f32d9736611694d18e6/examples/migrate/embeds.go))
- [filenames and contents are stored as base64 encoded strings](https://github.com/klingtnet/embed/blob/78fc802c58e27bec29607f32d9736611694d18e6/examples/migrate/embeds.go#L20)
    - compression adds a lot of overhead (additional dependency, runtime cost, etc.)
    - use a [binary packer][upx] if in doubt
- provides a [golang-migrate][golang-migrate] driver

### Usage

- check [klingtnet/embed/examples](https://github.com/klingtnet/embed/tree/master/examples) or [klingtnet/notes](https://github.com/klingtnet/notes) for a real world example

```sh
NAME:
   embed - A new cli application

USAGE:
   embed [global options] command [command options] [arguments...]

VERSION:
   unset

COMMANDS:
   help, h  Shows a list of commands or help for one command

GLOBAL OPTIONS:
   --package value, -p value                    name of the package the generated Go file is associated to (default: "main")
   --destination value, --dest value, -d value  where to store the generated Go file (default: "embeds.go")
   --include value, -i value                    paths to embed, directories are stored recursively (can be used multiple times)
   --help, -h                                   show help (default: false)
   --version, -v                                print the version (default: false)
```

## Draft for Embedded Static Files

[The draft][draft]---published by Russ Cox and Brad Fitzpatrick in July---identified the following problems with the current situation:

- too many existing tools :sweat_smile:
- all depend on a manual generation step
- generated file bloats git history (with a second slightly larger copy of each file)
- not go-gettable if generated file is not checked into source control

Adding support for file embedding to the `go` command will eliminate those problems.

Proposed changes:

- new `//go:embed` directive
- `embed` package containing `embed.Files` that implements `fs.FS` <sup>[file system interface draft][fs-draft]</sup> which makes it directly usable with `net/http` and `hmtl/template`

Here's an [example for the embed directive](https://go.googlesource.com/proposal/+/master/design/draft-embed.md#go_embed-directives):

```go
// content holds our static web server content.
//go:embed image/* template/*
//go:embed html/index.html
var content embed.Files
```

The [draft][draft] also contains various considerations regarding:

- [directory traversal](https://go.googlesource.com/proposal/+/master/design/draft-embed.md#dot_dot_module-boundaries_and-file-name-restrictions), e.g. `../../../etc/passwd` should be prevented by disallowing paths above the module root
- [content compression](https://go.googlesource.com/proposal/+/master/design/draft-embed.md#compression-to-reduce-binary-size) is discussed but left open as an implementation detail

Still curious?

- watch the [draft presentation video][draft-video], [proposal pull request][draft-pr] and its follow up [adoption pull request](https://github.com/golang/go/issues/41191)
- there [was](https://github.com/golang/go/issues/35950#issuecomment-561797246) also [the idea to just have a magic directory](https://github.com/golang/go/issues/35950#issuecomment-561718302) called `static`
- should embed include [hidden files](https://github.com/golang/go/issues/42328#issuecomment-720169922)?

[upx]: https://upx.github.io/
[meetup]: https://www.meetup.com/Leipzig-Golang/events/268785591/
[pkger]: https://github.com/markbates/pkger
[bindata]: https://github.com/jteeuwen/go-bindata
[gorice]: https://github.com/GeertJohan/go.rice
[statik]: https://github.com/rakyll/statik
[embed]: https://github.com/klingtnet/embed
[embed-gist]: https://gist.github.com/klingtnet/b66ecace3e87b10972245fec7e4c3fc5#file-teeny-tiny-file-embed-go
[embed-API]: https://pkg.go.dev/github.com/klingtnet/embed#Embed
[NIH]: https://en.wikipedia.org/wiki/Not_invented_here
[dogfooding]: https://en.wikipedia.org/wiki/Dogfooding
[golang-migrate]: https://github.com/golang-migrate/migrate/
[draft]: https://go.googlesource.com/proposal/+/master/design/draft-embed.md
[draft-pr]: https://github.com/golang/go/issues/35950
[draft-video]: https://golang.org/s/draft-embed-video
[go116]: https://tip.golang.org/doc/go1.16
[fs-draft]: https://golang.org/s/draft-iofs-design