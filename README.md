# SPRITPREISAUT FHEM Module

This module adds information about fuel prices getting pulled from spritpreisrechner.at using their e-control API.


- In the first version you'll be able to get informations limited by regions.
- Getting help about finding your region you can go to [samjas projects](http://www.wegscheider-it.com/projects/spritpreisaut/), for fhem commands too.

This module is still under development, the projects site too =)



## Installation

```
update add https://raw.githubusercontent.com/samjaseu/fhem-spritpreisaut/master/controls_spritpreisaut.txt
update check spritpreisaut
update all spritpreisaut
```


## Usage
### Define
```
define <name> SPRITPREISAUT <searchby> <regioncode> <regiontype> <fueltype> <includeclosed> <interval>
define <name> SPRITPREISAUT <searchby> <latitude> <longitude> <fueltype> <includeclosed> <interval>
```
#### Example
```
define Tanken.Diesel.Tulln SPRITPREISAUT region 321 PB DIE false 3600
attr Tanken.Diesel.Tulln group Tanken
attr Tanken.Diesel.Tulln icon gasoline
attr Tanken.Diesel.Tulln room OUTDOOR

define Tanken.Diesel.SitzenbergReidling SPRITPREISAUT address 48.2722 15.8917 DIE false 3600
```


## Changelog
### 0.3
- added enableControlSet support.
  - interval
  - reread
  - start
  - stop
### 0.2
- added support for by-address search with longitude/latitude.
### 0.1
- first kermit =)


## TODO

- [x] 0.2: adding support for by-address search with longitude/latitude.
- [x] 0.3: add enableControlSet support and others.
- [ ] 1.0: I guess getting better in perl programming and clean up my mess I did there =)


## License

MIT License

Copyright (c) 2018 Wegscheider IT-Services <contact@samjas.eu>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
