# Changelog

## 0.1.0 (2026-11-17)


### Features

* add elelem-image, a native stable-diffusion.cpp tool plugin ([238dd5b](https://github.com/elelem-sh/diffusion/commit/238dd5becda471cafb1aa321623cad868d7d8775))
* rename to elelem-diffusion, add persistent context, img2img, video, upscale ([59fae59](https://github.com/elelem-sh/diffusion/commit/59fae595864c52462041df5acdfe5da13df7dd81))


### Bug Fixes

* give video its own context, keyed by diffusion/vae/t5xxl paths ([d253053](https://github.com/elelem-sh/diffusion/commit/d253053408fb19a4cd7b71a78eb04929a3affb02))
* require elelem ~&gt; 0.12, the floor builtins/skills actually need ([fd90294](https://github.com/elelem-sh/diffusion/commit/fd9029419e9a20d8b09ff7176c5c913f959bc5d4))
* return ok:false instead of raising KeyError on unset ELELEM_SD_* env vars ([3cb18d0](https://github.com/elelem-sh/diffusion/commit/3cb18d0e25e29afc749dcb3c7718a11a57022292))
