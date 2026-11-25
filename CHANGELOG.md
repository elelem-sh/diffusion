# Changelog

## [0.2.1](https://github.com/elelem-sh/diffusion/compare/v0.2.0...v0.2.1) (2026-11-25)


### Bug Fixes

* port to the stable-diffusion.cpp options api ([c9d59cb](https://github.com/elelem-sh/diffusion/commit/c9d59cb4806bc55d5a110c5a0f35cd887e12b753))
* return an error when the output path is nil ([27ab48a](https://github.com/elelem-sh/diffusion/commit/27ab48a996096e73c01450368cf34a4d4c106e39))

## [0.2.0](https://github.com/elelem-sh/diffusion/compare/v0.1.0...v0.2.0) (2026-11-24)


### Features

* auto-detect GPU backend for stable-diffusion.cpp build ([a9b0da8](https://github.com/elelem-sh/diffusion/commit/a9b0da870bae7380654c53494b3ce363335c0f40))
* expose cfg_scale on image generation ([1517acb](https://github.com/elelem-sh/diffusion/commit/1517acba01d1853839f980563c0a6a07f2abb51e))
* expose vae_path on the image generation context ([37ebfa5](https://github.com/elelem-sh/diffusion/commit/37ebfa51cebcebc0b1395d84bfcac743c8b16810))
* use vulkan on intel macs with a discrete gpu ([e668982](https://github.com/elelem-sh/diffusion/commit/e6689826db9d1f50e93f9d491049e59fe0bd14a0))


### Bug Fixes

* build for the host cpu when installed as a gem ([d3def8c](https://github.com/elelem-sh/diffusion/commit/d3def8c13d27f6f02a9716774bf453c18d477524))
* link apple frameworks on macos ([85cd535](https://github.com/elelem-sh/diffusion/commit/85cd535c6481f011255aac58313b4fd7e02621a5))

## 0.1.0 (2026-11-17)


### Features

* add elelem-image, a native stable-diffusion.cpp tool plugin ([238dd5b](https://github.com/elelem-sh/diffusion/commit/238dd5becda471cafb1aa321623cad868d7d8775))
* rename to elelem-diffusion, add persistent context, img2img, video, upscale ([59fae59](https://github.com/elelem-sh/diffusion/commit/59fae595864c52462041df5acdfe5da13df7dd81))


### Bug Fixes

* give video its own context, keyed by diffusion/vae/t5xxl paths ([d253053](https://github.com/elelem-sh/diffusion/commit/d253053408fb19a4cd7b71a78eb04929a3affb02))
* require elelem ~&gt; 0.12, the floor builtins/skills actually need ([fd90294](https://github.com/elelem-sh/diffusion/commit/fd9029419e9a20d8b09ff7176c5c913f959bc5d4))
* return ok:false instead of raising KeyError on unset ELELEM_SD_* env vars ([3cb18d0](https://github.com/elelem-sh/diffusion/commit/3cb18d0e25e29afc749dcb3c7718a11a57022292))
