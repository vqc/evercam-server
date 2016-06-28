# Evercam Media [![Build Status][travis-image]][travis-url] [![Deps Status][hex-image]][hex-url]

Evercam Media is the component that is responsible for talking  to the camera. Consider it as a "proxy" for all commands. Processes here request either snapshots or streams and then send them to the API, Storage, or to any of the clients (e.g. Evercam-Dashboard, Evercam-Android, Evercam-iOS).

| Name   | Evercam Media  |
| --- | --- |
| Owner   | [@mosic](https://github.com/mosic)   |
| Version  | 1.0 |
| Evercam API Version  | 1.0  |
| Licence | [AGPL](https://tldrlegal.com/license/gnu-affero-general-public-license-v3-%28agpl-3.0%29) |

## Features

* Request snapshots from cameras
* Request rtsp stream from cameras
* Convert rtsp stream to rtmp / hls
* store snapshots

## Come on in, the water's warm :)

To setup the development environment follow the instructions at: [evercam-devops](https://github.com/evercam/evercam-devops)

The Evercam codebase is open source, see details: https://www.evercam.io/open-source

Documentation about Evercam can be found here: https://github.com/evercam/evercam-api/wiki

Any questions or suggestions, drop us a line: https://www.evercam.io/contact

[travis-url]: https://travis-ci.org/evercam/evercam-media
[travis-image]: https://travis-ci.org/evercam/evercam-media.svg?branch=master
[hex-url]: https://beta.hexfaktor.org/github/evercam/evercam-media
[hex-image]: https://beta.hexfaktor.org/badge/all/github/evercam/evercam-media.svg
